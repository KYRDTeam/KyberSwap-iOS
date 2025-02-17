//
//  TabBarController.swift
//  KyberNetwork
//
//  Created by Tung Nguyen on 09/12/2022.
//

import Foundation
import UIKit
import AppState
import Dependencies
import Utilities
import Moya
import KrystalWallets
import DesignSystem

class KNTabBarController: UITabBarController {
    
    let viewAppear = Once()
    let viewDidAppear = Once()
    
    override var preferredStatusBarStyle: UIStatusBarStyle { return .lightContent }
    
    override func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        tabBar.tintColor = UIColor(named: "buttonBackgroundColor")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        UITabBar.appearance().unselectedItemTintColor = .white
        self.observeNotification()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        viewDidAppear.run {
            self.showUpdatePopupIfNeeded(onDismissed: {
                self.showBackUpWalletIfNeeded(walletID: AppState.shared.currentAddress.walletID)
            })
        }
    }
    
    func observeNotification() {
        NotificationCenter.default.addObserver(self, selector: #selector(onSwitchAddress), name: .appAddressChanged, object: nil)
    }
    
    @objc func onSwitchAddress(notification: Notification) {
        guard let userInfo = notification.userInfo else {
            return
        }
        guard let oldAddress = userInfo["old_address"] as? KAddress, let newAddress = userInfo["new_address"] as? KAddress else {
            return
        }
        guard oldAddress.walletID != newAddress.walletID else {
            return
        }
        showBackUpWalletIfNeeded(walletID: newAddress.walletID)
    }
    
    func setupTabbarConstraints() {
        for vc in self.viewControllers ?? [] {
            vc.tabBarItem.title = nil
            vc.tabBarItem.imageInsets = UIEdgeInsets(top: 5, left: 0, bottom: -5, right: 0)
        }
    }
    
    func addNewTag(toItemAt index: Int) {
        let centerX = getCenterXOfItem(atIndex: index)
        
        let badgeView = UIView()
        badgeView.layer.cornerRadius = 4
        badgeView.layer.masksToBounds = true
        badgeView.backgroundColor = .red
        badgeView.translatesAutoresizingMaskIntoConstraints = false
        
        let label = UILabel()
        label.font = .karlaBold(ofSize: 8)
        label.text = "N"
        label.minimumScaleFactor = 0.5
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        
        let width = "N".width(withConstrainedHeight: 16, font: .karlaBold(ofSize: 8))
        let height = "N".height(withConstrainedWidth: width, font: .karlaBold(ofSize: 8))
        
        badgeView.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: badgeView.leadingAnchor, constant: 4),
            label.trailingAnchor.constraint(equalTo: badgeView.trailingAnchor, constant: -4),
            label.topAnchor.constraint(equalTo: badgeView.topAnchor, constant: 2),
            label.bottomAnchor.constraint(equalTo: badgeView.bottomAnchor, constant: -2),
        ])
        
        tabBar.superview?.addSubview(badgeView)
        tabBar.superview?.bringSubviewToFront(badgeView)
        
        NSLayoutConstraint.activate([
            badgeView.topAnchor.constraint(equalTo: tabBar.topAnchor, constant: 6),
            badgeView.widthAnchor.constraint(equalToConstant: width + 8),
            badgeView.heightAnchor.constraint(equalToConstant: height + 4),
            badgeView.leadingAnchor.constraint(equalTo: tabBar.leadingAnchor, constant: centerX + 16 - (width + 8) / 2)
        ])
        
        view.layoutIfNeeded()
    }
    
    private func getCenterXOfItem(atIndex index: Int) -> CGFloat {
        let itemCount = tabBar.items?.count ?? 0
        
        return itemCount == 0 ? 0 : tabBar.frame.width / CGFloat(itemCount * 2) * CGFloat(index * 2 + 1)
    }
    
    func showBackUpWalletIfNeeded(walletID: String) {
        guard AppDependencies.featureFlag.isFeatureEnabled(key: FeatureFlagKeys.backupRemind) else {
            return
        }
        guard !walletID.isEmpty, WalletExtraDataManager.shared.shouldShowBackup(forWallet: walletID) else { return }
        let provider = MoyaProvider<KrytalService>(plugins: [NetworkLoggerPlugin(verbose: true)])
        let addresses = WalletManager.shared.getAllAddresses(walletID: walletID).map { address -> String in
            switch address.addressType {
            case .evm:
                return "ethereum:\(address.addressString)"
            case .solana:
                return "solana:\(address.addressString)"
            }
        }
        provider.requestWithFilter(.getMultichainBalance(address: addresses, chainIds: ChainType.getAllChain().map { "\($0.getChainId())" }, quoteSymbols: [])) { (result) in
            switch result {
            case .success(let resp):
                guard let responseJson = try? resp.mapJSON() as? JSONDictionary ?? [:], let jsons = responseJson["data"] as? [JSONDictionary] else {
                    return
                }
                if !jsons.map(ChainBalanceModel.init).flatMap(\.balances).isEmpty {
                    AppDependencies.router.openBackupReminder(viewController: self, walletID: walletID)
                }
                return
            case .failure:
                return
            }
        }
    }
    
    func showUpdatePopupIfNeeded(onDismissed: @escaping () -> Void) {
        if VersionManager.shared.getCurrentVersionStatus() == .canUpdate, let latestVersion = VersionManager.shared.getLatestVersionConfig() {
            let vc = UpdateAvailableViewController.instantiateFromNib()
            vc.onDismissed = onDismissed
            vc.versionConfig = latestVersion
            let popup = PopupViewController(vc: vc, configuration: .init(height: .intrinsic))
            popup.modalPresentationStyle = .overCurrentContext
            present(popup, animated: true)
        } else {
            onDismissed()
        }
    }
}
