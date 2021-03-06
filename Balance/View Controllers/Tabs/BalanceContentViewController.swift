import UIKit
import CoreData
import SwiftEntryKit

typealias RefreshBlock = () -> ()
class BalanceContentViewController: UITableViewController {
    enum Section: Int {
        case cdp      = 0
        case ethereum = 1
        case erc20    = 2
    }
    
    var ethereumWallet: EthereumWallet?
    var erc20TableCell: CryptoBalanceTableViewCell?
    var refreshBlock: RefreshBlock?
    
    private var expandedIndexPath: IndexPath?
    
    private let cdpCellReuseIdentifier = "cdpCell"
    private lazy var cryptoCellReuseIdentifier: String = {
        // Use the memory address in the identifier so we only respond to cell notifications for this view controller
        let memAddress = unsafeBitCast(self, to: Int.self)
        return "\(memAddress) cryptoCell"
    }()
    
    // MARK - View Lifecycle -
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor(hexString: "#fbfbfb")
        
        tableView.backgroundColor = UIColor(hexString: "#fbfbfb")
        tableView.separatorStyle = .none
        
        tableView.register(CDPBalanceTableViewCell.self, forCellReuseIdentifier: cdpCellReuseIdentifier)
        let refresh = UIRefreshControl()
        refresh.addTarget(self, action: #selector(reload), for: .valueChanged)
        tableView.refreshControl = refresh
        
        setupNavigation()
        preloadErc20Cell()
        
        NotificationCenter.default.addObserver(self, selector: #selector(cellExpanded(_:)), name: ExpandableTableViewCell.Notifications.expanded, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(cellCollapsed(_:)), name: ExpandableTableViewCell.Notifications.collapsed, object: nil)
    }
    
    private func setupNavigation() {
        navigationItem.title = ""
        if let navigationBar = navigationController?.navigationBar {
            navigationBar.barTintColor = .white
            navigationBar.isTranslucent = false
            navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.black]
        }
    }
    
    @objc private func reload() {
        refreshBlock?()
    }
    
    private func reloadTableCellHeights() {
        // "hack" to reload the sizes without loading the table cell again
        // Note it's not really a hack, it's actually the recommended way to do this, it just feels hackish since Apple
        // doesn't provide a proper method for this
        tableView.beginUpdates()
        tableView.endUpdates()
    }
    
    @objc private func cellExpanded(_ notification: Notification) {
        if let userInfo = notification.userInfo, userInfo[ExpandableTableViewCell.Notifications.Keys.reuseIdentifier] as? String == cryptoCellReuseIdentifier, let indexPath = userInfo[ExpandableTableViewCell.Notifications.Keys.indexPath] as? IndexPath {
            expandedIndexPath = indexPath
            reloadTableCellHeights()
        }
    }
    
    @objc private func cellCollapsed(_ notification: Notification) {
        if let userInfo = notification.userInfo, userInfo[ExpandableTableViewCell.Notifications.Keys.reuseIdentifier] as? String == cryptoCellReuseIdentifier {
            expandedIndexPath = nil
            reloadTableCellHeights()
        }
    }
        
    // MARK - Table View -
    
    private func preloadErc20Cell() {
        let indexPath = IndexPath(row: 0, section: Section.erc20.rawValue)
        let isExpanded = (indexPath == expandedIndexPath)
        erc20TableCell = CryptoBalanceTableViewCell(withIdentifier: cryptoCellReuseIdentifier, wallet: ethereumWallet!, cryptoType: .erc20, isExpanded: isExpanded, indexPath: indexPath)
    }
    
    func reloadData() {
        preloadErc20Cell()
        tableView.reloadData()
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sectionEnum = Section(rawValue: section) else {
            return 0
        }
        
        switch sectionEnum {
        case .ethereum:
            return ethereumWallet != nil ? 1 : 0
        case .erc20:
            // Check if there are any tokens
            if let count = ethereumWallet?.tokens?.count, count > 0 {
                return 1
            }
            return 0
        case .cdp:
            return ethereumWallet?.CDPs?.count ?? 0
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let isExpanded = (indexPath == expandedIndexPath)
        if indexPath.section == Section.ethereum.rawValue {
            return CryptoBalanceTableViewCell(withIdentifier: cryptoCellReuseIdentifier, wallet: ethereumWallet!, cryptoType: .ethereum, isExpanded: isExpanded, indexPath: indexPath)
        } else if indexPath.section == Section.erc20.rawValue {
            // Cache this cell to prevent stuttering when scrolling
            return erc20TableCell!
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: cdpCellReuseIdentifier, for: indexPath) as! CDPBalanceTableViewCell
            if let cdp = ethereumWallet?.CDPs?[indexPath.row] {
                cell.cdp = cdp
            }
            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let ethereumWallet = ethereumWallet else {
            return 0
        }
        
        let isExpanded = (indexPath == expandedIndexPath)
        if indexPath.section == Section.ethereum.rawValue {
            return CryptoBalanceTableViewCell.calculatedHeight(wallet: ethereumWallet, cryptoType: .ethereum, isExpanded: isExpanded)
        } else if indexPath.section == Section.erc20.rawValue {
            return CryptoBalanceTableViewCell.calculatedHeight(wallet: ethereumWallet, cryptoType: .erc20, isExpanded: isExpanded)
        } else {
            return 180
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard indexPath.section == Section.cdp.rawValue else {
            return
        }
        
        guard let cdp = ethereumWallet?.CDPs?[indexPath.row] else {
            return
        }
        
        var attributes = EKAttributes()
        attributes = .centerFloat
        attributes.name = "CDP Info"
        attributes.hapticFeedbackType = .success
        attributes.popBehavior = .animated(animation: .translation)
        attributes.entryBackground = .color(color: .black)
        attributes.roundCorners = .all(radius: 20)
        attributes.border = .none
        attributes.statusBar = .hidden
        attributes.screenBackground = .color(color: UIColor(red:0.00, green:0.00, blue:0.00, alpha:0.8))
        attributes.positionConstraints.rotation.isEnabled = false
        attributes.shadow = .active(with: .init(color: .black, opacity: 0.5, radius: 2))
        attributes.statusBar = .ignored
        attributes.displayDuration = .infinity
        attributes.screenInteraction = .dismiss
        attributes.positionConstraints.rotation.isEnabled = false
        let widthConstraint = EKAttributes.PositionConstraints.Edge.ratio(value: 0.95)
        let heightConstraint = EKAttributes.PositionConstraints.Edge.intrinsic
        attributes.positionConstraints.size = .init(width: widthConstraint, height: heightConstraint)
        
        let cdpInfoView = CDPInfoView(cdp: cdp)
        SwiftEntryKit.display(entry: cdpInfoView, using: attributes)
    }
}
