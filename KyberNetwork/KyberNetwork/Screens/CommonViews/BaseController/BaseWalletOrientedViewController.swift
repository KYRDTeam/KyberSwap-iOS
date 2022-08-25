//
//  BaseWalletOrientedViewController.swift
//  KyberNetwork
//
//  Created by Tung Nguyen on 24/08/2022.
//

import UIKit
import KrystalWallets
import QRCodeReaderViewController
import WalletConnectSwift

class BaseWalletOrientedViewController: KNBaseViewController {
  @IBOutlet weak var walletButton: UIButton?
  @IBOutlet weak var chainIcon: UIImageView?
  @IBOutlet weak var chainButton: UIButton?
  
  var walletConnectQRReaderDelegate: KQRCodeReaderDelegate?
  
  var currentChain: ChainType {
    return KNGeneralProvider.shared.currentChain
  }
  
  var currentAddress: KAddress {
    return AppDelegate.session.address
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    observeNotifications()
    reloadWalletName()
    reloadChain()
    setupDelegates()
  }
  
  func setupDelegates() {
    walletConnectQRReaderDelegate = KQRCodeReaderDelegate(onResult: { result in
      self.handleWalletConnectQRCode(result: result)
    })
  }
  
  func handleWalletConnectQRCode(result: String) {
    guard let url = WCURL(result) else {
      self.showTopBannerView(
        with: Strings.invalidSession,
        message: Strings.invalidSessionTryOtherQR,
        time: 1.5
      )
      return
    }
    do {
      let privateKey = try WalletManager.shared.exportPrivateKey(address: self.currentAddress)
      DispatchQueue.main.async {
        let controller = KNWalletConnectViewController(
          wcURL: url,
          pk: privateKey
        )
        self.present(controller, animated: true, completion: nil)
      }
    } catch {
      self.showTopBannerView(
        with: Strings.privateKeyError,
        message: Strings.canNotGetPrivateKey,
        time: 1.5
      )
    }
  }
  
  deinit {
    unobserveNotifications()
  }
  
  func observeNotifications() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(onSwitchChain),
      name: AppEventCenter.shared.kAppDidSwitchChain,
      object: nil
    )
  }
  
  func unobserveNotifications() {
    NotificationCenter.default.removeObserver(self, name: AppEventCenter.shared.kAppDidChangeAddress, object: nil)
    NotificationCenter.default.removeObserver(self, name: AppEventCenter.shared.kAppDidSwitchChain, object: nil)
  }
  
  func reloadWalletName() {
    walletButton?.setTitle(currentAddress.name, for: .normal)
  }
  
  func reloadChain() {
    chainIcon?.image = KNGeneralProvider.shared.currentChain.squareIcon()
    chainButton?.setTitle(KNGeneralProvider.shared.currentChain.chainName(), for: .normal)
  }
  
  @IBAction func onWalletButtonTapped(_ sender: UIButton) {
    openWalletList()
  }
  
  @IBAction func onChainButtonTapped(_ sender: UIButton) {
    openSwitchChain()
  }
  
  @objc func onSwitchChain() {
    reloadChain()
  }
  
  func openWalletConnect() {
    let qrcode = QRCodeReaderViewController()
    qrcode.delegate = walletConnectQRReaderDelegate
    present(qrcode, animated: true, completion: nil)
  }
  
  func openWalletList() {
    let walletsList = WalletListV2ViewController()
    walletsList.delegate = self
    let navigation = UINavigationController(rootViewController: walletsList)
    navigation.setNavigationBarHidden(true, animated: false)
    present(navigation, animated: true, completion: nil)
  }
  
  func openSwitchChain() {
    let popup = SwitchChainViewController()
    popup.dataSource = WalletManager.shared.getAllAddresses(walletID: currentAddress.walletID).flatMap { address in
      return ChainType.allCases.filter { chain in
        return chain != .all && chain.addressType == address.addressType
      }
    }
    popup.completionHandler = { selectedChain in
      KNGeneralProvider.shared.currentChain = selectedChain
      AppEventCenter.shared.switchChain(chain: selectedChain)
    }
    present(popup, animated: true, completion: nil)
  }

}

extension BaseWalletOrientedViewController: WalletListV2ViewControllerDelegate {
  
  func didSelectAddWallet() {
    
  }
  
  func didSelectWallet(wallet: KWallet) {
    let addresses = WalletManager.shared.getAllAddresses(walletID: wallet.id)
    guard addresses.isNotEmpty else { return }
    if let matchingChainAddress = addresses.first(where: { $0.addressType == currentChain.addressType }) {
      AppDelegate.shared.coordinator.switchAddress(address: matchingChainAddress)
    } else {
      let address = addresses.first!
      guard let chain = ChainType.allCases.first(where: { $0 != .all && $0.addressType == address.addressType }) else { return }
      KNGeneralProvider.shared.currentChain = chain
      AppEventCenter.shared.switchChain(chain: chain)
      AppDelegate.shared.coordinator.switchAddress(address: address)
    }
  }
  
  func didSelectWatchWallet(address: KAddress) {
    if address.addressType == currentChain.addressType {
      AppDelegate.shared.coordinator.switchToWatchAddress(address: address, chain: currentChain)
    } else {
      guard let chain = ChainType.allCases.first(where: { $0 != .all && $0.addressType == address.addressType }) else { return }
      AppDelegate.shared.coordinator.switchToWatchAddress(address: address, chain: chain)
    }
  }
  
  func walletsListViewController(_ controller: WalletsListViewController, run event: WalletsListViewEvent) {
    switch event {
    case .connectWallet:
      self.openWalletConnect()
    case .manageWallet:
      return
    case .didSelect:
      self.reloadWalletName()
      return
    case .addWallet:
      // TODO: Add wallet
      //      self.delegate?.swapV2CoordinatorDidSelectAddWallet()
      return
    }
  }
  
}
