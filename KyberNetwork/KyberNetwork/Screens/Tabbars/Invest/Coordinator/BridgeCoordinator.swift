//
//  BridgeCoordinator.swift
//  KyberNetwork
//
//  Created by Com1 on 18/05/2022.
//

import UIKit
import Moya
import MBProgressHUD
import QRCodeReaderViewController
import WalletConnectSwift
import BigInt
import TrustCore
import JSONRPCKit
import APIKit
import Result

class PoolInfo: Codable {
  var anyToken: String = ""
  var decimals: Int = 0
  var liquidity: String = ""
  var logoUrl: String = ""
  var name: String = ""
  var symbol: String = ""

  init(json: JSONDictionary) {
    self.anyToken = json["anyToken"] as? String ?? ""
    self.decimals = json["decimals"] as? Int ?? 0
    self.liquidity = json["liquidity"] as? String ?? ""
    self.logoUrl = json["logoUrl"] as? String ?? ""
    self.name = json["name"] as? String ?? ""
    self.symbol = json["symbol"] as? String ?? ""
  }
  
  func liquidityPoolString() -> String {
    let liquidity = Double(self.liquidity) ?? 0
    let displayLiquidity = liquidity / pow(10, self.decimals).doubleValue
    let displayLiquiditySring = StringFormatter.amountString(value: displayLiquidity)
    return " Pool: \(displayLiquiditySring) \(self.symbol)"
  }
}

class DestBridgeToken: Codable {
  var address: String = ""
  var name: String = ""
  var symbol: String = ""
  var decimals: Int = 0
  var maximumSwap: Double = 0.0
  var minimumSwap: Double = 0.0
  var bigValueThreshold: Double = 0.0
  var swapFeeRatePerMillion: Double = 0.0
  var maximumSwapFee: Double = 0.0
  var minimumSwapFee: Double = 0.0
  
  init(json: JSONDictionary) {
    if let underlyingJson = json["underlying"] as? JSONDictionary {
      self.address = underlyingJson["address"] as? String ?? ""
      self.name = underlyingJson["name"] as? String ?? ""
      self.symbol = underlyingJson["symbol"] as? String ?? ""
      self.decimals = underlyingJson["decimals"] as? Int ?? 0
    }
    if self.address.isEmpty {
      // incase underlying empty the current token will be anyToken
      if let anyTokenJson = json["anyToken"] as? JSONDictionary {
        self.address = anyTokenJson["address"] as? String ?? ""
        self.name = anyTokenJson["name"] as? String ?? ""
        self.symbol = anyTokenJson["symbol"] as? String ?? ""
        self.decimals = anyTokenJson["decimals"] as? Int ?? 0
      }
    }
    
    self.maximumSwap = Double(json["maximumSwap"] as? String ?? "0.0") ?? 0
    self.minimumSwap = Double(json["minimumSwap"] as? String ?? "0.0") ?? 0
    self.bigValueThreshold = Double(json["bigValueThreshold"] as? String ?? "0.0") ?? 0
    self.swapFeeRatePerMillion = json["swapFeeRatePerMillion"] as? Double ?? 0.0
    self.maximumSwapFee = Double(json["maximumSwapFee"] as? String ?? "0.0") ?? 0
    self.minimumSwapFee = Double(json["minimumSwapFee"] as? String ?? "0.0") ?? 0
  }
}

class SourceBridgeToken: Codable {
  var address: String = ""
  var name: String = ""
  var symbol: String = ""
  var decimals: Int = 0
  var destChains: [String: DestBridgeToken] = [:]
  
  init(json: JSONDictionary) {
    if let underlyingJson = json["underlying"] as? JSONDictionary {
      self.address = underlyingJson["address"] as? String ?? ""
      self.name = underlyingJson["name"] as? String ?? ""
      self.symbol = underlyingJson["symbol"] as? String ?? ""
      self.decimals = underlyingJson["decimals"] as? Int ?? 0
    }
    if self.address.isEmpty {
      // incase underlying empty the current token will be anyToken
      if let anyTokenJson = json["anyToken"] as? JSONDictionary {
        self.address = anyTokenJson["address"] as? String ?? ""
        self.name = anyTokenJson["name"] as? String ?? ""
        self.symbol = anyTokenJson["symbol"] as? String ?? ""
        self.decimals = anyTokenJson["decimals"] as? Int ?? 0
      }
    }
    
    if let destChainsJson = json["destChains"] as? JSONDictionary {
      for key in destChainsJson.keys {
        if let destBridgeTokenJson = destChainsJson[key] as? JSONDictionary {
          let destBridgeToken = DestBridgeToken(json: destBridgeTokenJson)
          self.destChains[key] = destBridgeToken
        }
      }
      print(self)
    }
  }
}

protocol BridgeCoordinatorDelegate: class {
  func didSelectAddChainWallet(chainType: ChainType)
  func didSelectWallet(_ wallet: Wallet)
  func didSelectAddWallet()
  func didSelectManageWallet()
  func didSelectOpenHistoryList()

}

class BridgeCoordinator: NSObject, Coordinator {
  fileprivate var session: KNSession
  weak var delegate: BridgeCoordinatorDelegate?
  let navigationController: UINavigationController
  var coordinators: [Coordinator] = []
  var data: [SourceBridgeToken] = []

  var advancedGasLimit: String?
  var advancedMaxPriorityFee: String?
  var advancedMaxFee: String?
  var advancedNonce: String?
  var approveGasLimit = KNGasConfiguration.exchangeTokensGasLimitDefault

  fileprivate(set) var currentSignTransaction: SignTransaction?
  fileprivate(set) var bridgeContract: String = ""
  fileprivate(set) var minRatePercent: Double = 0.5
  fileprivate(set) var estimateGasLimit: BigInt = KNGasConfiguration.exchangeTokensGasLimitDefault
  fileprivate(set) var selectedGasPriceType: KNSelectedGasPriceType = .medium
  fileprivate(set) var gasPrice: BigInt = KNGasCoordinator.shared.standardKNGas
  
  lazy var rootViewController: BridgeViewController = {
    let viewModel = BridgeViewModel(wallet: self.session.wallet)
    let controller = BridgeViewController(viewModel: viewModel)
    controller.delegate = self
    return controller
  }()
  
  var confirmVC: ConfirmBridgeViewController?
  
  init(navigationController: UINavigationController = UINavigationController(), session: KNSession) {
    self.navigationController = navigationController
    self.session = session
    self.navigationController.setNavigationBarHidden(true, animated: false)
  }

  func start() {
    self.navigationController.pushViewController(self.rootViewController, animated: true, completion: nil)
    self.fetchData()
  }
  
  func fetchData() {
    self.getServerInfo(chainId: KNGeneralProvider.shared.currentChain.getChainId()) {
      if let address = self.rootViewController.viewModel.currentSourceToken?.address {
        self.getPoolInfo(chainId: KNGeneralProvider.shared.currentChain.getChainId(), tokenAddress: address) { poolInfo in
          if let poolInfo = poolInfo {
            self.rootViewController.viewModel.currentSourcePoolInfo = poolInfo
            self.rootViewController.viewModel.showFromPoolInfo = true
          }
          self.rootViewController.coordinatorDidUpdateData()
        }
      } else {
        self.rootViewController.coordinatorDidUpdateData()
      }
    }
  }

  func appCoordinatorDidUpdateChain() {
    self.rootViewController.viewModel = BridgeViewModel(wallet: self.session.wallet)
    self.rootViewController.coordinatorDidUpdateChain()
    self.fetchData()
  }
  
  func appCoordinatorDidUpdateNewSession(_ session: KNSession) {
    self.session = session
    self.rootViewController.coordinatorUpdateNewSession(wallet: session.wallet)
  }
  
  func coordinatorDidUpdatePendingTx() {
    self.rootViewController.coordinatorDidUpdatePendingTx()
  }
  
  func getServerInfo(chainId: Int, completion: @escaping (() -> Void)) {
    let provider = MoyaProvider<KrytalService>(plugins: [NetworkLoggerPlugin(verbose: true)])
    self.rootViewController.showLoadingHUD()
    
    provider.request(.getServerInfo(chainId: chainId)) { result in
      DispatchQueue.main.async {
        self.rootViewController.hideLoading()
      }
      var tokens: [SourceBridgeToken] = []
      switch result {
      case .success(let result):
        if let json = try? result.mapJSON() as? JSONDictionary ?? [:], let data = json["data"] as? [JSONDictionary] {
          for dataJson in data {
            let sourceBridgeToken = SourceBridgeToken(json: dataJson)
            tokens.append(sourceBridgeToken)
          }
          if tokens.isNotEmpty {
            self.data = tokens
            
            var allTokens = KNSupportedTokenStorage.shared.getAllTokenObject()
              
            let supportedAddress = self.data.map { return $0.address.lowercased() }
            allTokens = allTokens.filter({
              supportedAddress.contains($0.address.lowercased())
            })
            self.rootViewController.viewModel.currentSourceToken = allTokens.first
          }
        }
      case .failure(let error):
        print("[Get Server Info] \(error.localizedDescription)")
      }
      completion()
    }
  }
  
  func getPoolInfo(chainId: Int, tokenAddress: String, completion: @escaping ((PoolInfo?) -> Void)) {
    let provider = MoyaProvider<KrytalService>(plugins: [NetworkLoggerPlugin(verbose: true)])
    self.rootViewController.showLoadingHUD()
    provider.request(.getPoolInfo(chainId: chainId, tokenAddress: tokenAddress)) { result in
      DispatchQueue.main.async {
        self.rootViewController.hideLoading()
      }
      switch result {
      case .success(let result):
        if let json = try? result.mapJSON() as? JSONDictionary ?? [:] {
          let poolInfo = PoolInfo(json: json)
          completion(poolInfo)
        } else {
          completion(nil)
        }
      case .failure( _):
        completion(nil)
      }
    }
  }
  
  func buildSwapChainTx(completion: @escaping ((TxObject?) -> Void)) {
    let provider = MoyaProvider<KrytalService>(plugins: [NetworkLoggerPlugin(verbose: true)])
    let fromAddress = self.session.wallet.addressString
    let toAddress = self.rootViewController.viewModel.currentSendToAddress
    let fromChainId = self.rootViewController.viewModel.currentSourceChain?.getChainId() ?? 0
    let toChainId = self.rootViewController.viewModel.currentDestChain?.getChainId() ?? 0
    let tokenAddress = self.rootViewController.viewModel.currentSourceToken?.address ?? ""
    
    let decimal = self.rootViewController.viewModel.currentSourceToken?.decimals ?? 0
    
    let amount = BigInt(self.rootViewController.viewModel.sourceAmount * pow(10.0, Double(decimal)))
    let amountString = String(amount)
    
    provider.request(.buildSwapChainTx(fromAddress: fromAddress, toAddress: toAddress, fromChainId: fromChainId, toChainId: toChainId, tokenAddress: tokenAddress, amount: amountString)) { result in
      if case .success(let resp) = result {
        let decoder = JSONDecoder()
        do {
          let data = try decoder.decode(TransactionResponse.self, from: resp.data)
          completion(data.txObject)
          
        } catch let error {
          self.navigationController.showTopBannerView(message: error.localizedDescription)
        }
      } else {
        self.navigationController.showTopBannerView(message: "Build Tx request is failed")
      }
    }
  }
  
  func getTransactionStatus(txHash: String, chainId: String) {
    let provider = MoyaProvider<KrytalService>(plugins: [NetworkLoggerPlugin(verbose: true)])
    self.rootViewController.showLoadingHUD()
    provider.request(.checkTxStatus(txHash: txHash, chainId: chainId)) { result in
      DispatchQueue.main.async {
        self.rootViewController.hideLoading()
      }
      
      //TODO: parse pending transaction here
    }
  }
  
  fileprivate func isAccountUseGasToken() -> Bool {
    var data: [String: Bool] = [:]
    if let saved = UserDefaults.standard.object(forKey: Constants.useGasTokenDataKey) as? [String: Bool] {
      data = saved
    } else {
      return false
    }
    return data[self.session.wallet.addressString] ?? false
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
  
  fileprivate func buildSignTx(_ object: TxObject) -> SignTransaction? {
    guard
      let value = BigInt(object.value.drop0x, radix: 16),
      var gasPrice = BigInt(object.gasPrice.drop0x, radix: 16),
      var gasLimit = BigInt(object.gasLimit.drop0x, radix: 16),
      
        // sai o day nay
      var nonce = Int(object.nonce.drop0x, radix: 16)
    else
    {
      return nil
    }
    
    if let unwrap = self.advancedMaxFee, let value = unwrap.shortBigInt(units: UnitConfiguration.gasPriceUnit) {
      gasPrice = value
    }

    if let unwrap = self.advancedGasLimit, let value = BigInt(unwrap) {
      gasLimit = value
    }

    if let unwrap = self.advancedNonce, let value = Int(unwrap) {
      nonce = value
    }
    
    if case let .real(account) = self.session.wallet.type {
      return SignTransaction(
        value: value,
        account: account,
        to: Address(string: object.to),
        nonce: nonce,
        data: Data(hex: object.data.drop0x),
        gasPrice: gasPrice,
        gasLimit: gasLimit,
        chainID: KNGeneralProvider.shared.customRPC.chainID
      )
    } else {
      //TODO: handle watch wallet type
      return nil
    }
  }
}

extension BridgeCoordinator: BridgeViewControllerDelegate {
  func bridgeViewControllerController(_ controller: BridgeViewController, run event: BridgeEvent) {
    switch event {
    case .changeAmount(amount: let amount):
      self.rootViewController.viewModel.sourceAmount = amount
      self.rootViewController.coordinatorDidUpdateData()
    case .didSelectDestChain(chain: let newChain):
      self.rootViewController.viewModel.currentDestChain = newChain
      self.rootViewController.viewModel.showReminder = true
      if let currentSourceToken = self.rootViewController.viewModel.currentSourceToken {
        if let currentBridgeToken = self.data.first(where: { $0.address.lowercased() == currentSourceToken.address.lowercased()
        }) {
          let currentDestChainToken = currentBridgeToken.destChains[newChain.getChainId().toString()]
          self.rootViewController.viewModel.currentDestToken = currentDestChainToken

          if let address = currentDestChainToken?.address {
            self.getPoolInfo(chainId: newChain.getChainId(), tokenAddress: address) { poolInfo in
              self.rootViewController.viewModel.currentDestPoolInfo = poolInfo
              self.rootViewController.viewModel.showToPoolInfo = true
              self.rootViewController.coordinatorDidUpdateData()
            }
          }
        }
      }
      self.getBuildTx()
      self.rootViewController.coordinatorDidUpdateData()
    case .openHistory:
        self.delegate?.didSelectOpenHistoryList()
    case .openWalletsList:
      let viewModel = WalletsListViewModel(
        walletObjects: KNWalletStorage.shared.availableWalletObjects,
        currentWallet: self.session.currentWalletObject
      )
      let walletsList = WalletsListViewController(viewModel: viewModel)
      walletsList.delegate = self
      self.navigationController.present(walletsList, animated: true, completion: nil)
    case .addChainWallet(let chainType):
      self.delegate?.didSelectAddChainWallet(chainType: chainType)
    case .willSelectDestChain:
      guard let sourceToken = self.rootViewController.viewModel.currentSourceToken else { return }
      let currentData = self.data.first {
        $0.address.lowercased() ==  sourceToken.address.lowercased()
      }
      guard let currentData = currentData else {
        return
      }
      let sourceChain = currentData.destChains.keys.map { key -> ChainType in
        let chainId = Int(key) ?? 0
        return ChainType.getAllChain().first { $0.getChainId() == chainId } ?? .eth
      }
      self.rootViewController.openSwitchChainPopup(sourceChain, false)
    case .selectSourceToken:
      var tokens = KNSupportedTokenStorage.shared.getAllTokenObject()
        
      let supportedAddress = self.data.map { return $0.address.lowercased() }
      tokens = tokens.filter({
        supportedAddress.contains($0.address.lowercased())
      })
        
      let viewModel = KNSearchTokenViewModel(
        supportedTokens: tokens
      )
      let controller = KNSearchTokenViewController(viewModel: viewModel)
      controller.loadViewIfNeeded()
      controller.delegate = self
      self.rootViewController.present(controller, animated: true, completion: nil)
    case .selectDestToken:
      let tokens = KNSupportedTokenStorage.shared.getAllTokenObject()
      let viewModel = KNSearchTokenViewModel(
        supportedTokens: tokens
      )
      let controller = KNSearchTokenViewController(viewModel: viewModel)
      controller.loadViewIfNeeded()
      controller.delegate = self
      self.rootViewController.present(controller, animated: true, completion: nil)
    case .changeShowDestAddress:
      self.rootViewController.viewModel.showSendAddress = !self.rootViewController.viewModel.showSendAddress
      self.rootViewController.coordinatorDidUpdateData()
    case .changeDestAddress(address: let address):
      self.rootViewController.viewModel.currentSendToAddress = address
      self.rootViewController.coordinatorDidUpdateData()
    case .checkAllowance(token: let from):
      self.getAllowance(token: from)
    case .selectSwap:
        let viewModel = self.rootViewController.viewModel
        if let currentSourceToken = viewModel.currentSourceToken {
          let fromValue = "\(viewModel.sourceAmount) \(currentSourceToken.symbol)"
          let toValue = "\(viewModel.calculateDesAmountString()) \(currentSourceToken.symbol)"
          let fee = self.gasPrice * self.estimateGasLimit
          let feeString: String = fee.displayRate(decimals: 18)

          let bridgeViewModel = ConfirmBridgeViewModel(fromChain: viewModel.currentSourceChain, fromValue: fromValue, fromAddress: self.session.wallet.addressString, toChain: viewModel.currentDestChain, toValue: toValue, toAddress: viewModel.currentSendToAddress, token: currentSourceToken, fee: feeString, signTransaction: self.currentSignTransaction, eip1559Transaction: nil)
          let vc = ConfirmBridgeViewController(viewModel: bridgeViewModel)
          vc.delegate = self
          self.confirmVC = vc
          self.navigationController.present(vc, animated: true, completion: nil)
        }
    case .sendApprove(token: let token, remain: let remain):
      self.estimateGasForApprove(tokenAddress: token.address) { estGas in
        let vm = ApproveTokenViewModelForTokenObject(token: token, res: remain)
        vm.gasLimit = estGas
        let vc = ApproveTokenViewController(viewModel: vm)
        vc.delegate = self
        self.navigationController.present(vc, animated: true, completion: nil)
      }
    case .selectMaxSource:
      guard let from = self.rootViewController.viewModel.currentSourceToken else { return }
      if from.isQuoteToken {
        let balance = from.getBalanceBigInt()
        let fee = self.gasPrice * self.estimateGasLimit
        if balance <= fee {
          self.rootViewController.viewModel.sourceAmount = 0
        }
        
        let availableToSwap = max(BigInt(0), balance - fee)
        let doubleValue = Double(availableToSwap.string(
          decimals: from.decimals,
          minFractionDigits: 0,
          maxFractionDigits: min(from.decimals, 5)
        ).removeGroupSeparator()) ?? 0
        self.rootViewController.viewModel.sourceAmount = doubleValue
      } else {
        let bal: BigInt = from.getBalanceBigInt()
        let string = bal.string(
          decimals: from.decimals,
          minFractionDigits: 0,
          maxFractionDigits: min(from.decimals, 5)
        )
        let doubleValue = Double(string.removeGroupSeparator()) ?? 0
        self.rootViewController.viewModel.sourceAmount = doubleValue
      }
      self.rootViewController.coordinatorDidUpdateData()
    }
  }
  
  func estimateGasForApprove(tokenAddress: String, completion: @escaping (BigInt) -> Void) {
      guard let bridgeAddress = Address(string: self.bridgeContract) else {
        completion(KNGasConfiguration.approveTokenGasLimitDefault)
        return
      }
      guard case .real(let account) = self.session.wallet.type else {
        completion(KNGasConfiguration.approveTokenGasLimitDefault)
        return
      }
      
      KNGeneralProvider.shared.getSendApproveERC20TokenEncodeData(networkAddress: bridgeAddress, value: Constants.maxValueBigInt) { encodeResult in
        switch encodeResult {
        case .success(let data):
          let setting = ConfirmAdvancedSetting(
            gasPrice: KNGasCoordinator.shared.defaultKNGas.description,
            gasLimit: KNGasConfiguration.approveTokenGasLimitDefault.description,
            advancedGasLimit: nil,
            advancedPriorityFee: nil,
            avancedMaxFee: nil,
            advancedNonce: nil
          )
          let currentAddress = account.address.description
          if KNGeneralProvider.shared.isUseEIP1559 {
            let tx = TransactionFactory.buildEIP1559Transaction(from: currentAddress, to: tokenAddress, nonce: 1, data: data, setting: setting)
            KNGeneralProvider.shared.getEstimateGasLimit(eip1559Tx: tx) { result in
              switch result {
              case .success(let estGas):
                completion(estGas)
              case .failure(_):
                completion(KNGasConfiguration.approveTokenGasLimitDefault)
              }
            }
          } else {
            let tx = TransactionFactory.buildLegacyTransaction(account: account, to: tokenAddress, nonce: 1, data: data, setting: setting)
            KNGeneralProvider.shared.getEstimateGasLimit(transaction: tx) { result in
              switch result {
              case .success(let estGas):
                completion(estGas)
              case .failure(_):
                completion(KNGasConfiguration.approveTokenGasLimitDefault)
              }
            }
          }
        case .failure( _):
          completion(KNGasConfiguration.approveTokenGasLimitDefault)
        }
      }
    }
  
  func getBuildTx(_ completion: (() -> Void)? = nil) {
    self.getLatestNonce { result in
      switch result {
      case .success(let nonce):
        self.buildSwapChainTx { txObject in
          if let txObject = txObject {
            let viewModel = self.rootViewController.viewModel
            let decimal = viewModel.currentSourceToken?.decimals ?? 0
            let newTxObject = TxObject(nonce: BigInt(nonce).hexEncoded, from: txObject.from, to: txObject.to, data: txObject.data, value: txObject.value, gasPrice: self.gasPrice.hexEncoded, gasLimit: txObject.gasLimit)
            self.bridgeContract = txObject.to
            guard let signTx = self.buildSignTx(newTxObject) else {
              if let completion = completion {
                completion()
              }
              return
            }
            self.currentSignTransaction = signTx
            self.estimateGasLimit = BigInt(txObject.gasLimit.drop0x, radix: 16) ?? KNGasConfiguration.exchangeTokensGasLimitDefault
            self.getAllowance(token: viewModel.currentSourceToken)
            if let completion = completion {
              completion()
            }
          }
        }
      case .failure(let error):
        self.navigationController.showErrorTopBannerMessage(message: error.description)
      }
    }
  }
  
  func getAllowance(token: TokenObject?) {
    guard let provider = self.session.externalProvider, let token = token else {
      return
    }
    guard !self.bridgeContract.isEmpty else {
      return
    }
    let networkAddress: Address = Address(string: self.bridgeContract)!
    let sourceTokenAddress: Address = Address(string: token.address ?? "")!
    provider.getAllowance(tokenAddress: sourceTokenAddress, toAddress: networkAddress) { [weak self] getAllowanceResult in
      guard let `self` = self else { return }
      switch getAllowanceResult {
      case .success(let res):
        self.rootViewController.coordinatorDidUpdateAllowance(token: token, allowance: res)
      case .failure:
        self.rootViewController.coordinatorDidFailUpdateAllowance(token: token)
      }
    }
  }
  
  fileprivate func saveUseGasTokenState(_ state: Bool) {
    var data: [String: Bool] = [:]
    if let saved = UserDefaults.standard.object(forKey: Constants.useGasTokenDataKey) as? [String: Bool] {
      data = saved
    }
    data[self.session.wallet.addressString] = state
    UserDefaults.standard.setValue(data, forKey: Constants.useGasTokenDataKey)
  }
  
  fileprivate func resetAllowanceForTokenIfNeeded(_ token: TokenObject, remain: BigInt, gasLimit: BigInt, completion: @escaping (Result<Bool, AnyError>) -> Void) {
    guard let provider = self.session.externalProvider else {
      return
    }
    if remain.isZero {
      completion(.success(true))
      return
    }
    let gasPrice = KNGasCoordinator.shared.defaultKNGas
    provider.sendApproveERCToken(
      for: token,
      value: BigInt(0),
      gasPrice: gasPrice,
      gasLimit: gasLimit
    ) { result in
      switch result {
      case .success:
        completion(.success(true))
      case .failure(let error):
        completion(.failure(error))
      }
    }
  }
}

extension BridgeCoordinator: ConfirmBridgeViewControllerDelegate {
  fileprivate func openTransactionStatusPopUp(transaction: InternalHistoryTransaction) {
    let controller = BridgeTransactionStatusPopup(transaction: transaction)
    self.navigationController.present(controller, animated: true, completion: nil)

  }
  
  func didConfirm(_ controller: ConfirmBridgeViewController, signTransaction: SignTransaction, internalHistoryTransaction: InternalHistoryTransaction) {
    self.navigationController.displayLoading()
    self.getBuildTx {
      guard let provider = self.session.externalProvider else {
        return
      }
      provider.signTransactionData(from: self.currentSignTransaction ?? signTransaction) { [weak self] result in
        guard let `self` = self else { return }
        switch result {
        case .success(let signedData):
          KNGeneralProvider.shared.sendSignedTransactionData(signedData.0, completion: { sendResult in
            self.navigationController.hideLoading()
            switch sendResult {
            case .success(let hash):
              provider.minTxCount += 1
              internalHistoryTransaction.hash = hash
              internalHistoryTransaction.nonce = signTransaction.nonce
              internalHistoryTransaction.time = Date()
              
              EtherscanTransactionStorage.shared.appendInternalHistoryTransaction(internalHistoryTransaction)
              controller.dismiss(animated: true) {
                self.openTransactionStatusPopUp(transaction: internalHistoryTransaction)
              }
              self.rootViewController.coordinatorSuccessSendTransaction()
            case .failure(let error):
              var errorMessage = error.description
              if case let APIKit.SessionTaskError.responseError(apiKitError) = error.error {
                if case let JSONRPCKit.JSONRPCError.responseError(_, message, _) = apiKitError {
                  errorMessage = message
                }
              }
              self.navigationController.showErrorTopBannerMessage(
                with: "Error",
                message: errorMessage
              )
            }
          })
        case .failure:
          self.rootViewController.coordinatorFailSendTransaction()
        }
      }
    }
  }
  
  func didConfirm(_ controller: ConfirmBridgeViewController, eip1559Tx: EIP1559Transaction, internalHistoryTransaction: InternalHistoryTransaction) {
    
  }

  func openGasPriceSelect() {
    let viewModel = GasFeeSelectorPopupViewModel(isSwapOption: true, gasLimit: self.estimateGasLimit, selectType: self.selectedGasPriceType, currentRatePercentage: self.minRatePercent, isUseGasToken: self.isAccountUseGasToken(), isContainSlippageSection: false)

    viewModel.baseGasLimit = self.estimateGasLimit
    viewModel.updateGasPrices(
      fast: KNGasCoordinator.shared.fastKNGas,
      medium: KNGasCoordinator.shared.standardKNGas,
      slow: KNGasCoordinator.shared.lowKNGas,
      superFast: KNGasCoordinator.shared.superFastKNGas
    )
    viewModel.advancedGasLimit = self.advancedGasLimit
    viewModel.advancedMaxPriorityFee = self.advancedMaxPriorityFee
    viewModel.advancedMaxFee = self.advancedMaxFee
    viewModel.advancedNonce = self.advancedNonce

    let vc = GasFeeSelectorPopupViewController(viewModel: viewModel)
    vc.delegate = self
    self.confirmVC?.present(vc, animated: true, completion: nil)
    self.getLatestNonce { result in
      switch result {
      case .success(let nonce):
        vc.coordinatorDidUpdateCurrentNonce(nonce)
      case .failure(let error):
        self.navigationController.showErrorTopBannerMessage(message: error.description)
      }
    }
  }
}

extension BridgeCoordinator: GasFeeSelectorPopupViewControllerDelegate {
  func gasFeeSelectorPopupViewController(_ controller: GasFeeSelectorPopupViewController, run event: GasFeeSelectorPopupViewEvent) {
    switch event {
    case .gasPriceChanged(let type, let value):
      self.advancedGasLimit = nil
      self.advancedMaxPriorityFee = nil
      self.advancedMaxFee = nil
      self.selectedGasPriceType = type
      self.gasPrice = value
      let feeString: String = (self.gasPrice * self.estimateGasLimit).displayRate(decimals: 18)
      self.confirmVC?.coordinatorDidUpdateFee(feeString: feeString)
    case .minRatePercentageChanged(let percent):
      self.minRatePercent = Double(percent)
    case .helpPressed(let tag):
      var message = "Gas.fee.is.the.fee.you.pay.to.the.miner".toBeLocalised()
      switch tag {
      case 1:
        message = KNGeneralProvider.shared.isUseEIP1559 ? "gas.limit.help".toBeLocalised() : "gas.limit.legacy.help".toBeLocalised()
      case 2:
        message = "max.priority.fee.help".toBeLocalised()
      case 3:
        message = KNGeneralProvider.shared.isUseEIP1559 ? "max.fee.help".toBeLocalised() : "gas.price.legacy.help".toBeLocalised()
      case 4:
        message = "nonce.help".toBeLocalised()
      default:
        break
      }
      self.navigationController.showBottomBannerView(
        message: message,
        icon: UIImage(named: "help_icon_large") ?? UIImage(),
        time: 10
      )
    case .useChiStatusChanged(let status):
      break
    case .updateAdvancedSetting(let gasLimit, let maxPriorityFee, let maxFee):
      self.advancedGasLimit = gasLimit
      self.advancedMaxPriorityFee = maxPriorityFee
      self.advancedMaxFee = maxFee
      self.selectedGasPriceType = .custom
    case .updateAdvancedNonce(let nonce):
      self.advancedNonce = nonce
    default:
      break
    }
  }
}

extension BridgeCoordinator: ApproveTokenViewControllerDelegate {
  func approveTokenViewControllerDidApproved(_ controller: ApproveTokenViewController, token: TokenObject, remain: BigInt, gasLimit: BigInt) {
    self.navigationController.displayLoading()
    guard let provider = self.session.externalProvider else {
      return
    }
    self.resetAllowanceForTokenIfNeeded(token, remain: remain, gasLimit: gasLimit) { [weak self] resetResult in
      guard let `self` = self else { return }
      self.navigationController.hideLoading()
      switch resetResult {
      case .success:
        let sourceTokenAddress: Address = Address(string: self.rootViewController.viewModel.currentSourceToken?.address ?? "")!
        
        provider.sendApproveERCTokenAddress(
          for: sourceTokenAddress,
          value: Constants.maxValueBigInt,
          gasPrice: KNGasCoordinator.shared.defaultKNGas,
          gasLimit: self.approveGasLimit,
          toAddress: self.bridgeContract) { result in
            switch result {
            case .success:
              self.rootViewController.coordinatorSuccessApprove(token: token)
            case .failure(let error):
              var errorMessage = error.description
              if case let APIKit.SessionTaskError.responseError(apiKitError) = error.error {
                if case let JSONRPCKit.JSONRPCError.responseError(_, message, _) = apiKitError {
                  errorMessage = message
                }
              }
              self.navigationController.showErrorTopBannerMessage(
                with: "Error",
                message: errorMessage,
                time: 1.5
              )
              self.rootViewController.coordinatorFailApprove(token: token)
            }
        }
      case .failure:
        self.rootViewController.coordinatorFailApprove(token: token)
      }
    }
  }
  
  func approveTokenViewControllerDidApproved(_ controller: ApproveTokenViewController, address: String, remain: BigInt, state: Bool, toAddress: String?, gasLimit: BigInt) {
    self.navigationController.displayLoading()
    guard let provider = self.session.externalProvider, let gasTokenAddress = Address(string: address) else {
      return
    }
    provider.sendApproveERCTokenAddress(
      for: gasTokenAddress,
      value: Constants.maxValueBigInt,
      gasPrice: KNGasCoordinator.shared.defaultKNGas,
      gasLimit: gasLimit
    ) { approveResult in
      self.navigationController.hideLoading()
      switch approveResult {
      case .success:
        self.saveUseGasTokenState(state)
      case .failure(let error):
        var errorMessage = error.description
        if case let APIKit.SessionTaskError.responseError(apiKitError) = error.error {
          if case let JSONRPCKit.JSONRPCError.responseError(_, message, _) = apiKitError {
            errorMessage = message
          }
        }
        self.navigationController.showErrorTopBannerMessage(
          with: "Error",
          message: errorMessage,
          time: 1.5
        )
      }
    }
  }
  
  func approveTokenViewControllerGetEstimateGas(_ controller: ApproveTokenViewController, tokenAddress: Address) {
    guard case .real(let account) = self.session.wallet.type else {
      return
    }
    KNGeneralProvider.shared.buildSignTxForApprove(tokenAddress: tokenAddress, account: account) { signTx in
      guard let unwrap = signTx else { return }
      KNGeneralProvider.shared.getEstimateGasLimit(transaction: unwrap) { result in
        switch result {
        case.success(let estGas):
          controller.coordinatorDidUpdateGasLimit(estGas)
        default:
          break
        }
      }
    }
  }
}

extension BridgeCoordinator: KNSearchTokenViewControllerDelegate {
  func searchTokenViewController(_ controller: KNSearchTokenViewController, run event: KNSearchTokenViewEvent) {
    controller.dismiss(animated: true, completion: nil)
    switch event {
    case .select(let token):
      self.rootViewController.viewModel.currentSourceToken = token
      self.rootViewController.viewModel.sourceAmount = 0.0
      self.rootViewController.viewModel.currentDestChain = nil
      self.rootViewController.viewModel.currentDestToken = nil
      self.rootViewController.viewModel.currentDestPoolInfo = nil
      self.rootViewController.viewModel.showToPoolInfo = false
      self.rootViewController.viewModel.showReminder = false
      if let currentSourceChain = self.rootViewController.viewModel.currentSourceChain {
        self.getPoolInfo(chainId: currentSourceChain.getChainId(), tokenAddress: token.address) { poolInfo in
          self.rootViewController.viewModel.currentSourcePoolInfo = poolInfo
          self.rootViewController.viewModel.showFromPoolInfo = true
          self.rootViewController.coordinatorDidUpdateData()
        }
      }
      self.rootViewController.coordinatorDidUpdateData()
    default:
      return
    }
  }
}

extension BridgeCoordinator: WalletsListViewControllerDelegate {
  func walletsListViewController(_ controller: WalletsListViewController, run event: WalletsListViewEvent) {
    switch event {
    case .connectWallet:
      let qrcode = QRCodeReaderViewController()
      qrcode.delegate = self
      self.navigationController.present(qrcode, animated: true, completion: nil)
    case .manageWallet:
      self.delegate?.didSelectManageWallet()
    case .copy(let wallet):
      UIPasteboard.general.string = wallet.address
      let hud = MBProgressHUD.showAdded(to: controller.view, animated: true)
      hud.mode = .text
      hud.label.text = NSLocalizedString("copied", value: "Copied", comment: "")
      hud.hide(animated: true, afterDelay: 1.5)
    case .select(let wallet):
      guard let wal = self.session.keystore.matchWithWalletObject(wallet, chainType: KNGeneralProvider.shared.currentChain == .solana ? .solana : .multiChain) else {
        return
      }
      self.delegate?.didSelectWallet(wal)
    case .addWallet:
      self.delegate?.didSelectAddWallet()
    }
  }
}

extension BridgeCoordinator: QRCodeReaderDelegate {
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