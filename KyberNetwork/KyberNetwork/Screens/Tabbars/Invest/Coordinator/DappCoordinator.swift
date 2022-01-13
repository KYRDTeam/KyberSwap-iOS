//
//  DappCoordinator.swift
//  KyberNetwork
//
//  Created by Ta Minh Quan on 21/12/2021.
//

import Foundation
import TrustKeystore
import TrustCore
import CryptoKit
import Result
import APIKit
import JSONRPCKit
import MBProgressHUD
import QRCodeReaderViewController
import WalletConnectSwift
import BigInt

protocol DappCoordinatorDelegate: class {
  func dAppCoordinatorDidSelectAddWallet()
  func dAppCoordinatorDidSelectWallet(_ wallet: Wallet)
  func dAppCoordinatorDidSelectManageWallet()
}

class DappCoordinator: NSObject, Coordinator {
  let navigationController: UINavigationController
  var coordinators: [Coordinator] = []
  var session: KNSession
  fileprivate weak var transactionStatusVC: KNTransactionStatusPopUp?
  
  init(navigationController: UINavigationController = UINavigationController(), session: KNSession) {
    self.navigationController = navigationController
    self.session = session
  }
  
  lazy var rootViewController: DappBrowserHomeViewController = {
    let controller = DappBrowserHomeViewController()
    controller.delegate = self
    return controller
  }()
  
  private lazy var urlParser: BrowserURLParser = {
      return BrowserURLParser()
  }()
  
  fileprivate var currentWallet: KNWalletObject {
    let address = self.session.wallet.address.description
    return KNWalletStorage.shared.get(forPrimaryKey: address) ?? KNWalletObject(address: address)
  }
  
  private var browserViewController: BrowserViewController?
  private var transactionConfirm: DappBrowerTransactionConfirmPopup?
  
  weak var delegate: DappCoordinatorDelegate?
  
  func start() {
    self.navigationController.pushViewController(self.rootViewController, animated: true)
  }
  
  func stop() {
    
  }
  
  fileprivate func openWalletListView() {
    let viewModel = WalletsListViewModel(
      walletObjects: KNWalletStorage.shared.wallets,
      currentWallet: self.currentWallet
    )
    let walletsList = WalletsListViewController(viewModel: viewModel)
    walletsList.delegate = self
    self.navigationController.present(walletsList, animated: true, completion: nil)
  }
  
  func openBrowserScreen(searchText: String) {
    guard case .real(let account) = self.session.wallet.type else { return }
    guard let url = urlParser.url(from: searchText.trimmed) else { return }
    let vm = BrowserViewModel(url: url, account: account)
    let vc = BrowserViewController(viewModel: vm)
    vc.delegate = self
    self.navigationController.pushViewController(vc, animated: true)
    self.browserViewController = vc
  }

  func appCoordinatorDidUpdateChain() {
    guard let topVC = self.navigationController.topViewController, topVC is BrowserViewController, let unwrap = self.browserViewController else { return }
    guard case .real(let account) = self.session.wallet.type else {
      self.navigationController.popViewController(animated: true, completion: nil)
      return
    }
    let url = unwrap.viewModel.url
    self.navigationController.popViewController(animated: false) {
      let vm = BrowserViewModel(url: url, account: account)
      let vc = BrowserViewController(viewModel: vm)
      vc.delegate = self
      self.navigationController.pushViewController(vc, animated: false)
      self.browserViewController = vc
    }
  }

  func appCoordinatorDidUpdateNewSession(_ session: KNSession, resetRoot: Bool = false) {
    self.session = session
    self.appCoordinatorDidUpdateChain()
  }

  func coordinatorDidUpdateTransaction(_ tx: InternalHistoryTransaction) -> Bool {
    if let trans = self.transactionStatusVC?.transaction, trans.hash == tx.hash {
      self.transactionStatusVC?.updateView(with: tx)
      return true
    }
    return false
  }
}

extension DappCoordinator: DappBrowserHomeViewControllerDelegate {
  func dappBrowserHomeViewController(_ controller: DappBrowserHomeViewController, run event: DappBrowserHomeEvent) {
    switch event {
    case .enterText(let text):
      self.openBrowserScreen(searchText: text)
    case .showAllRecently:
      let viewModel = RecentlyHistoryViewModel { item in
        self.openBrowserScreen(searchText: item.url)
      }
      let controller = RecentlyHistoryViewController(viewModel: viewModel)
      self.navigationController.pushViewController(controller, animated: true, completion: nil)
    }
  }
}

extension DappCoordinator: BrowserViewControllerDelegate {
  func browserViewController(_ controller: BrowserViewController, run event: BrowserViewEvent) {
    switch event {
    case .openOption(let url):
      let controller = BrowserOptionsViewController(
        url: url,
        canGoBack: controller.webView.canGoBack,
        canGoForward: controller.webView.canGoForward
      )
      controller.delegate = self
      self.navigationController.present(controller, animated: true, completion: nil)
    case .switchChain:
      break
    }
  }
  
  func didCall(action: DappAction, callbackID: Int, inBrowserViewController viewController: BrowserViewController) {
    let url = viewController.viewModel.url.absoluteString
    func rejectDappAction() {
      viewController.coordinatorNotifyFinish(callbackID: callbackID, value: .failure(DAppError.cancelled))
      navigationController.topViewController?.displayError(error: InCoordinatorError.onlyWatchAccount)
    }
    
    func performDappAction(account: Address) {
      switch action {
      case .signTransaction(let unconfirmedTransaction):
        print(unconfirmedTransaction)
        self.executeTransaction(action: action, callbackID: callbackID, tx: unconfirmedTransaction, url: url)
      case .sendTransaction(let unconfirmedTransaction):
        print(unconfirmedTransaction)
        self.executeTransaction(action: action, callbackID: callbackID, tx: unconfirmedTransaction, url: url)
      case .signMessage(let hexMessage):
        let vm = SignMessageConfirmViewModel(
          url: url,
          address: self.session.wallet.address.description,
          message: hexMessage,
          onConfirm: {
            self.signMessage(with: .message(hexMessage.toHexData), callbackID: callbackID)
          },
          onCancel: {
            let error = DAppError.cancelled
            self.browserViewController?.coordinatorNotifyFinish(callbackID: callbackID, value: .failure(error))
          }
        )
        let vc = SignMessageConfirmPopup(viewModel: vm)
        self.navigationController.present(vc, animated: true, completion: nil)
      case .signPersonalMessage(let hexMessage):
        let vm = SignMessageConfirmViewModel(
          url: url,
          address: self.session.wallet.address.description,
          message: hexMessage,
          onConfirm: {
            self.signMessage(with: .personalMessage(hexMessage.toHexData), callbackID: callbackID)
          },
          onCancel: {
            let error = DAppError.cancelled
            self.browserViewController?.coordinatorNotifyFinish(callbackID: callbackID, value: .failure(error))
          }
        )
        let vc = SignMessageConfirmPopup(viewModel: vm)
        self.navigationController.present(vc, animated: true, completion: nil)
        
      case .ethCall(from: let from, to: let to, data: let data):
        let callRequest = CallRequest(to: to, data: data)
        let request = EtherServiceAlchemyRequest(batch: BatchFactory().create(callRequest))
        DispatchQueue.global().async {
          Session.send(request) { [weak self] result in
            guard let `self` = self else { return }
            DispatchQueue.main.async {
              switch result {
              case .success(let output):
                let callback = DappCallback(id: callbackID, value: .ethCall(output))
                self.browserViewController?.coordinatorNotifyFinish(callbackID: callbackID, value: .success(callback))
              case .failure(let error):
                if case let SessionTaskError.responseError(JSONRPCError.responseError(_, message: message, _)) = error {
                  self.browserViewController?.coordinatorNotifyFinish(callbackID: callbackID, value: .failure(.nodeError(message)))
                } else {
                  self.browserViewController?.coordinatorNotifyFinish(callbackID: callbackID, value: .failure(.cancelled))
                }
              }
            }
          }
        }
//      case .walletAddEthereumChain(let customChain):
//        break
      case .walletSwitchEthereumChain(let targetChain):
        guard let targetChainId = Int(chainId0xString: targetChain.chainId), let chainType = ChainType.make(chainID: targetChainId) else {
          let error = DAppError.nodeError("Invaild chain ID")
          self.browserViewController?.coordinatorNotifyFinish(callbackID: callbackID, value: .failure(error))
          return
        }
        if KNGeneralProvider.shared.customRPC.chainID == targetChainId {
          let callback = DappCallback(id: callbackID, value: .walletSwitchEthereumChain)
          self.browserViewController?.coordinatorNotifyFinish(callbackID: callbackID, value: .success(callback))
        } else {
          let alertController = KNPrettyAlertController(
            title: "",
            message: "Please switch to \(chainType.chainName()) to continue".toBeLocalised(),
            secondButtonTitle: "OK".toBeLocalised(),
            firstButtonTitle: "Cancel".toBeLocalised(),
            secondButtonAction: {
              KNGeneralProvider.shared.currentChain = chainType
              KNNotificationUtil.postNotification(for: kChangeChainNotificationKey, object: self.session.wallet.address.description)
            },
            firstButtonAction: {
              let error = DAppError.cancelled
              self.browserViewController?.coordinatorNotifyFinish(callbackID: callbackID, value: .failure(error))
            }
          )
          alertController.popupHeight = 220
          self.navigationController.present(alertController, animated: true, completion: nil)
        }
      default:
        self.navigationController.showTopBannerView(message: "This dApp action is not supported yet")
      }
    }
    
    switch session.wallet.type {
    case .real(let account):
      return performDappAction(account: account.address)
    case .watch(let account):
        switch action {
        case .signTransaction, .sendTransaction, .signMessage, .signPersonalMessage, .signTypedMessage, .signTypedMessageV3, .ethCall, .unknown, .sendRawTransaction:
            return rejectDappAction()
        case .walletAddEthereumChain, .walletSwitchEthereumChain:
          return performDappAction(account: account)
        }
    }
  }

  private func executeTransaction(action: DappAction, callbackID: Int, tx: SignTransactionObject, url: String) {
    self.askToAsyncSign(action: action, callbackID: callbackID, tx: tx, message: "Prepare to send your transaction", url: url) {
    }
  }

  private func signMessage(with type: SignMessageType, callbackID: Int) {
    guard case .real(let account) = self.session.wallet.type, let keystore = self.session.externalProvider?.keystore else { return }
    var result: Result<Data, KeystoreError>
    switch type {
    case .message(let data):
      result  = keystore.signPersonalMessage(data, for: account)
    case .personalMessage(let data):
      result = keystore.signPersonalMessage(data, for: account)
    }
    var callback: DappCallback
    switch result {
    case .success(let data):
      callback = DappCallback(id: callbackID, value: .signMessage(data))
      self.browserViewController?.coordinatorNotifyFinish(callbackID: callbackID, value: .success(callback))
    case .failure(let error):
      self.browserViewController?.coordinatorNotifyFinish(callbackID: callbackID, value: .failure(DAppError.cancelled))
    }
  }
  
  func askToAsyncSign(action: DappAction, callbackID: Int, tx: SignTransactionObject, message: String, url: String, sign: @escaping () -> Void) {
    guard case .real(let account) = self.session.wallet.type, let provider = self.session.externalProvider else {
      return
    }
    let onSign = { (setting: ConfirmAdvancedSetting) in
      print("[Debug] \(setting)")
      self.navigationController.displayLoading()
      self.getLatestNonce { nonce in
        var sendTx = tx
        sendTx.updateNonce(nonce: nonce)
        print("[Dapp] raw tx \(tx)")
        if KNGeneralProvider.shared.isUseEIP1559 {
          let eipTx = sendTx.toEIP1559Transaction(setting: setting)
          print("[Dapp] eip tx \(eipTx)")
          if let data = provider.signContractGenericEIP1559Transaction(eipTx) {
            KNGeneralProvider.shared.sendSignedTransactionData(data, completion: { sendResult in
              switch sendResult {
              case .success(let hash):
                print("[Dapp] hash \(hash)")
                let data = Data(_hex: hash)
                let callback = DappCallback(id: callbackID, value: .sentTransaction(data))
                self.browserViewController?.coordinatorNotifyFinish(callbackID: callbackID, value: .success(callback))

                let historyTransaction = InternalHistoryTransaction(
                  type: .contractInteraction,
                  state: .pending,
                  fromSymbol: nil,
                  toSymbol: nil,
                  transactionDescription: "DApp",
                  transactionDetailDescription: tx.to ?? "",
                  transactionObj: nil,
                  eip1559Tx: eipTx
                )
                historyTransaction.hash = hash
                historyTransaction.time = Date()
                historyTransaction.nonce = nonce
                EtherscanTransactionStorage.shared.appendInternalHistoryTransaction(historyTransaction)
                self.openTransactionStatusPopUp(transaction: historyTransaction)
              case .failure(let error):
                self.navigationController.displayError(error: error)
              }
              self.navigationController.hideLoading()
            })
          }
        } else {
          let signTx = sendTx.toSignTransaction(account: account, setting: setting)
          provider.signTransactionData(from: signTx) { [weak self] result in
            guard let `self` = self else { return }
            switch result {
            case .success(let signedData):
              KNGeneralProvider.shared.sendSignedTransactionData(signedData.0, completion: { sendResult in
                switch sendResult {
                case .success(let hash):
                  let data = Data(_hex: hash)
                  let callback = DappCallback(id: callbackID, value: .sentTransaction(data))
                  self.browserViewController?.coordinatorNotifyFinish(callbackID: callbackID, value: .success(callback))

                  let historyTransaction = InternalHistoryTransaction(
                    type: .contractInteraction,
                    state: .pending,
                    fromSymbol: nil,
                    toSymbol: nil,
                    transactionDescription: "DApp",
                    transactionDetailDescription: tx.to ?? "",
                    transactionObj: sendTx,
                    eip1559Tx: nil
                  )
                  historyTransaction.hash = hash
                  historyTransaction.time = Date()
                  historyTransaction.nonce = nonce
                  EtherscanTransactionStorage.shared.appendInternalHistoryTransaction(historyTransaction)
                  self.openTransactionStatusPopUp(transaction: historyTransaction)
                case .failure(let error):
                  self.navigationController.displayError(error: error)
                }
              })
            case .failure(let error):
              self.navigationController.displayError(error: error)
            }
            self.navigationController.hideLoading()
          }
        }
      }
    }
    let onCancel = {
      print("[Dapp] cancel")
      self.browserViewController?.coordinatorNotifyFinish(callbackID: callbackID, value: .failure(DAppError.cancelled))
    }
    
    let onChangeGasFee = { (gasLimit: BigInt, baseGasLimit: BigInt, selectType: KNSelectedGasPriceType, advancedGasLimit: String?, advancedPriorityFee: String?, advancedMaxFee: String?, advancedNonce: String?) in
      let viewModel = GasFeeSelectorPopupViewModel(isSwapOption: false, gasLimit: gasLimit, selectType: selectType, isContainSlippageSection: false)
      viewModel.baseGasLimit = baseGasLimit
      viewModel.updateGasPrices(
        fast: KNGasCoordinator.shared.fastKNGas,
        medium: KNGasCoordinator.shared.standardKNGas,
        slow: KNGasCoordinator.shared.lowKNGas,
        superFast: KNGasCoordinator.shared.superFastKNGas
      )
      viewModel.advancedGasLimit = advancedGasLimit
      viewModel.advancedMaxPriorityFee = advancedPriorityFee
      viewModel.advancedMaxFee = advancedMaxFee
      viewModel.advancedNonce = advancedNonce
      let vc = GasFeeSelectorPopupViewController(viewModel: viewModel)
      vc.delegate = self

      self.getLatestNonce { nonce in
        vc.coordinatorDidUpdateCurrentNonce(nonce)
      }

      self.transactionConfirm?.present(vc, animated: true, completion: nil)

    }
    
    let vm = DappBrowerTransactionConfirmViewModel(transaction: tx, url: url, onSign: onSign, onCancel: onCancel, onChangeGasFee: onChangeGasFee)
    let controller = DappBrowerTransactionConfirmPopup(viewModel: vm)
    self.navigationController.present(controller, animated: true, completion: nil)
    self.transactionConfirm = controller
  }

  func getLatestNonce(completion: @escaping (Int) -> Void) {
    guard let provider = self.session.externalProvider else {
      return
    }
    provider.getTransactionCount { [weak self] result in
      guard let `self` = self else { return }
      switch result {
      case .success(let res):
        completion(res)
      case .failure:
        self.getLatestNonce(completion: completion)
      }
    }
  }
  
  fileprivate func openTransactionStatusPopUp(transaction: InternalHistoryTransaction) {
    let controller = KNTransactionStatusPopUp(transaction: transaction)
    controller.delegate = self
    self.navigationController.present(controller, animated: true, completion: nil)
    self.transactionStatusVC = controller
  }
}

extension DappCoordinator: BrowserOptionsViewControllerDelegate {
  func browserOptionsViewController(_ controller: BrowserOptionsViewController, run event: BrowserOptionsViewEvent) {
    switch event {
    case .back:
      self.browserViewController?.coodinatorDidReceiveBackEvent()
    case .forward:
      self.browserViewController?.coodinatorDidReceiveForwardEvent()
    case .refresh:
      self.browserViewController?.coodinatorDidReceiveRefreshEvent()
    case .share:
      self.browserViewController?.coodinatorDidReceiveShareEvent()
    case .copy:
      self.browserViewController?.coodinatorDidReceiveCopyEvent()
    case .favourite:
      self.browserViewController?.coodinatorDidReceiveFavoriteEvent()
    case .switchWallet:
      self.openWalletListView()
      self.browserViewController?.coodinatorDidReceiveSwitchWalletEvent()
    }
  }
}

extension DappCoordinator: WalletsListViewControllerDelegate {
  func walletsListViewController(_ controller: WalletsListViewController, run event: WalletsListViewEvent) {
    switch event {
    case .connectWallet:
      let qrcode = QRCodeReaderViewController()
      qrcode.delegate = self
      self.navigationController.present(qrcode, animated: true, completion: nil)
    case .manageWallet:
      self.delegate?.dAppCoordinatorDidSelectManageWallet()
    case .copy(let wallet):
      UIPasteboard.general.string = wallet.address
      let hud = MBProgressHUD.showAdded(to: controller.view, animated: true)
      hud.mode = .text
      hud.label.text = NSLocalizedString("copied", value: "Copied", comment: "")
      hud.hide(animated: true, afterDelay: 1.5)
    case .select(let wallet):
      guard let wal = self.session.keystore.wallets.first(where: { $0.address.description.lowercased() == wallet.address.lowercased() }) else {
        return
      }
      self.delegate?.dAppCoordinatorDidSelectWallet(wal)
    case .addWallet:
      self.delegate?.dAppCoordinatorDidSelectAddWallet()
    }
  }
}

extension DappCoordinator: QRCodeReaderDelegate {
  func readerDidCancel(_ reader: QRCodeReaderViewController!) {
    reader.dismiss(animated: true, completion: nil)
  }

  func reader(_ reader: QRCodeReaderViewController!, didScanResult result: String!) {
    reader.dismiss(animated: true) {
      guard let url = WCURL(result) else {
        self.navigationController.showTopBannerView(
          with: "Invalid session".toBeLocalised(),
          message: "Your session is invalid, please try with another QR code".toBeLocalised(),
          time: 1.5
        )
        return
      }

      if case .real(let account) = self.session.wallet.type {
        let result = self.session.keystore.exportPrivateKey(account: account)
        switch result {
        case .success(let data):
          DispatchQueue.main.async {
            let pkString = data.hexString
            let controller = KNWalletConnectViewController(
              wcURL: url,
              knSession: self.session,
              pk: pkString
            )
            self.navigationController.present(controller, animated: true, completion: nil)
          }
          
        case .failure(_):
          self.navigationController.showTopBannerView(
            with: "Private Key Error",
            message: "Can not get Private key",
            time: 1.5
          )
        }
      }
    }
  }
}

extension DappCoordinator: GasFeeSelectorPopupViewControllerDelegate {
  func gasFeeSelectorPopupViewController(_ controller: GasFeeSelectorPopupViewController, run event: GasFeeSelectorPopupViewEvent) {
    switch event {
    case .gasPriceChanged(let type, let value):
      self.transactionConfirm?.coordinatorDidUpdateGasPriceType(type, value: value)
    case .helpPressed(let tag):
      var message = "Gas.fee.is.the.fee.you.pay.to.the.miner".toBeLocalised()
      switch tag {
      case 1:
        message = "gas.limit.help".toBeLocalised()
      case 2:
        message = "max.priority.fee.help".toBeLocalised()
      case 3:
        message = "max.fee.help".toBeLocalised()
      default:
        break
      }
      self.navigationController.showBottomBannerView(
        message: message,
        icon: UIImage(named: "help_icon_large") ?? UIImage(),
        time: 10
      )
    case .updateAdvancedSetting(gasLimit: let gasLimit, maxPriorityFee: let maxPriorityFee, maxFee: let maxFee):
      self.transactionConfirm?.coordinatorDidUpdateAdvancedSettings(gasLimit: gasLimit, maxPriorityFee: maxPriorityFee, maxFee: maxFee)
    case .updateAdvancedNonce(nonce: let nonce):
      self.transactionConfirm?.coordinatorDidUpdateAdvancedNonce(nonce)
    case .speedupTransaction(transaction: let transaction, original: let original):
      if let data = self.session.externalProvider?.signContractGenericEIP1559Transaction(transaction) {
        let savedTx = EtherscanTransactionStorage.shared.getInternalHistoryTransactionWithHash(original.hash)
        KNGeneralProvider.shared.sendSignedTransactionData(data, completion: { sendResult in
          switch sendResult {
          case .success(let hash):
            savedTx?.state = .speedup
            savedTx?.hash = hash
            if let unwrapped = savedTx {
              self.openTransactionStatusPopUp(transaction: unwrapped)
              KNNotificationUtil.postNotification(
                for: kTransactionDidUpdateNotificationKey,
                object: unwrapped,
                userInfo: nil
              )
            }
          case .failure(let error):
            print(error.description)
            var errorMessage = "Speedup failed"
            if case let APIKit.SessionTaskError.responseError(apiKitError) = error.error {
              if case let JSONRPCKit.JSONRPCError.responseError(_, message, _) = apiKitError {
                errorMessage = message
              }
            }
            self.navigationController.showTopBannerView(message: errorMessage)
          }
        })
      }
    case .cancelTransaction(transaction: let transaction, original: let original):
      if let data = self.session.externalProvider?.signContractGenericEIP1559Transaction(transaction) {
        let savedTx = EtherscanTransactionStorage.shared.getInternalHistoryTransactionWithHash(original.hash)

        KNGeneralProvider.shared.sendSignedTransactionData(data, completion: { sendResult in
          switch sendResult {
          case .success(let hash):
            savedTx?.state = .cancel
            savedTx?.type = .transferETH
            savedTx?.transactionSuccessDescription = "-0 ETH"
            savedTx?.hash = hash
            if let unwrapped = savedTx {
              self.openTransactionStatusPopUp(transaction: unwrapped)
              KNNotificationUtil.postNotification(
                for: kTransactionDidUpdateNotificationKey,
                object: unwrapped,
                userInfo: nil
              )
            }
          case .failure(let error):
            var errorMessage = "Cancel failed"
            if case let APIKit.SessionTaskError.responseError(apiKitError) = error.error {
              if case let JSONRPCKit.JSONRPCError.responseError(_, message, _) = apiKitError {
                errorMessage = message
              }
            }
            self.navigationController.showTopBannerView(message: errorMessage)
          }
        })
      }
    case .speedupTransactionLegacy(legacyTransaction: let transaction, original: let original):
      if case .real(let account) = self.session.wallet.type, let provider = self.session.externalProvider {
        let savedTx = EtherscanTransactionStorage.shared.getInternalHistoryTransactionWithHash(original.hash)
       
        let speedupTx = transaction.toSignTransaction(account: account)
        speedupTx.send(provider: provider) { (result) in
          switch result {
          case .success(let hash):
            savedTx?.state = .speedup
            savedTx?.hash = hash
            print("GasSelector][Legacy][Speedup][Sent] \(hash)")
            if let unwrapped = savedTx {
              self.openTransactionStatusPopUp(transaction: unwrapped)
              KNNotificationUtil.postNotification(
                for: kTransactionDidUpdateNotificationKey,
                object: unwrapped,
                userInfo: nil
              )
            }
          case .failure(let error):
            var errorMessage = "Speedup failed"
            if case let APIKit.SessionTaskError.responseError(apiKitError) = error.error {
              if case let JSONRPCKit.JSONRPCError.responseError(_, message, _) = apiKitError {
                errorMessage = message
              }
            }
            self.navigationController.showTopBannerView(message: errorMessage)
          }
        }
      }
    case .cancelTransactionLegacy(legacyTransaction: let transaction, original: let original):
      if case .real(let account) = self.session.wallet.type, let provider = self.session.externalProvider {
        let saved = EtherscanTransactionStorage.shared.getInternalHistoryTransactionWithHash(original.hash)
        
        let cancelTx = transaction.toSignTransaction(account: account)
        cancelTx.send(provider: provider) { (result) in
          switch result {
          case .success(let hash):
            saved?.state = .cancel
            saved?.type = .transferETH
            saved?.transactionSuccessDescription = "-0 ETH"
            saved?.hash = hash
            print("GasSelector][Legacy][Cancel][Sent] \(hash)")
            if let unwrapped = saved {
              self.openTransactionStatusPopUp(transaction: unwrapped)
              KNNotificationUtil.postNotification(
                for: kTransactionDidUpdateNotificationKey,
                object: unwrapped,
                userInfo: nil
              )
            }
          case .failure(let error):
            var errorMessage = "Cancel failed"
            if case let APIKit.SessionTaskError.responseError(apiKitError) = error.error {
              if case let JSONRPCKit.JSONRPCError.responseError(_, message, _) = apiKitError {
                errorMessage = message
              }
            }
            self.navigationController.showTopBannerView(message: errorMessage)
          }
        }
      }
      
    default:
      break
    }
  }
}

extension DappCoordinator: KNTransactionStatusPopUpDelegate {
  func transactionStatusPopUp(_ controller: KNTransactionStatusPopUp, action: KNTransactionStatusPopUpEvent) {
    self.transactionStatusVC = nil
    switch action {
//    case .transfer:
//      self.openSendTokenView()
    case .openLink(let url):
      self.navigationController.openSafari(with: url)
    case .speedUp(let tx):
      self.openTransactionSpeedUpViewController(transaction: tx)
    case .cancel(let tx):
      self.openTransactionCancelConfirmPopUpFor(transaction: tx)
    case .goToSupport:
      self.navigationController.openSafari(with: "https://support.krystal.app")
    default:
      break
    }
  }

  fileprivate func openTransactionSpeedUpViewController(transaction: InternalHistoryTransaction) {
    let gasLimit: BigInt = {
      if KNGeneralProvider.shared.isUseEIP1559 {
        return BigInt(transaction.eip1559Transaction?.reservedGasLimit.drop0x ?? "", radix: 16) ?? BigInt(0)
      } else {
        return BigInt(transaction.transactionObject?.reservedGasLimit ?? "") ?? BigInt(0)
      }
    }()
    let viewModel = GasFeeSelectorPopupViewModel(isSwapOption: true, gasLimit: gasLimit, selectType: .superFast, currentRatePercentage: 0, isUseGasToken: false)
    viewModel.updateGasPrices(
      fast: KNGasCoordinator.shared.fastKNGas,
      medium: KNGasCoordinator.shared.standardKNGas,
      slow: KNGasCoordinator.shared.lowKNGas,
      superFast: KNGasCoordinator.shared.superFastKNGas
    )

    viewModel.isSpeedupMode = true
    viewModel.transaction = transaction
    let vc = GasFeeSelectorPopupViewController(viewModel: viewModel)
    vc.delegate = self
    self.navigationController.present(vc, animated: true, completion: nil)
  }

  fileprivate func openTransactionCancelConfirmPopUpFor(transaction: InternalHistoryTransaction) {
    let gasLimit: BigInt = {
      if KNGeneralProvider.shared.isUseEIP1559 {
        return BigInt(transaction.eip1559Transaction?.reservedGasLimit.drop0x ?? "", radix: 16) ?? BigInt(0)
      } else {
        return BigInt(transaction.transactionObject?.reservedGasLimit ?? "") ?? BigInt(0)
      }
    }()
    
    let viewModel = GasFeeSelectorPopupViewModel(isSwapOption: true, gasLimit: gasLimit, selectType: .superFast, currentRatePercentage: 0, isUseGasToken: false)
    viewModel.updateGasPrices(
      fast: KNGasCoordinator.shared.fastKNGas,
      medium: KNGasCoordinator.shared.standardKNGas,
      slow: KNGasCoordinator.shared.lowKNGas,
      superFast: KNGasCoordinator.shared.superFastKNGas
    )
    
    viewModel.isCancelMode = true
    viewModel.transaction = transaction
    let vc = GasFeeSelectorPopupViewController(viewModel: viewModel)
    vc.delegate = self
    self.navigationController.present(vc, animated: true, completion: nil)
  }
}

//extension DappCoordinator: GasFeeSelectorPopupViewControllerDelegate {
//  func gasFeeSelectorPopupViewController(_ controller: GasFeeSelectorPopupViewController, run event: GasFeeSelectorPopupViewEvent) {
//    switch event {
//    case .helpPressed(let tag):
//      var message = "Gas.fee.is.the.fee.you.pay.to.the.miner".toBeLocalised()
//      switch tag {
//      case 1:
//        message = KNGeneralProvider.shared.isUseEIP1559 ? "gas.limit.help".toBeLocalised() : "gas.limit.legacy.help".toBeLocalised()
//      case 2:
//        message = "max.priority.fee.help".toBeLocalised()
//      case 3:
//        message = KNGeneralProvider.shared.isUseEIP1559 ? "max.fee.help".toBeLocalised() : "gas.price.legacy.help".toBeLocalised()
//      case 4:
//        message = "nonce.help".toBeLocalised()
//      default:
//        break
//      }
//      self.navigationController.showBottomBannerView(
//        message: message,
//        icon: UIImage(named: "help_icon_large") ?? UIImage(),
//        time: 10
//      )
//    case .speedupTransaction(transaction: let transaction, original: let original):
//      if let data = self.session.externalProvider?.signContractGenericEIP1559Transaction(transaction) {
//        let savedTx = EtherscanTransactionStorage.shared.getInternalHistoryTransactionWithHash(original.hash)
//        KNGeneralProvider.shared.sendSignedTransactionData(data, completion: { sendResult in
//          switch sendResult {
//          case .success(let hash):
//            savedTx?.state = .speedup
//            savedTx?.hash = hash
//            if let unwrapped = savedTx {
//              self.openTransactionStatusPopUp(transaction: unwrapped)
//              KNNotificationUtil.postNotification(
//                for: kTransactionDidUpdateNotificationKey,
//                object: unwrapped,
//                userInfo: nil
//              )
//            }
//          case .failure(let error):
//            print(error.description)
//            var errorMessage = "Speedup failed"
//            if case let APIKit.SessionTaskError.responseError(apiKitError) = error.error {
//              if case let JSONRPCKit.JSONRPCError.responseError(_, message, _) = apiKitError {
//                errorMessage = message
//              }
//            }
//            self.navigationController.showTopBannerView(message: errorMessage)
//          }
//        })
//      }
//    case .cancelTransaction(transaction: let transaction, original: let original):
//      if let data = self.session.externalProvider?.signContractGenericEIP1559Transaction(transaction) {
//        let savedTx = EtherscanTransactionStorage.shared.getInternalHistoryTransactionWithHash(original.hash)
//
//        KNGeneralProvider.shared.sendSignedTransactionData(data, completion: { sendResult in
//          switch sendResult {
//          case .success(let hash):
//            savedTx?.state = .cancel
//            savedTx?.type = .transferETH
//            savedTx?.transactionSuccessDescription = "-0 ETH"
//            savedTx?.hash = hash
//            if let unwrapped = savedTx {
//              self.openTransactionStatusPopUp(transaction: unwrapped)
//              KNNotificationUtil.postNotification(
//                for: kTransactionDidUpdateNotificationKey,
//                object: unwrapped,
//                userInfo: nil
//              )
//            }
//          case .failure(let error):
//            var errorMessage = "Cancel failed"
//            if case let APIKit.SessionTaskError.responseError(apiKitError) = error.error {
//              if case let JSONRPCKit.JSONRPCError.responseError(_, message, _) = apiKitError {
//                errorMessage = message
//              }
//            }
//            self.navigationController.showTopBannerView(message: errorMessage)
//          }
//        })
//      }
//    case .speedupTransactionLegacy(legacyTransaction: let transaction, original: let original):
//      if case .real(let account) = self.session.wallet.type, let provider = self.session.externalProvider {
//        let savedTx = EtherscanTransactionStorage.shared.getInternalHistoryTransactionWithHash(original.hash)
//
//        let speedupTx = transaction.toSignTransaction(account: account)
//        speedupTx.send(provider: provider) { (result) in
//          switch result {
//          case .success(let hash):
//            savedTx?.state = .speedup
//            savedTx?.hash = hash
//            print("GasSelector][Legacy][Speedup][Sent] \(hash)")
//            if let unwrapped = savedTx {
//              self.openTransactionStatusPopUp(transaction: unwrapped)
//              KNNotificationUtil.postNotification(
//                for: kTransactionDidUpdateNotificationKey,
//                object: unwrapped,
//                userInfo: nil
//              )
//            }
//          case .failure(let error):
//            var errorMessage = "Speedup failed"
//            if case let APIKit.SessionTaskError.responseError(apiKitError) = error.error {
//              if case let JSONRPCKit.JSONRPCError.responseError(_, message, _) = apiKitError {
//                errorMessage = message
//              }
//            }
//            self.navigationController.showTopBannerView(message: errorMessage)
//          }
//        }
//      }
//    case .cancelTransactionLegacy(legacyTransaction: let transaction, original: let original):
//      if case .real(let account) = self.session.wallet.type, let provider = self.session.externalProvider {
//        let saved = EtherscanTransactionStorage.shared.getInternalHistoryTransactionWithHash(original.hash)
//
//        let cancelTx = transaction.toSignTransaction(account: account)
//        cancelTx.send(provider: provider) { (result) in
//          switch result {
//          case .success(let hash):
//            saved?.state = .cancel
//            saved?.type = .transferETH
//            saved?.transactionSuccessDescription = "-0 ETH"
//            saved?.hash = hash
//            print("GasSelector][Legacy][Cancel][Sent] \(hash)")
//            if let unwrapped = saved {
//              self.openTransactionStatusPopUp(transaction: unwrapped)
//              KNNotificationUtil.postNotification(
//                for: kTransactionDidUpdateNotificationKey,
//                object: unwrapped,
//                userInfo: nil
//              )
//            }
//          case .failure(let error):
//            var errorMessage = "Cancel failed"
//            if case let APIKit.SessionTaskError.responseError(apiKitError) = error.error {
//              if case let JSONRPCKit.JSONRPCError.responseError(_, message, _) = apiKitError {
//                errorMessage = message
//              }
//            }
//            self.navigationController.showTopBannerView(message: errorMessage)
//          }
//        }
//      }
//    default:
//      break
//    }
//  }
//
//  fileprivate func saveUseGasTokenState(_ state: Bool) {
//    var data: [String: Bool] = [:]
//    if let saved = UserDefaults.standard.object(forKey: Constants.useGasTokenDataKey) as? [String: Bool] {
//      data = saved
//    }
//    data[self.session.wallet.address.description] = state
//    UserDefaults.standard.setValue(data, forKey: Constants.useGasTokenDataKey)
//  }
//
//  fileprivate func isApprovedGasToken() -> Bool {
//    var data: [String: Bool] = [:]
//    if let saved = UserDefaults.standard.object(forKey: Constants.useGasTokenDataKey) as? [String: Bool] {
//      data = saved
//    } else {
//      return false
//    }
//    return data.keys.contains(self.session.wallet.address.description)
//  }
//
//  fileprivate func isAccountUseGasToken() -> Bool {
//    var data: [String: Bool] = [:]
//    if let saved = UserDefaults.standard.object(forKey: Constants.useGasTokenDataKey) as? [String: Bool] {
//      data = saved
//    } else {
//      return false
//    }
//    return data[self.session.wallet.address.description] ?? false
//  }
//}
