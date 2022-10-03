//
//  SwapV2Coordinator.swift
//  KyberNetwork
//
//  Created by Tung Nguyen on 10/08/2022.
//

import Foundation
import UIKit
import QRCodeReaderViewController
import WalletConnectSwift
import KrystalWallets
import BigInt

protocol SwapV2CoordinatorDelegate: AnyObject {
  func swapV2CoordinatorDidSelectManageWallets()
  func swapV2CoordinatorDidSelectAddWallet()
  func swapV2CoordinatorDidSelectAddWalletForChain(chain: ChainType)
}

class SwapV2Coordinator: NSObject, Coordinator {
  var coordinators: [Coordinator] = []
  var rootViewController: SwapV2ViewController!
  var navigationController: UINavigationController!
  weak var delegate: SwapV2CoordinatorDelegate?
  var historyCoordinator: Coordinator?
  
  func start() {
    let vc = SwapV2ViewController.instantiateFromNib()
    let viewModel = SwapV2ViewModel(
      actions: SwapV2ViewModelActions(
        onSelectSwitchChain: {
          self.openSwitchChain()
        },
        onSelectSwitchWallet: {
          self.openSwitchWallet()
        },
        onSelectOpenHistory: {
          self.openTransactionHistory()
        },
        openSwapConfirm: { swapObject in
          self.openSwapConfirm(object: swapObject)
        },
        openApprove: { tokenObject, amount in
          self.openApprove(token: tokenObject, amount: amount)
        },
        openSettings: { gasLimit, rate, settings in
          self.openTransactionSettings(gasLimit: gasLimit, rate: rate, settings: settings)
        }
      )
    )
    vc.viewModel = viewModel
    self.rootViewController = vc
    self.navigationController = UINavigationController(rootViewController: vc)
  }
  
  func appCoordinatorShouldOpenExchangeForToken(_ token: Token, isReceived: Bool = false) {
    self.navigationController.popToRootViewController(animated: true)
    if isReceived {
      self.rootViewController.viewModel.updateDestToken(token: token)
    } else {
      self.rootViewController.viewModel.updateSourceToken(token: token)
    }
  }
  
  func openSwapConfirm(object: SwapObject) {
    let viewModel = SwapSummaryViewModel(swapObject: object)
    let swapSummaryVC = SwapSummaryViewController(viewModel: viewModel)
    swapSummaryVC.delegate = rootViewController
    let nav = UINavigationController(rootViewController: swapSummaryVC)
    nav.modalPresentationStyle = .overFullScreen
    self.rootViewController.present(nav, animated: true)
    MixPanelManager.track("swap_confirm_pop_up_open", properties: ["screenid": "swap_confirm_pop_up"])
  }
  
  func openTransactionSettings(gasLimit: BigInt, rate: Rate?, settings: SwapTransactionSettings) {
    let advancedGasLimit = (settings.advanced?.gasLimit).map(String.init)
    let advancedMaxPriorityFee = (settings.advanced?.maxPriorityFee).map {
      return NumberFormatUtils.format(value: $0, decimals: 9, maxDecimalMeaningDigits: 2, maxDecimalDigits: 2)
    }
    let advancedMaxFee = (settings.advanced?.maxFee).map {
      return NumberFormatUtils.format(value: $0, decimals: 9, maxDecimalMeaningDigits: 2, maxDecimalDigits: 2)
    }
    let advancedNonce = (settings.advanced?.nonce).map { "\($0)" }
    
    let vm = TransactionSettingsViewModel(gasLimit: gasLimit, selectType: settings.basic?.gasPriceType ?? .medium, rate: rate, defaultOpenAdvancedMode: settings.advanced != nil)
    let popup = TransactionSettingsViewController(viewModel: vm)
    vm.update(priorityFee: advancedMaxPriorityFee, maxGas: advancedMaxFee, gasLimit: advancedGasLimit, nonceString: advancedNonce)
    
    vm.saveEventHandler = { [weak self] swapSettings in
      self?.rootViewController.viewModel.updateSettings(settings: swapSettings)
    }
    self.navigationController.pushViewController(popup, animated: true, completion: nil)
    MixPanelManager.track("swap_txn_setting_pop_up_open", properties: ["screenid": "swap_txn_setting_pop_up"])
  }
  
  func openApprove(token: TokenObject, amount: BigInt) {
    let vc = ApproveTokenViewController(viewModel: ApproveTokenViewModelForTokenObject(token: token, res: amount))
    vc.delegate = self
    navigationController.present(vc, animated: true, completion: nil)
  }

  func openTransactionHistory() {
    switch KNGeneralProvider.shared.currentChain {
    case .solana:
      let coordinator = KNTransactionHistoryCoordinator(navigationController: navigationController, type: .solana)
      coordinator.delegate = self
      self.historyCoordinator = coordinator
      coordinate(coordinator: coordinator)
    default:
      let coordinator = KNHistoryCoordinator(navigationController: self.navigationController)
      coordinator.delegate = self
      self.historyCoordinator = coordinator
      coordinate(coordinator: coordinator)
    }
  }
  
  func openSwitchChain() {
    let popup = SwitchChainViewController()
    popup.completionHandler = { [weak self] selectedChain in
      let addresses = WalletManager.shared.getAllAddresses(addressType: selectedChain.addressType)
      if addresses.isEmpty {
        self?.delegate?.swapV2CoordinatorDidSelectAddWalletForChain(chain: selectedChain)
        return
      } else {
        let viewModel = SwitchChainWalletsListViewModel(selected: selectedChain)
        let secondPopup = SwitchChainWalletsListViewController(viewModel: viewModel)
        self?.rootViewController.present(secondPopup, animated: true, completion: nil)
      }
    }
    self.rootViewController.present(popup, animated: true, completion: nil)
  }
  
  func openSwitchWallet() {
    let viewModel = WalletsListViewModel()
    let walletsList = WalletsListViewController(viewModel: viewModel)
    walletsList.delegate = self
    self.navigationController.present(walletsList, animated: true, completion: nil)
  }
  
  func openWalletConnect() {
    let qrcode = QRCodeReaderViewController()
    qrcode.delegate = self
    self.navigationController.present(qrcode, animated: true, completion: nil)
  }
  
}

extension SwapV2Coordinator: WalletsListViewControllerDelegate {
  func walletsListViewController(_ controller: WalletsListViewController, run event: WalletsListViewEvent) {
    switch event {
    case .connectWallet:
      self.openWalletConnect()
    case .manageWallet:
      self.delegate?.swapV2CoordinatorDidSelectManageWallets()
    case .didSelect:
      return
    case .addWallet:
      self.delegate?.swapV2CoordinatorDidSelectAddWallet()
    }
  }
}

extension SwapV2Coordinator: QRCodeReaderDelegate {
  func readerDidCancel(_ reader: QRCodeReaderViewController!) {
    reader.dismiss(animated: true, completion: nil)
  }

  func reader(_ reader: QRCodeReaderViewController!, didScanResult result: String!) {
    reader.dismiss(animated: true) {
      guard let url = WCURL(result) else {
        self.navigationController.showTopBannerView(
          with: Strings.invalidSession,
          message: Strings.invalidSessionTryOtherQR,
          time: 1.5
        )
        return
      }
      do {
        let currentAddress = self.rootViewController.viewModel.currentAddress.value
        let privateKey = try WalletManager.shared.exportPrivateKey(address: currentAddress)
        DispatchQueue.main.async {
          let controller = KNWalletConnectViewController(
            wcURL: url,
            pk: privateKey
          )
          self.navigationController.present(controller, animated: true, completion: nil)
        }
      } catch {
        self.navigationController.showTopBannerView(
          with: Strings.privateKeyError,
          message: Strings.canNotGetPrivateKey,
          time: 1.5
        )
      }
    }
  }
}

extension SwapV2Coordinator: KNHistoryCoordinatorDelegate {
  
  func historyCoordinatorDidSelectAddChainWallet(chainType: ChainType) {
    self.delegate?.swapV2CoordinatorDidSelectAddWalletForChain(chain: chainType)
  }
  
  func historyCoordinatorDidSelectAddToken(_ token: TokenObject) {
    // No need to handle
  }
  
  func historyCoordinatorDidSelectAddWallet() {
    self.delegate?.swapV2CoordinatorDidSelectAddWallet()
  }

  func historyCoordinatorDidSelectManageWallet() {
    self.delegate?.swapV2CoordinatorDidSelectManageWallets()
  }

  func historyCoordinatorDidClose() {
    removeCoordinator(historyCoordinator!)
    historyCoordinator = nil
  }
  
}

extension SwapV2Coordinator: ApproveTokenViewControllerDelegate {
  
  func approveTokenViewControllerDidApproved(_ controller: ApproveTokenViewController, token: TokenObject, remain: BigInt, gasLimit: BigInt) {
    rootViewController.viewModel.approve(tokenAddress: token.address, currentAllowance: remain, gasLimit: gasLimit)
  }
  
  func approveTokenViewControllerDidApproved(_ controller: ApproveTokenViewController, address: String, remain: BigInt, state: Bool, toAddress: String?, gasLimit: BigInt) {
    rootViewController.viewModel.approve(tokenAddress: address, currentAllowance: remain, gasLimit: gasLimit)
  }
  
  func approveTokenViewControllerGetEstimateGas(_ controller: ApproveTokenViewController, tokenAddress: String, value: BigInt) {
    
  }
  
  func approveTokenViewControllerDidSelectGasSetting(_ controller: ApproveTokenViewController, gasLimit: BigInt, baseGasLimit: BigInt, selectType: KNSelectedGasPriceType, advancedGasLimit: String?, advancedPriorityFee: String?, advancedMaxFee: String?, advancedNonce: String?) {
    
  }
  
}

extension SwapV2Coordinator {
  func appCoordinatorReceivedTokensSwapFromUniversalLink(srcTokenAddress: String?, destTokenAddress: String?, chainIdString: String?) {
    // default swap screen
    self.navigationController.tabBarController?.selectedIndex = 1
    self.navigationController.popToRootViewController(animated: false)
    guard let chainIdString = chainIdString else {
      return
    }

    let chainId = Int(chainIdString) ?? AllChains.ethMainnetPRC.chainID
    //switch chain if need
    if KNGeneralProvider.shared.customRPC.chainID != chainId {
      let chain = ChainType.make(chainID: chainId) ?? .eth
      self.rootViewController.showSwitchChainAlert(chain, "Please switch to \(chain.chainName()) to swap".toBeLocalised()) {
        self.prepareTokensForSwap(srcTokenAddress: srcTokenAddress, destTokenAddress: destTokenAddress, chainId: chainId, isFromDeepLink: true)
      }
    } else {
      self.prepareTokensForSwap(srcTokenAddress: srcTokenAddress, destTokenAddress: destTokenAddress, chainId: chainId, isFromDeepLink: true)
    }
  }

  func prepareTokensForSwap(srcTokenAddress: String?, destTokenAddress: String?, chainId: Int, isFromDeepLink: Bool = false) {
    // default token
    var fromToken = KNGeneralProvider.shared.currentChain.quoteTokenObject()
    var toToken = KNGeneralProvider.shared.currentChain.defaultToSwapToken()

    var newAddress: [String] = []
    guard let srcTokenAddress = srcTokenAddress, let destTokenAddress = destTokenAddress else {
      self.updateToken(sourceToken: fromToken.toToken(), destToken: toToken.toToken())
      return
    }

    let isValidSrcAddress = KNGeneralProvider.shared.isAddressValid(address: srcTokenAddress)
    let isValidDestTokenAddress = KNGeneralProvider.shared.isAddressValid(address: destTokenAddress)
    
    guard isValidSrcAddress, isValidDestTokenAddress else {
      self.updateToken(sourceToken: fromToken.toToken(), destToken: toToken.toToken())
      return
    }
    // in case can get token with given address
    if let token = KNSupportedTokenStorage.shared.get(forPrimaryKey: srcTokenAddress) {
       fromToken = token
    } else {
       newAddress.append(srcTokenAddress)
    }

    if let token = KNSupportedTokenStorage.shared.get(forPrimaryKey: destTokenAddress) {
      toToken = token
    } else {
      newAddress.append(destTokenAddress)
    }
    if newAddress.isEmpty {
      // there are no new address then show swap screen
      self.updateToken(sourceToken: fromToken.toToken(), destToken: toToken.toToken())
    } else if isFromDeepLink {
      self.navigationController.popToRootViewController(animated: false)
    }
  }
  
  func updateToken(sourceToken: Token, destToken: Token) {
    self.rootViewController.viewModel.updateSourceToken(token: sourceToken)
    self.rootViewController.viewModel.updateDestToken(token: destToken)
  }

}
