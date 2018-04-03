// Copyright SIX DAY LLC. All rights reserved.

import UIKit

class KNWalletCoordinator: Coordinator {

  let navigationController: UINavigationController
  let session: KNSession
  let balanceCoordinator: KNBalanceCoordinator

  weak var delegate: KNSessionDelegate?

  var coordinators: [Coordinator] = []

  lazy var rootViewController: KNWalletViewController = {
    return KNWalletViewController(delegate: self)
  }()

  init(
    navigationController: UINavigationController = UINavigationController(),
    session: KNSession,
    balanceCoordinator: KNBalanceCoordinator
    ) {
    self.navigationController = navigationController
    self.navigationController.applyStyle()
    self.session = session
    self.balanceCoordinator = balanceCoordinator
  }

  func start() {
    self.navigationController.viewControllers = [self.rootViewController]
    self.addObserveNotifications()
  }

  func stop() {
    self.removeObserveNotifications()
  }
}

extension KNWalletCoordinator {
  fileprivate func addObserveNotifications() {
    let ethBalanceName = Notification.Name(kETHBalanceDidUpdateNotificationKey)
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(self.ethBalanceDidUpdateNotification(_:)),
      name: ethBalanceName,
      object: nil
    )
    let tokenBalanceName = Notification.Name(kOtherBalanceDidUpdateNotificationKey)
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(self.tokenBalancesDidUpdateNotification(_:)),
      name: tokenBalanceName,
      object: nil
    )
    let rateTokensName = Notification.Name(kExchangeTokenRateNotificationKey)
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(self.exchangeRateDidUpdateNotification(_:)),
      name: rateTokensName,
      object: nil)
    let rateUSDName = Notification.Name(kExchangeUSDRateNotificationKey)
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(self.exchangeRateDidUpdateNotification(_:)),
      name: rateUSDName,
      object: nil
    )
  }

  fileprivate func removeObserveNotifications() {
    let ethBalanceName = Notification.Name(kETHBalanceDidUpdateNotificationKey)
    NotificationCenter.default.removeObserver(self, name: ethBalanceName, object: nil)
    let tokenBalanceName = Notification.Name(kOtherBalanceDidUpdateNotificationKey)
    NotificationCenter.default.removeObserver(self, name: tokenBalanceName, object: nil)
    let rateTokensName = Notification.Name(kExchangeTokenRateNotificationKey)
    NotificationCenter.default.removeObserver(self, name: rateTokensName, object: nil)
    let rateUSDName = Notification.Name(kExchangeUSDRateNotificationKey)
    NotificationCenter.default.removeObserver(self, name: rateUSDName, object: nil)
  }

  @objc func tokenBalancesDidUpdateNotification(_ sender: Any) {
    self.rootViewController.coordinatorUpdateTokenBalances(self.balanceCoordinator.otherTokensBalance)
    self.exchangeRateDidUpdateNotification(sender)
  }

  @objc func ethBalanceDidUpdateNotification(_ sender: Any) {
    if let ethToken = KNJSONLoaderUtil.loadListSupportedTokensFromJSONFile().first(where: { $0.isETH }) {
      self.rootViewController.coordinatorUpdateTokenBalances([ethToken.address: self.balanceCoordinator.ethBalance])
    }
    self.exchangeRateDidUpdateNotification(sender)
  }

  @objc func exchangeRateDidUpdateNotification(_ sender: Any) {
    self.rootViewController.coordinatorUpdateBalanceInETHAndUSD(
      ethBalance: self.balanceCoordinator.totalBalanceInETH,
      usdBalance: self.balanceCoordinator.totalBalanceInUSD
    )
  }
}

extension KNWalletCoordinator: KNWalletViewControllerDelegate {
  func walletViewControllerDidExit() {
    self.delegate?.userDidClickExitSession()
  }
}
