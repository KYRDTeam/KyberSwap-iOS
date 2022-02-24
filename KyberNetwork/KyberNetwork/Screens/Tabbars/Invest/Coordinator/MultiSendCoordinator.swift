//
//  MultiSendCoordinator.swift
//  KyberNetwork
//
//  Created by Ta Minh Quan on 09/02/2022.
//

import Foundation
import BigInt
import Result
import TrustCore
import WalletCore
import Moya
import APIKit
import JSONRPCKit

class MultiSendCoordinator: Coordinator {
  let navigationController: UINavigationController
  var coordinators: [Coordinator] = []
  var session: KNSession
  
  weak var delegate: KNSendTokenViewCoordinatorDelegate?
  
  lazy var rootViewController: MultiSendViewController = {
    let controller = MultiSendViewController()
    controller.delegate = self
    return controller
  }()
  
  lazy var addContactVC: KNNewContactViewController = {
    let viewModel: KNNewContactViewModel = KNNewContactViewModel(address: "")
    let controller = KNNewContactViewController(viewModel: viewModel)
    controller.loadViewIfNeeded()
    controller.delegate = self
    return controller
  }()
  
  fileprivate(set) var searchTokensVC: KNSearchTokenViewController?
  fileprivate(set) var approveVC: MultiSendApproveViewController?
  fileprivate(set) weak var gasPriceSelector: GasFeeSelectorPopupViewController?
  fileprivate(set) var confirmVC: MultiSendConfirmViewController?
  fileprivate(set) var processingTx: TxObject?
  
  init(navigationController: UINavigationController = UINavigationController(), session: KNSession) {
    self.navigationController = navigationController
    self.session = session
  }

  func start() {
    self.navigationController.pushViewController(self.rootViewController, animated: true, completion: nil)
  }
  
  func stop() {
    
  }
}

extension MultiSendCoordinator: MultiSendViewControllerDelegate {
  func multiSendViewController(_ controller: MultiSendViewController, run event: MultiSendViewControllerEvent) {
    switch event {
    case .searchToken(let selectedToken):
      self.openSearchToken(selectedToken: selectedToken.toObject())
    case .openContactsList:
      self.openListContactsView()
    case .addContact(address: let address):
      self.openNewContact(address: address, ens: nil)
    case .checkApproval(items: let items):
      self.requestBuildTx(items: items) { object in
        self.processingTx = object
        self.checkAllowance(contractAddress: object.to, items: items) { remaining in
          if remaining.isEmpty {
            self.rootViewController.coordinatorDidFinishApproveTokens()
          } else {
            self.openApproveView(items: remaining)
          }
        }
      }
    case .confirm(items: let items):
      self.getLatestNonce { result in
        switch result {
        case .success(let nonce):
          let nonceStr = BigInt(nonce).hexEncoded.hexSigned2Complement
          self.processingTx?.nonce = nonceStr
          if let tx = self.processingTx, let gasLimit = BigInt(tx.gasLimit.drop0x, radix: 16), !gasLimit.isZero {
            self.openConfirmView(items: items, txObject: tx)
          } else {
            self.requestBuildTx(items: items) { object in
              self.processingTx = object
              self.openConfirmView(items: items, txObject: object)
            }
          }
        case .failure(let error):
          self.navigationController.showErrorTopBannerMessage(message: error.description)
        }
      }
      if let tx = self.processingTx, let gasLimit = BigInt(tx.gasLimit.drop0x, radix: 16), !gasLimit.isZero {
        self.openConfirmView(items: items, txObject: tx)
      } else {
        self.requestBuildTx(items: items) { object in
          self.processingTx = object
          self.openConfirmView(items: items, txObject: object)
        }
      }
    }
  }
  
  fileprivate func requestBuildTx(items: [MultiSendItem], completion: @escaping (TxObject) -> Void) {
    let provider = MoyaProvider<KrytalService>(plugins: [NetworkLoggerPlugin(verbose: true)])
    let address = self.session.wallet.address.description
    
    provider.request(.buildMultiSendTx(sender: address, items: items)) { result in
      if case .success(let resp) = result {
        let decoder = JSONDecoder()
        do {
          let data = try decoder.decode(TransactionResponse.self, from: resp.data)
          completion(data.txObject)
          
        } catch let error {
          self.navigationController.showTopBannerView(message: error.localizedDescription)
        }
      }
    }
  }
  
  fileprivate func openSearchToken(selectedToken: TokenObject) {
    let tokens = KNSupportedTokenStorage.shared.getAllTokenObject()
    let viewModel = KNSearchTokenViewModel(
      supportedTokens: tokens
    )
    let controller = KNSearchTokenViewController(viewModel: viewModel)
    controller.loadViewIfNeeded()
    controller.delegate = self
    self.navigationController.present(controller, animated: true, completion: nil)
    self.searchTokensVC = controller
  }
  
  fileprivate func checkAllowance(contractAddress: String, items: [MultiSendItem], completion: @escaping ([MultiSendItem]) -> Void) {
    guard let provider = self.session.externalProvider else {
      self.navigationController.showErrorTopBannerMessage(message: "You are using watch wallet")
      return
    }
    
    var remaining: [MultiSendItem] = []
    let group = DispatchGroup()
    
    items.forEach { item in
      if let address = Address(string: item.2.address) {
        group.enter()
        
        provider.getAllowance(tokenAddress: address, toAddress: Address(string: contractAddress)) { result in
          switch result {
          case .success(let res):
            if item.1 > res {
              remaining.append(item)
            }
          case .failure:
            break
          }
          
          group.leave()
        }
      }
    }
    
    group.notify(queue: .main) {
      completion(remaining)
    }
  }
  
  fileprivate func openListContactsView() {
    let controller = KNListContactViewController()
    controller.loadViewIfNeeded()
    controller.delegate = self
    self.navigationController.pushViewController(controller, animated: true)
  }
  
  fileprivate func openNewContact(address: String, ens: String?) {
    let viewModel: KNNewContactViewModel = KNNewContactViewModel(address: address, ens: ens)
    self.addContactVC.updateView(viewModel: viewModel)
    self.navigationController.pushViewController(self.addContactVC, animated: true)
  }
  
  fileprivate func openApproveView(items: [MultiSendItem]) {
    guard self.approveVC == nil else { return }
    let viewModel = MultiSendApproveViewModel(items: items)
    let controller = MultiSendApproveViewController(viewModel: viewModel)
    controller.delegate = self
    self.navigationController.present(controller, animated: true, completion: nil)
    self.approveVC = controller
  }

  fileprivate func openConfirmView(items: [MultiSendItem], txObject: TxObject) {
    guard self.confirmVC == nil else { return }
    let gasLimit = BigInt(txObject.gasLimit.drop0x, radix: 16) ?? BigInt.zero
    let vm = MultiSendConfirmViewModel(sendItems: items, gasPrice: KNGasCoordinator.shared.fastKNGas, gasLimit: gasLimit, baseGasLimit: gasLimit)
    let controller = MultiSendConfirmViewController(viewModel: vm)
    controller.delegate = self
    self.navigationController.present(controller, animated: true, completion: nil)
    self.confirmVC = controller
  }
  
  fileprivate func openGasPriceSelectView(_ gasLimit: BigInt, _ selectType: KNSelectedGasPriceType, _ baseGasLimit: BigInt, _ advancedGasLimit: String?, _ advancedPriorityFee: String?, _ advancedMaxFee: String?, _ advancedNonce: String?, _ controller: UIViewController) {
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
    
    self.getLatestNonce { result in
      switch result {
      case .success(let nonce):
        vc.coordinatorDidUpdateCurrentNonce(nonce)
      case .failure(let error):
        self.navigationController.showErrorTopBannerMessage(message: error.description)
      }
    }
    
    controller.present(vc, animated: true, completion: nil)
    self.gasPriceSelector = vc
  }
  
  fileprivate func openAddressListView(items: [MultiSendItem], controller: UIViewController) {
    let vm = MultisendAddressListViewModel(items: items)
    let vc = MultisendAddressListViewController(viewModel: vm)
    controller.present(vc, animated: true, completion: nil)
  }
}

extension MultiSendCoordinator: KNSearchTokenViewControllerDelegate {
  func searchTokenViewController(_ controller: KNSearchTokenViewController, run event: KNSearchTokenViewEvent) {
    controller.dismiss(animated: true) {
      self.searchTokensVC = nil
      if case .select(let token) = event {
        self.rootViewController.coordinatorDidUpdateSendToken(token.toToken())
      } else if case .add(let token) = event {
        self.delegate?.sendTokenCoordinatorDidSelectAddToken(token)
      }
    }
  }
}

extension MultiSendCoordinator: KNListContactViewControllerDelegate {
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

extension MultiSendCoordinator: KNNewContactViewControllerDelegate {
  func newContactViewController(_ controller: KNNewContactViewController, run event: KNNewContactViewEvent) {
    self.navigationController.popViewController(animated: true) {
      if case .send(let address) = event {
        self.rootViewController.coordinatorSend(to: address)
      }
    }
  }
}

extension MultiSendCoordinator: MultiSendApproveViewControllerDelegate {

  func multiSendApproveVieController(_ controller: MultiSendApproveViewController, run event: MultiSendApproveViewEvent) {
    switch event {
    case .openGasPriceSelect(let gasLimit, let baseGasLimit, let selectType, let advancedGasLimit, let advancedPriorityFee, let advancedMaxFee, let advancedNonce):
      openGasPriceSelectView(gasLimit, selectType, baseGasLimit, advancedGasLimit, advancedPriorityFee, advancedMaxFee, advancedNonce, controller)
    case .dismiss:
      self.approveVC = nil
    
    case .approve(items: let items, isApproveUnlimit: let isApproveUnlimit, settings: let setting):
      guard case .real(let account) = self.session.wallet.type, let provider = self.session.externalProvider else {
        return
      }
      
      let currentAddress = account.address.description

      self.getLatestNonce { nonceResult in
        switch nonceResult {
        case .success(let nonce):
          self.buildApproveDataList(items: items, isApproveUnlimit: isApproveUnlimit) { dataList in
            var eipTxs: [(MultiSendItem, EIP1559Transaction)] = []
            var legacyTxs: [(MultiSendItem, SignTransaction)] = []
            for (index, element) in dataList.enumerated() {
              let item = element.0
              let txNonce = nonce + index
              if KNGeneralProvider.shared.isUseEIP1559 {
                let tx = TransactionFactory.buildEIP1559Transaction(from: currentAddress, to: item.2.address, nonce: txNonce, data: element.1, setting: setting)
                eipTxs.append((item, tx))
              } else {
                let tx = TransactionFactory.buildLegacyTransaction(account: account, to: item.2.address, nonce: txNonce, data: element.1, setting: setting)
                legacyTxs.append((item, tx))
              }
            }
            print(eipTxs)
            print(legacyTxs)
            
            if !eipTxs.isEmpty {
              self.sendEIP1559Txs(eipTxs) { remaining in
                guard remaining.isEmpty else {
                  
                  return
                }
                DispatchQueue.main.async {
                  controller.dismiss(animated: true) {
                    self.rootViewController.coordinatorDidFinishApproveTokens()
                  }
                }
              }
            } else if !legacyTxs.isEmpty {
              self.sendLegacyTxs(legacyTxs) { remaining in
                DispatchQueue.main.async {
                  controller.dismiss(animated: true) {
                    self.rootViewController.coordinatorDidFinishApproveTokens()
                  }
                }
              }
            }
          }
        case .failure( _):
          break
        }
      }
    }
  }

  fileprivate func getLatestNonce(completion: @escaping (Result<Int, AnyError>) -> Void) {
    guard let provider = self.session.externalProvider else {
      return
    }
    provider.getTransactionCount { result in
      switch result {
      case .success(let res):
        completion(.success(res))
      case .failure(let error):
        completion(.failure(error))
      }
    }
  }
  
  fileprivate func buildApproveDataList(items: [MultiSendItem], isApproveUnlimit: Bool, completion: @escaping ([(MultiSendItem, Data)]) -> Void) {
    guard let addressStr = self.processingTx?.to, let address = Address(string: addressStr) else { return }
    var dataList: [(MultiSendItem, Data)] = []
    let group = DispatchGroup()
    items.forEach { item in
      let value = isApproveUnlimit ? BigInt(2).power(256) - BigInt(1) : item.1
      group.enter()

      KNGeneralProvider.shared.getSendApproveERC20TokenEncodeData(networkAddress: address, value: value) { encodeResult in
        switch encodeResult {
        case .success(let data):
          dataList.append((item, data))
        case .failure( _):
          break
        }
        group.leave()
      }

      group.notify(queue: .global()) {
        completion(dataList)
      }
    }
  }

  fileprivate func sendEIP1559Txs(_ txs: [(MultiSendItem, EIP1559Transaction)], completion: @escaping ([MultiSendItem]) -> Void) {
    guard let provider = self.session.externalProvider else {
      self.navigationController.showErrorTopBannerMessage(message: "Watch wallet doesn't support this operation")
      return
    }
    var signedData: [(MultiSendItem, EIP1559Transaction, Data)] = []
    txs.forEach { element in
      if let data = provider.signContractGenericEIP1559Transaction(element.1) {
        signedData.append((element.0, element.1, data))
      }
    }
    
    let group = DispatchGroup()
    var unApproveItem: [MultiSendItem] = []
    signedData.forEach { txData in
      group.enter()
      let item = txData.0
      KNGeneralProvider.shared.sendRawTransactionWithInfura(txData.2, completion: { sendResult in
        switch sendResult {
        case .success(let hash):
          let historyTx = InternalHistoryTransaction(type: .allowance, state: .pending, fromSymbol: nil, toSymbol: nil, transactionDescription: "Approve \(item.2.name)", transactionDetailDescription: "", transactionObj: nil, eip1559Tx: txData.1)
          historyTx.hash = hash
          historyTx.time = Date()
          historyTx.nonce = Int(txData.1.nonce) ?? 0
          EtherscanTransactionStorage.shared.appendInternalHistoryTransaction(historyTx)
          self.approveVC?.coordinatorDidUpdateApprove(txData.0)
        case .failure( _):
          unApproveItem.append(txData.0)
        }

        group.leave()
      })
    }
    
    group.notify(queue: .main) {
      completion(unApproveItem)
    }
  }
  
  fileprivate func sendLegacyTxs(_ txs: [(MultiSendItem, SignTransaction)], completion: @escaping ([MultiSendItem]) -> Void) {
    guard let provider = self.session.externalProvider else {
      self.navigationController.showErrorTopBannerMessage(message: "Watch wallet doesn't support this operation")
      return
    }
    let group = DispatchGroup()
    var signedData: [(MultiSendItem, SignTransaction, Data)] = []
    txs.forEach { element in
      group.enter()
      provider.signTransactionData(from: element.1) { signResult in
        if case .success(let resultData) = signResult {
          signedData.append((element.0, element.1, resultData.0))
        }

        group.leave()
      }
      group.wait()
    }
    group.notify(queue: .global()) {
      let sendGroup = DispatchGroup()
      var unApproveItem: [MultiSendItem] = []
      signedData.forEach { txData in
        sendGroup.enter()
        let item = txData.0
        print("[Debug] \(txData.2.hexEncoded)")
        KNGeneralProvider.shared.sendRawTransactionWithInfura(txData.2, completion: { sendResult in
          switch sendResult {
          case .success(let hash):
            let historyTx = InternalHistoryTransaction(type: .allowance, state: .pending, fromSymbol: nil, toSymbol: nil, transactionDescription: "Approve \(item.2.name)", transactionDetailDescription: "", transactionObj: txData.1.toSignTransactionObject(), eip1559Tx:nil )
            historyTx.hash = hash
            historyTx.time = Date()
            historyTx.nonce = txData.1.nonce
            EtherscanTransactionStorage.shared.appendInternalHistoryTransaction(historyTx)
            self.approveVC?.coordinatorDidUpdateApprove(txData.0)
          case .failure( _):
            unApproveItem.append(txData.0)
          }
          
          sendGroup.leave()
        })
        sendGroup.wait()
      }

      sendGroup.notify(queue: .main) {
        completion(unApproveItem)
      }
    }
  }
  
}

extension MultiSendCoordinator: GasFeeSelectorPopupViewControllerDelegate {
  func gasFeeSelectorPopupViewController(_ controller: GasFeeSelectorPopupViewController, run event: GasFeeSelectorPopupViewEvent) {
    switch event {
    case .infoPressed:
      break
    case .gasPriceChanged(let type, let value):
      self.approveVC?.coordinatorDidUpdateGasPriceType(type, value: value)
      self.confirmVC?.coordinatorDidUpdateGasPriceType(type, value: value)
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
    case .updateAdvancedSetting(let gasLimit, let maxPriorityFee, let maxFee):
      self.approveVC?.coordinatorDidUpdateAdvancedSettings(gasLimit: gasLimit, maxPriorityFee: maxPriorityFee, maxFee: maxFee)
      self.confirmVC?.coordinatorDidUpdateAdvancedSettings(gasLimit: gasLimit, maxPriorityFee: maxPriorityFee, maxFee: maxFee)
    case .updateAdvancedNonce(let nonce):
      self.approveVC?.coordinatorDidUpdateAdvancedNonce(nonce)
      self.confirmVC?.coordinatorDidUpdateAdvancedNonce(nonce)
    default:
      break
    }
  }
}

extension MultiSendCoordinator: MultiSendConfirmViewControllerDelegate {
  func multiSendConfirmVieController(_ controller: MultiSendConfirmViewController, run event: MultiSendConfirmViewEvent) {
    switch event {
    case .openGasPriceSelect(let gasLimit, let baseGasLimit, let selectType, let advancedGasLimit, let advancedPriorityFee, let advancedMaxFee, let advancedNonce):
      openGasPriceSelectView(gasLimit, selectType, baseGasLimit, advancedGasLimit, advancedPriorityFee, advancedMaxFee, advancedNonce, controller)
    case .dismiss:
      self.confirmVC = nil
      self.processingTx = nil
    case .confirm(setting: let setting):
      guard case .real(let account) = self.session.wallet.type, let provider = self.session.externalProvider else {
        return
      }
      guard let tx = self.processingTx else { return }
      if KNGeneralProvider.shared.isUseEIP1559 {
        let tx = TransactionFactory.buildEIP1559Transaction(txObject: tx, setting: setting)
        guard let data = provider.signContractGenericEIP1559Transaction(tx) else {
          return
        }
        KNGeneralProvider.shared.sendRawTransactionWithInfura(data, completion: { sendResult in
          switch sendResult {
          case .success(let hash):
            let historyTransaction = InternalHistoryTransaction(type: .transferToken, state: .pending, fromSymbol: "", toSymbol: "", transactionDescription: "MultiSend", transactionDetailDescription: "", transactionObj: nil, eip1559Tx: tx)
            historyTransaction.hash = hash
            historyTransaction.time = Date()
            historyTransaction.nonce = Int(tx.nonce.drop0x, radix: 16) ?? 0
            EtherscanTransactionStorage.shared.appendInternalHistoryTransaction(historyTransaction)
          case .failure(let error):
            self.navigationController.showTopBannerView(message: error.localizedDescription)
          }
        })
      } else {
        let tx = TransactionFactory.buildLegaryTransaction(txObject: tx, account: account, setting: setting)
        KNGeneralProvider.shared.getEstimateGasLimit(transaction: tx) {
         result in
          switch result {
          case .success(_):
            provider.signTransactionData(from: tx) { result in
              switch result {
              case .success(let signedData):
                print(signedData.0.hexEncoded)
                KNGeneralProvider.shared.sendRawTransactionWithInfura(signedData.0) { sendResult in
                  switch sendResult {
                  case .success(let hash):
                    let historyTransaction = InternalHistoryTransaction(type: .transferToken, state: .pending, fromSymbol: "", toSymbol: "", transactionDescription: "MultiSend", transactionDetailDescription: "", transactionObj: tx.toSignTransactionObject(), eip1559Tx: nil)
                    historyTransaction.hash = hash
                    historyTransaction.time = Date()
                    historyTransaction.nonce = tx.nonce
                    EtherscanTransactionStorage.shared.appendInternalHistoryTransaction(historyTransaction)
                  case .failure(let error):
                    self.navigationController.showTopBannerView(message: error.localizedDescription)
                  }
                }
              case .failure(let error):
                var errorMessage = "Can not sign transaction data"
                if case let APIKit.SessionTaskError.responseError(apiKitError) = error.error {
                  if case let JSONRPCKit.JSONRPCError.responseError(_, message, _) = apiKitError {
                    errorMessage = message
                  }
                }
                self.navigationController.showErrorTopBannerMessage(message: errorMessage)
              }

            }
          case .failure(let error):
            var errorMessage = "Can not estimate Gas Limit"
            if case let APIKit.SessionTaskError.responseError(apiKitError) = error.error {
              if case let JSONRPCKit.JSONRPCError.responseError(_, message, _) = apiKitError {
                errorMessage = "Cannot estimate gas, please try again later. Error: \(message)"
              }
            }
            self.navigationController.showErrorTopBannerMessage(message: errorMessage)
          }
        }
        
        
      }
      
      self.confirmVC = nil
      self.processingTx = nil
    case .showAddresses(let items):
      self.openAddressListView(items: items, controller: controller)
    }
  }
}
