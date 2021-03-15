// Copyright SIX DAY LLC. All rights reserved.

import UIKit
import BigInt
import TrustKeystore
import Result
import Moya
import APIKit
import MBProgressHUD
import QRCodeReaderViewController
import WalletConnect

protocol KNSendTokenViewCoordinatorDelegate: class {
  func sendTokenViewCoordinatorDidUpdateWalletObjects()
  func sendTokenViewCoordinatorDidSelectRemoveWallet(_ wallet: Wallet)
  func sendTokenViewCoordinatorDidSelectWallet(_ wallet: Wallet)
  func sendTokenViewCoordinatorSelectOpenHistoryList()
  func sendTokenCoordinatorDidSelectManageWallet()
  func sendTokenCoordinatorDidSelectAddWallet()
}

class KNSendTokenViewCoordinator: NSObject, Coordinator {
  weak var delegate: KNSendTokenViewCoordinatorDelegate?

  let navigationController: UINavigationController
  fileprivate var session: KNSession
  var coordinators: [Coordinator] = []
  var balances: [String: Balance] = [:]
  fileprivate var from: TokenObject
  fileprivate var currentWallet: KNWalletObject {
    let address = self.session.wallet.address.description
    return KNWalletStorage.shared.get(forPrimaryKey: address) ?? KNWalletObject(address: address)
  }

  lazy var rootViewController: KSendTokenViewController = {
    let address = self.session.wallet.address.description
    let viewModel = KNSendTokenViewModel(
      from: self.from,
      balances: self.balances,
      currentAddress: address
    )
    let controller = KSendTokenViewController(viewModel: viewModel)
    controller.loadViewIfNeeded()
    controller.delegate = self
    return controller
  }()

  fileprivate(set) var searchTokensVC: KNSearchTokenViewController?
  fileprivate(set) var confirmVC: KConfirmSendViewController?
  fileprivate(set) weak var gasPriceSelector: GasFeeSelectorPopupViewController?
  fileprivate var transactionStatusVC: KNTransactionStatusPopUp?

  lazy var addContactVC: KNNewContactViewController = {
    let viewModel: KNNewContactViewModel = KNNewContactViewModel(address: "")
    let controller = KNNewContactViewController(viewModel: viewModel)
    controller.loadViewIfNeeded()
    controller.delegate = self
    return controller
  }()

  deinit {
    self.rootViewController.removeObserveNotification()
  }

  init(
    navigationController: UINavigationController,
    session: KNSession,
    balances: [String: Balance],
    from: TokenObject = KNSupportedTokenStorage.shared.ethToken
    ) {
    self.navigationController = navigationController
    self.session = session
    self.balances = balances
    self.from = from
    if self.from.isPromoToken {
      self.from = KNSupportedTokenStorage.shared.ethToken
    }
  }

  func start() {
    self.navigationController.pushViewController(self.rootViewController, animated: true)
    self.rootViewController.coordinatorUpdateBalances(self.balances)

    let isPromo = KNWalletPromoInfoStorage.shared.getDestinationToken(from: self.session.wallet.address.description) != nil
    self.rootViewController.coordinatorUpdateIsPromoWallet(isPromo)
  }

  func stop() {
    self.navigationController.popViewController(animated: true)
  }
}

// MARK: Update from coordinator
extension KNSendTokenViewCoordinator {
  func coordinatorTokenBalancesDidUpdate(balances: [String: Balance]) {
    balances.forEach { self.balances[$0.key] = $0.value }
    self.rootViewController.coordinatorUpdateBalances(self.balances)
    self.searchTokensVC?.updateBalances(self.balances)
  }

  func coordinatorShouldOpenSend(from token: TokenObject) {
    self.rootViewController.coordinatorDidUpdateSendToken(token, balance: self.balances[token.contract])
  }

  func coordinatorTokenObjectListDidUpdate(_ tokenObjects: [TokenObject]) {
    self.searchTokensVC?.updateListSupportedTokens(tokenObjects)
  }

  func coordinatorGasPriceCachedDidUpdate() {
    self.rootViewController.coordinatorUpdateGasPriceCached()
    self.gasPriceSelector?.coordinatorDidUpdateGasPrices(
      fast: KNGasCoordinator.shared.fastKNGas,
      medium: KNGasCoordinator.shared.standardKNGas,
      slow: KNGasCoordinator.shared.lowKNGas,
      superFast: KNGasCoordinator.shared.superFastKNGas
    )
  }

  func coordinatorOpenSendView(to address: String) {
    self.rootViewController.coordinatorSend(to: address)
  }

  func coordinatorDidUpdateTrackerRate() {
    self.rootViewController.coordinatorUpdateTrackerRate()
  }

  func coordinatorDidUpdateTransaction(_ tx: KNTransaction?, txID: String) -> Bool {
    if let txHash = self.transactionStatusVC?.transaction.id, txHash == txID {
      self.transactionStatusVC?.updateView(with: tx)
      return true
    }
    return false
  }
}

// MARK: Send Token View Controller Delegate
extension KNSendTokenViewCoordinator: KSendTokenViewControllerDelegate {
  func kSendTokenViewController(_ controller: KSendTokenViewController, run event: KSendTokenViewEvent) {
    switch event {
    case .back:
      self.stop()
    case .setGasPrice:
      break
    case .estimateGas(let transaction):
      self.estimateGasLimit(for: transaction)
    case .searchToken(let selectedToken):
      self.openSearchToken(selectedToken: selectedToken)
    case .validate:
      // validate transaction before transfer,
      // currently only validate sender's address, could be added more later
      guard self.session.externalProvider != nil else {
        self.navigationController.showTopBannerView(message: "Watch wallet can not do this operation".toBeLocalised())
        return
      }
      controller.displayLoading()
      self.sendGetPreScreeningWalletRequest { [weak self] (result) in
        controller.hideLoading()
        guard let `self` = self else { return }
        var message: String?
        if case .success(let resp) = result,
          let json = try? resp.mapJSON() as? JSONDictionary ?? [:] {
          if let status = json["eligible"] as? Bool {
            if isDebug { print("eligible status : \(status)") }
            if status == false { message = json["message"] as? String }
          }
        }
        if let errorMessage = message {
          self.navigationController.showErrorTopBannerMessage(
            with: NSLocalizedString("error", value: "Error", comment: ""),
            message: errorMessage,
            time: 2.0
          )
        } else {
          self.rootViewController.coordinatorDidValidateTransferTransaction()
        }
      }
    case .send(let transaction, let ens):
      self.openConfirmTransfer(transaction: transaction, ens: ens)
    case .addContact(let address, let ens):
      self.openNewContact(address: address, ens: ens)
    case .contactSelectMore:
      self.openListContactsView()
    case .openGasPriceSelect(let gasLimit, let selectType):
      let viewModel = GasFeeSelectorPopupViewModel(isSwapOption: false, gasLimit: gasLimit, selectType: selectType)
      viewModel.updateGasPrices(
        fast: KNGasCoordinator.shared.fastKNGas,
        medium: KNGasCoordinator.shared.standardKNGas,
        slow: KNGasCoordinator.shared.lowKNGas,
        superFast: KNGasCoordinator.shared.superFastKNGas
      )

      let vc = GasFeeSelectorPopupViewController(viewModel: viewModel)
      vc.delegate = self
      self.navigationController.present(vc, animated: true, completion: nil)
      self.gasPriceSelector = vc
    case .openHistory:
      self.delegate?.sendTokenViewCoordinatorSelectOpenHistoryList()
    case .openWalletsList:
      let viewModel = WalletsListViewModel(
        walletObjects: KNWalletStorage.shared.wallets,
        currentWallet: self.currentWallet
      )
      let walletsList = WalletsListViewController(viewModel: viewModel)
      walletsList.delegate = self
      self.navigationController.present(walletsList, animated: true, completion: nil)
    }
  }

  fileprivate func sendGetPreScreeningWalletRequest(completion: @escaping (Result<Moya.Response, MoyaError>) -> Void) {
    let address = self.session.wallet.address.description
    DispatchQueue.global(qos: .background).async {
      let provider = MoyaProvider<UserInfoService>()
      provider.request(.getPreScreeningWallet(address: address)) { result in
        DispatchQueue.main.async {
          completion(result)
        }
      }
    }
  }

  fileprivate func estimateGasLimit(for transaction: UnconfirmedTransaction) {
    guard let provider = self.session.externalProvider else {
      return
    }
    provider.getEstimateGasLimit(
    for: transaction) { [weak self] result in
      if case .success(let gasLimit) = result {
        self?.rootViewController.coordinatorUpdateEstimatedGasLimit(
          gasLimit,
          from: transaction.transferType.tokenObject(),
          address: transaction.to?.description ?? ""
        )
        self?.gasPriceSelector?.coordinatorDidUpdateGasLimit(gasLimit)
      } else {
        self?.rootViewController.coordinatorFailedToUpdateEstimateGasLimit()
      }
    }
  }

  fileprivate func openSearchToken(selectedToken: TokenObject) {
    let tokens = self.session.tokenStorage.tokens
    self.searchTokensVC = {
      let viewModel = KNSearchTokenViewModel(
        supportedTokens: tokens
      )
      let controller = KNSearchTokenViewController(viewModel: viewModel)
      controller.loadViewIfNeeded()
      controller.delegate = self
      return controller
    }()
    self.navigationController.present(self.searchTokensVC!, animated: true, completion: nil)
    self.searchTokensVC?.updateBalances(self.balances)
  }

  fileprivate func openConfirmTransfer(transaction: UnconfirmedTransaction, ens: String?) {
    if ens != nil {
      KNCrashlyticsUtil.logCustomEvent(withName: "tranfer_send_using_ens", customAttributes: nil)
    }
    if self.session.transactionStorage.kyberPendingTransactions.isEmpty {
      self.confirmVC = {
        let viewModel = KConfirmSendViewModel(transaction: transaction, ens: ens)
        let controller = KConfirmSendViewController(viewModel: viewModel)
        controller.delegate = self
        controller.loadViewIfNeeded()
        return controller
      }()
      self.navigationController.present(self.confirmVC!, animated: true, completion: nil)
    } else {
      let message = NSLocalizedString("Please wait for other transactions to be mined before making a transfer", comment: "")
      self.navigationController.showWarningTopBannerMessage(
        with: "",
        message: message,
        time: 2.0
      )
    }
  }

  fileprivate func openNewContact(address: String, ens: String?) {
    let viewModel: KNNewContactViewModel = KNNewContactViewModel(address: address, ens: ens)
    self.addContactVC.updateView(viewModel: viewModel)
    self.navigationController.pushViewController(self.addContactVC, animated: true)
  }

  fileprivate func openListContactsView() {
    let controller = KNListContactViewController()
    controller.loadViewIfNeeded()
    controller.delegate = self
    self.navigationController.pushViewController(controller, animated: true)
  }
}

// MARK: Search Token Delegate
extension KNSendTokenViewCoordinator: KNSearchTokenViewControllerDelegate {
  func searchTokenViewController(_ controller: KNSearchTokenViewController, run event: KNSearchTokenViewEvent) {
    controller.dismiss(animated: true) {
      self.searchTokensVC = nil
      if case .select(let token) = event {
        let balance = self.balances[token.contract]
        self.rootViewController.coordinatorDidUpdateSendToken(token, balance: balance)
      }
    }
  }
}

// MARK: Confirm Transaction Delegate
extension KNSendTokenViewCoordinator: KConfirmSendViewControllerDelegate {
  func kConfirmSendViewController(_ controller: KConfirmSendViewController, run event: KConfirmViewEvent) {
    if case .confirm(let type, let historyTransaction) = event, case .transfer(let transaction) = type {
      controller.dismiss(animated: true) {
        guard self.session.externalProvider != nil else {
          return
        }
        self.didConfirmTransfer(transaction, historyTransaction: historyTransaction)
        self.confirmVC = nil
        self.navigationController.displayLoading()
      }
    } else {
      controller.dismiss(animated: true) {
        self.confirmVC = nil
      }
    }
  }
}

// MARK: Network requests
extension KNSendTokenViewCoordinator {
  fileprivate func didConfirmTransfer(_ transaction: UnconfirmedTransaction, historyTransaction: InternalHistoryTransaction) {
    guard let provider = self.session.externalProvider else {
      return
    }
    self.rootViewController.coordinatorSendTokenUserDidConfirmTransaction()
    // send transaction request
    provider.transfer(transaction: transaction, completion: { [weak self] sendResult in
      guard let `self` = self else { return }
      self.navigationController.hideLoading()
      switch sendResult {
      case .success(let txHash):
        //TODO: replace realm object implement
        let tx: Transaction = transaction.toTransaction(
          wallet: self.session.wallet,
          hash: txHash,
          nounce: provider.minTxCount - 1
        )
        self.session.addNewPendingTransaction(tx)
        
        historyTransaction.hash = txHash
        historyTransaction.time = Date()
        historyTransaction.nonce = Int(tx.nonce) ?? 0
        
        EtherscanTransactionStorage.shared.appendInternalHistoryTransaction(historyTransaction)
        
        self.openTransactionStatusPopUp(transaction: tx)
      case .failure(let error):
        self.confirmVC?.resetActionButtons()
        KNNotificationUtil.postNotification(
          for: kTransactionDidUpdateNotificationKey,
          object: error,
          userInfo: nil
        )
      }
    })
  }

  fileprivate func openTransactionStatusPopUp(transaction: Transaction) {
    let trans = KNTransaction.from(transaction: transaction)
    self.transactionStatusVC = KNTransactionStatusPopUp(transaction: trans)
    self.transactionStatusVC?.delegate = self
    self.navigationController.present(self.transactionStatusVC!, animated: true, completion: nil)
  }
}

extension KNSendTokenViewCoordinator: KNNewContactViewControllerDelegate {
  func newContactViewController(_ controller: KNNewContactViewController, run event: KNNewContactViewEvent) {
    self.navigationController.popViewController(animated: true) {
      if case .send(let address) = event {
        self.rootViewController.coordinatorSend(to: address)
      }
    }
  }
}

extension KNSendTokenViewCoordinator: KNListContactViewControllerDelegate {
  func listContactViewController(_ controller: KNListContactViewController, run event: KNListContactViewEvent) {
    self.navigationController.popViewController(animated: true) {
      if case .select(let contact) = event {
        self.rootViewController.coordinatorDidSelectContact(contact)
      } else if case .send(let address) = event {
        self.rootViewController.coordinatorSend(to: address)
      }
    }
  }
}

extension KNSendTokenViewCoordinator: KNTransactionStatusPopUpDelegate {
  func transactionStatusPopUp(_ controller: KNTransactionStatusPopUp, action: KNTransactionStatusPopUpEvent) {
    self.transactionStatusVC = nil
    switch action {
    case .swap:
      KNNotificationUtil.postNotification(for: kOpenExchangeTokenViewKey)
    case .speedUp(let tx):
      self.openTransactionSpeedUpViewController(transaction: tx)
    case .cancel(let tx):
      self.openTransactionCancelConfirmPopUpFor(transaction: tx)
    case .openLink(let url):
      self.navigationController.openSafari(with: url)
    default:
      break
    }
  }

  fileprivate func openTransactionSpeedUpViewController(transaction: Transaction) {
    let viewModel = SpeedUpCustomGasSelectViewModel(transaction: transaction)
    let controller = SpeedUpCustomGasSelectViewController(viewModel: viewModel)
    controller.loadViewIfNeeded()
    controller.delegate = self
    navigationController.present(controller, animated: true)
  }

  fileprivate func openTransactionCancelConfirmPopUpFor(transaction: Transaction) {
    let viewModel = KNConfirmCancelTransactionViewModel(transaction: transaction)
    let confirmPopup = KNConfirmCancelTransactionPopUp(viewModel: viewModel)
    confirmPopup.delegate = self
    self.navigationController.present(confirmPopup, animated: true, completion: nil)
  }

  fileprivate func sendSpeedUpForTransferTransaction(transaction: UnconfirmedTransaction, original: Transaction) {
    guard let provider = self.session.externalProvider else {
      return
    }
    provider.speedUpTransferTransaction(transaction: transaction, completion: { [weak self] sendResult in
      guard let `self` = self else { return }
      switch sendResult {
      case .success(let txHash):
        let tx: Transaction = transaction.toTransaction(
          wallet: self.session.wallet,
          hash: txHash,
          nounce: Int(original.nonce)!,
          type: .speedup
        )
        self.session.updatePendingTransactionWithHash(hashTx: original.id, ultiTransaction: tx, state: .speedingUp, completion: {
          self.openTransactionStatusPopUp(transaction: tx)
        })
      case .failure:
        KNNotificationUtil.postNotification(
          for: kTransactionDidUpdateNotificationKey,
          object: nil,
          userInfo: [Constants.transactionIsCancel: TransactionType.speedup]
        )
      }
    })
  }
}

extension KNSendTokenViewCoordinator: GasFeeSelectorPopupViewControllerDelegate {
  func gasFeeSelectorPopupViewController(_ controller: GasFeeSelectorPopupViewController, run event: GasFeeSelectorPopupViewEvent) {
    switch event {
    case .gasPriceChanged(let type, let value):
      self.rootViewController.coordinatorDidUpdateGasPriceType(type, value: value)
    case .helpPressed:
      self.navigationController.showBottomBannerView(
        message: "Gas.fee.is.the.fee.you.pay.to.the.miner".toBeLocalised(),
        icon: UIImage(named: "help_icon_large") ?? UIImage(),
        time: 10
      )
    default:
      break
    }
  }
}

extension KNSendTokenViewCoordinator: WalletsListViewControllerDelegate {
  func walletsListViewController(_ controller: WalletsListViewController, run event: WalletsListViewEvent) {
    switch event {
    case .connectWallet:
      let qrcode = QRCodeReaderViewController()
      qrcode.delegate = self
      self.navigationController.present(qrcode, animated: true, completion: nil)
    case .manageWallet:
      self.delegate?.sendTokenCoordinatorDidSelectManageWallet()
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
      self.delegate?.sendTokenViewCoordinatorDidSelectWallet(wal)
    case .addWallet:
      self.delegate?.sendTokenCoordinatorDidSelectAddWallet()
    }
  }
}

extension KNSendTokenViewCoordinator: SpeedUpCustomGasSelectDelegate {
  func speedUpCustomGasSelectViewController(_ controller: SpeedUpCustomGasSelectViewController, run event: SpeedUpCustomGasSelectViewEvent) {
    switch event {
    case .done(let transaction, let newValue):
      let tokenObjects: [TokenObject] = self.session.tokenStorage.tokens
      if let speedUpTx = transaction.makeSpeedUpTransaction(availableTokens: tokenObjects, gasPrice: newValue) {
        self.sendSpeedUpForTransferTransaction(transaction: speedUpTx, original: transaction)
      }
    case .invaild:
      self.navigationController.showErrorTopBannerMessage(
        with: NSLocalizedString("error", value: "Error", comment: ""),
        message: "your.gas.must.be.10.percent.higher".toBeLocalised(),
        time: 1.5
      )
    }
  }

  fileprivate func sendSpeedUpSwapTransactionFor(transaction: Transaction, availableTokens: [TokenObject], newPrice: BigInt) {
    guard let provider = self.session.externalProvider else {
      return
    }
    guard let nouce = Int(transaction.nonce) else { return }
    guard let localizedOperation = transaction.localizedOperations.first else { return }
    guard let filteredToken = availableTokens.first(where: { (token) -> Bool in
      return token.symbol == localizedOperation.symbol
    }) else { return }
    let amount: BigInt = {
      return transaction.value.amountBigInt(decimals: localizedOperation.decimals) ?? BigInt(0)
    }()
    let gasLimit: BigInt = {
      return transaction.gasUsed.amountBigInt(units: .wei) ?? BigInt(0)
    }()
    provider.getTransactionByHash(transaction.id) { [weak self] (pendingTx, _) in
      guard let `self` = self else { return }
      if let fetchedTx = pendingTx, !fetchedTx.input.isEmpty {
        
        provider.speedUpSwapTransaction(
          for: filteredToken,
          amount: amount,
          nonce: nouce,
          data: fetchedTx.input,
          gasPrice: newPrice,
          gasLimit: gasLimit) { sendResult in
          switch sendResult {
          case .success(let txHash):
            let tx = transaction.convertToSpeedUpTransaction(newHash: txHash, newGasPrice: newPrice.displayRate(decimals: 0).removeGroupSeparator())
            self.session.updatePendingTransactionWithHash(hashTx: transaction.id, ultiTransaction: tx, state: .speedingUp, completion: {
              self.openTransactionStatusPopUp(transaction: tx)
            })
          case .failure:
            KNNotificationUtil.postNotification(
              for: kTransactionDidUpdateNotificationKey,
              object: nil,
              userInfo: [Constants.transactionIsCancel: TransactionType.speedup]
            )
          }
        }
      }
    }
  }
}

extension KNSendTokenViewCoordinator: KNConfirmCancelTransactionPopUpDelegate {
  func didConfirmCancelTransactionPopup(_ controller: KNConfirmCancelTransactionPopUp, transaction: Transaction) {
    self.didConfirmTransfer(transaction)
  }

  fileprivate func didConfirmTransfer(_ transaction: Transaction) {
    guard let provider = self.session.externalProvider else {
      return
    }
    guard let unconfirmTx = transaction.makeCancelTransaction() else {
      return
    }
    provider.speedUpTransferTransaction(transaction: unconfirmTx, completion: { [weak self] sendResult in
      guard let `self` = self else { return }
      switch sendResult {
      case .success(let txHash):
        let tx: Transaction = unconfirmTx.toTransaction(
          wallet: self.session.wallet,
          hash: txHash,
          nounce: provider.minTxCount - 1,
          type: .cancel
        )
        self.session.updatePendingTransactionWithHash(hashTx: transaction.id, ultiTransaction: tx, completion: {
          self.openTransactionStatusPopUp(transaction: tx)
        })
      case .failure:
        KNNotificationUtil.postNotification(
          for: kTransactionDidUpdateNotificationKey,
          object: nil,
          userInfo: [Constants.transactionIsCancel: TransactionType.cancel]
        )
      }
    })
  }
}

extension KNSendTokenViewCoordinator: QRCodeReaderDelegate {
  func readerDidCancel(_ reader: QRCodeReaderViewController!) {
    reader.dismiss(animated: true, completion: nil)
  }

  func reader(_ reader: QRCodeReaderViewController!, didScanResult result: String!) {
    reader.dismiss(animated: true) {
      guard let session = WCSession.from(string: result) else {
        self.navigationController.showTopBannerView(
          with: "Invalid session".toBeLocalised(),
          message: "Your session is invalid, please try with another QR code".toBeLocalised(),
          time: 1.5
        )
        return
      }
      let controller = KNWalletConnectViewController(
        wcSession: session,
        knSession: self.session
      )
      self.navigationController.present(controller, animated: true, completion: nil)
    }
  }
}
