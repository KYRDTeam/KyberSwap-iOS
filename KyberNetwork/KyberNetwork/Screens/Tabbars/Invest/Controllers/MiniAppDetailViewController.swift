//
//  MiniAppDetailViewController.swift
//  KyberNetwork
//
//  Created by Com1 on 24/05/2022.
//

import UIKit
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
import WebKit
import Moya

protocol MiniAppDetailDelegate: class {
  func dAppCoordinatorDidSelectAddWallet()
  func dAppCoordinatorDidSelectWallet(_ wallet: Wallet)
  func dAppCoordinatorDidSelectManageWallet()
  func dAppCoordinatorDidSelectAddChainWallet(chainType: ChainType)
}

class MiniAppDetailViewController: KNBaseViewController {
  @IBOutlet weak var fiveStarButton: UIButton!
  @IBOutlet weak var fourStarButton: UIButton!
  @IBOutlet weak var threeStarButton: UIButton!
  @IBOutlet weak var twoStarButton: UIButton!
  @IBOutlet weak var oneStarButton: UIButton!
  @IBOutlet weak var titleLabel: UILabel!
  @IBOutlet weak var reviewsLabel: UILabel!
  @IBOutlet weak var nameLabel: UILabel!
  @IBOutlet weak var icon: UIImageView!
  @IBOutlet weak var detailLabel: UILabel!
  @IBOutlet weak var chainLabel: UILabel!
  @IBOutlet weak var favoriteButton: UIButton!
  @IBOutlet weak var tableView: UITableView!
  private var browserViewController: BrowserViewController?
  private var transactionConfirm: DappBrowerTransactionConfirmPopup?
  fileprivate weak var transactionStatusVC: KNTransactionStatusPopUp?
  weak var delegate: MiniAppDetailDelegate?
  var dataSource: [MiniAppReview] = []
  var session: KNSession
  var currentMiniApp: MiniApp
  var isFavorite: Bool = false
  var favoriteData: [String: Bool]? = UserDefaults.standard.value(forKey: "MiniAppData") as? [String: Bool]

  init(miniApp: MiniApp, session: KNSession) {
    self.currentMiniApp = miniApp
    self.session = session
    super.init(nibName: MiniAppDetailViewController.className, bundle: nil)
    self.modalPresentationStyle = .custom
  }
  
  private lazy var urlParser: BrowserURLParser = {
      return BrowserURLParser()
  }()
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    self.titleLabel.text = self.currentMiniApp.category
    self.nameLabel.text = self.currentMiniApp.name
    if let url = URL(string: self.currentMiniApp.icon) {
      self.icon.setImage(with: url, placeholder: nil)
    }
    self.reviewsLabel.text = "\(self.currentMiniApp.numberOfReviews) Ratings"
    self.chainLabel.text = "Available on: \(self.currentMiniApp.chains)"
    self.detailLabel.text = self.currentMiniApp.description
    
    let rate = self.currentMiniApp.rating
    self.updateRateUI(rate: rate)
    self.favoriteButton.setImage(self.isFavorite ? UIImage(named: "heart_icon_red") : UIImage(named: "heart_icon"), for: .normal)
    
    if let favoriteData = self.favoriteData, let favorite = favoriteData[self.currentMiniApp.url], favorite == true {
      self.favoriteButton.setImage(UIImage(named: "heart_icon_red"), for: .normal)
    } else {
      self.favoriteButton.setImage(UIImage(named: "heart_icon"), for: .normal)
    }
    
    self.tableView.registerCellNib(MiniAppReviewCell.self)
    self.getDetailData()
  }
  
  fileprivate func openTransactionStatusPopUp(transaction: InternalHistoryTransaction) {
    let controller = KNTransactionStatusPopUp(transaction: transaction)
    controller.delegate = self
    self.navigationController?.present(controller, animated: true, completion: nil)
    self.transactionStatusVC = controller
  }
  
  func updateRateUI(rate: Double) {
    self.oneStarButton.configStarRate(isHighlight: rate >= 0.5)
    self.twoStarButton.configStarRate(isHighlight: rate >= 1.5)
    self.threeStarButton.configStarRate(isHighlight: rate >= 2.5)
    self.fourStarButton.configStarRate(isHighlight: rate >= 3.5)
    self.fiveStarButton.configStarRate(isHighlight: rate >= 4.5)
  }

  @IBAction func favoriteButtonTapped(_ sender: Any) {
    self.isFavorite = !self.isFavorite
    if var favoriteData = self.favoriteData {
      favoriteData[self.currentMiniApp.url] = self.isFavorite
      UserDefaults.standard.set(favoriteData, forKey: "MiniAppData")
    } else {
      let newFavoriteData = [self.currentMiniApp.url : self.isFavorite]
      UserDefaults.standard.set(newFavoriteData, forKey: "MiniAppData")
    }
    self.favoriteButton.setImage(self.isFavorite ? UIImage(named: "heart_icon_red") : UIImage(named: "heart_icon"), for: .normal)
    if self.isFavorite {
      let provider = MoyaProvider<KrytalService>(plugins: [NetworkLoggerPlugin(verbose: true)])
      self.showLoadingHUD()
      provider.request(.addFavorite(address: self.session.wallet.addressString, url: self.currentMiniApp.url)) { (result) in
        DispatchQueue.main.async {
          self.hideLoading()
        }
        if case .success(let resp) = result {
          print("Success")
        } else {
          print("Error")
        }
      }
    }
  }
  
  @IBAction func backButtonTapped(_ sender: Any) {
    self.navigationController?.popViewController(animated: true)
  }

  @IBAction func onOpenDappTapped(_ sender: Any) {
    guard case .real(let account) = self.session.wallet.type else { return }
    guard let url = urlParser.url(from: self.currentMiniApp.url) else { return }
    let vm = BrowserViewModel(url: url, account: account)
    let vc = BrowserViewController(viewModel: vm)
    vc.delegate = self
    vc.webView.uiDelegate = self
    self.browserViewController = vc
    self.navigationController?.pushViewController(vc, animated: true)
  }
  
  @IBAction func rateButtonTapped(_ sender: UIButton) {
    self.updateRateUI(rate: Double(sender.tag))
    let vc = RateTransactionPopupViewController(currentRate: sender.tag, txHash: "")
    vc.delegate = self
    self.present(vc, animated: true, completion: nil)
  }
  
  func getDetailData() {
    let provider = MoyaProvider<KrytalService>(plugins: [NetworkLoggerPlugin(verbose: true)])
    self.showLoadingHUD()
    provider.request(.getDetail(url: self.currentMiniApp.url)) { (result) in
      DispatchQueue.main.async {
        self.hideLoading()
      }
      switch result {
      case .success(let data):
        var reviews: [MiniAppReview] = []
        if let json = try? data.mapJSON() as? JSONDictionary ?? [:] {
          if let reviewsJsons = json["reviews"] as? [JSONDictionary] {
            for reviewsJson in reviewsJsons {
              if let userId = reviewsJson["userId"] as? String,
                let dappUrl = reviewsJson["dappUrl"] as? String,
                let score = reviewsJson["score"] as? Double,
                let comment = reviewsJson["comment"] as? String {
                let review = MiniAppReview(userId: userId, dappUrl: dappUrl, score: score, comment: comment)
              reviews.append(review)
              }
            }
          }
          self.dataSource = reviews
          self.tableView.reloadData()
        }
      case .failure(let error):
        print("[Get miniapp detail] \(error.localizedDescription)")
      }
    }
  }
}

extension MiniAppDetailViewController: UITableViewDataSource {
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = self.tableView.dequeueReusableCell(MiniAppReviewCell.self, indexPath: indexPath)!
    let review = self.dataSource[indexPath.row]
    cell.updateRateUI(rate: review.score)
    cell.reviewLabel.text = review.comment
    return cell
  }

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return self.dataSource.count
  }
}

extension MiniAppDetailViewController: WKUIDelegate {
  func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
    if navigationAction.targetFrame == nil {
      self.browserViewController?.webView.load(navigationAction.request)
    }
    return nil
  }
}

extension MiniAppDetailViewController: BrowserViewControllerDelegate {
  func browserViewController(_ controller: BrowserViewController, run event: BrowserViewEvent) {
    switch event {
    case .openOption(let url):
      let controller = BrowserOptionsViewController(
        url: url,
        canGoBack: controller.webView.canGoBack,
        canGoForward: controller.webView.canGoForward
      )
      controller.delegate = self
      self.present(controller, animated: true, completion: nil)
    case .switchChain:
      break
    case .addChainWallet(let chainType):
      self.showTopBannerView(message: "Not supported")
    }
  }
  
  func didCall(action: DappAction, callbackID: Int, inBrowserViewController viewController: BrowserViewController) {
    let url = viewController.viewModel.url.absoluteString
    func rejectDappAction() {
      viewController.coordinatorNotifyFinish(callbackID: callbackID, value: .failure(DAppError.cancelled))
      self.navigationController?.topViewController?.displayError(error: InCoordinatorError.onlyWatchAccount)
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
          address: self.session.wallet.addressString,
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
          self.navigationController?.present(vc, animated: true, completion: nil)
      case .signPersonalMessage(let hexMessage):
        let vm = SignMessageConfirmViewModel(
          url: url,
          address: self.session.wallet.addressString,
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
          self.navigationController?.present(vc, animated: true, completion: nil)
      case .signTypedMessage(let typedData):
        let vm = SignMessageConfirmViewModel(
          url: url,
          address: self.session.wallet.addressString,
          message: typedData.first?.value.string ?? "0x",
          onConfirm: {
            self.signMessage(with: .typedMessage(typedData), callbackID: callbackID)
          },
          onCancel: {
            let error = DAppError.cancelled
            self.browserViewController?.coordinatorNotifyFinish(callbackID: callbackID, value: .failure(error))
          }
        )
        let vc = SignMessageConfirmPopup(viewModel: vm)
          self.navigationController?.present(vc, animated: true, completion: nil)
      case .signTypedMessageV3(let typedData):
        let vm = SignMessageConfirmViewModel(
          url: url,
          address: self.session.wallet.addressString,
          message: typedData.message["functionSignature"]?.stringValue ?? "0x",
          onConfirm: {
            self.signMessage(with: .eip712v3And4(typedData), callbackID: callbackID)
          },
          onCancel: {
            let error = DAppError.cancelled
            self.browserViewController?.coordinatorNotifyFinish(callbackID: callbackID, value: .failure(error))
          }
        )
        let vc = SignMessageConfirmPopup(viewModel: vm)
          self.navigationController?.present(vc, animated: true, completion: nil)
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
      case .walletAddEthereumChain(let customChain):
        guard let targetChainId = Int(chainId0xString: customChain.chainId), let chainType = ChainType.make(chainID: targetChainId) else {
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
              KNNotificationUtil.postNotification(for: kChangeChainNotificationKey, object: self.session.wallet.addressString)
            },
            firstButtonAction: {
              let error = DAppError.cancelled
              self.browserViewController?.coordinatorNotifyFinish(callbackID: callbackID, value: .failure(error))
            }
          )
          alertController.popupHeight = 220
          self.navigationController?.present(alertController, animated: true, completion: nil)
        }
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
              KNNotificationUtil.postNotification(for: kChangeChainNotificationKey, object: self.session.wallet.addressString)
            },
            firstButtonAction: {
              let error = DAppError.cancelled
              self.browserViewController?.coordinatorNotifyFinish(callbackID: callbackID, value: .failure(error))
            }
          )
          alertController.popupHeight = 220
          self.navigationController?.present(alertController, animated: true, completion: nil)
        }
      default:
          self.navigationController?.showTopBannerView(message: "This dApp action is not supported yet")
      }
    }
  }
  
  private func executeTransaction(action: DappAction, callbackID: Int, tx: SignTransactionObject, url: String) {
    self.askToAsyncSign(action: action, callbackID: callbackID, tx: tx, message: "Prepare to send your transaction", url: url) {
    }
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
  
  func askToAsyncSign(action: DappAction, callbackID: Int, tx: SignTransactionObject, message: String, url: String, sign: @escaping () -> Void) {
    guard case .real(let account) = self.session.wallet.type, let provider = self.session.externalProvider else {
      return
    }
    let onSign = { (setting: ConfirmAdvancedSetting) in
      print("[Debug] \(setting)")
      self.navigationController?.displayLoading()
      self.getLatestNonce { nonce in
        var sendTx = tx
        sendTx.updateNonce(nonce: nonce)
        print("[Dapp] raw tx \(tx)")
        if KNGeneralProvider.shared.isUseEIP1559 {
          let eipTx = sendTx.toEIP1559Transaction(setting: setting)
          KNGeneralProvider.shared.getEstimateGasLimit(eip1559Tx: eipTx) { (estResult) in
            switch estResult {
            case .success:
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
                      transactionDescription: "Application",
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
                      self.navigationController?.displayError(error: error)
                  }
                  self.navigationController?.hideLoading()
                })
              }
            case .failure(let error):
                self.navigationController?.hideLoading()
              var errorMessage = "Can not estimate Gas Limit"
              if case let APIKit.SessionTaskError.responseError(apiKitError) = error.error {
                if case let JSONRPCKit.JSONRPCError.responseError(_, message, _) = apiKitError {
                  errorMessage = "Cannot estimate gas, please try again later. Error: \(message)"
                }
              }
              if errorMessage.lowercased().contains("INSUFFICIENT_OUTPUT_AMOUNT".lowercased()) || errorMessage.lowercased().contains("Return amount is not enough".lowercased()) {
                errorMessage = "Transaction will probably fail. There may be low liquidity, you can try a smaller amount or increase the slippage."
              }
              if errorMessage.lowercased().contains("Unknown(0x)".lowercased()) {
                errorMessage = "Transaction will probably fail due to various reasons. Please try increasing the slippage or selecting a different platform."
              }
                self.navigationController?.showErrorTopBannerMessage(message: errorMessage)
            }
          }
        } else {
          let signTx = sendTx.toSignTransaction(account: account, setting: setting)
          KNGeneralProvider.shared.getEstimateGasLimit(transaction: signTx) { estResult in
            switch estResult {
            case .success:
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
                        transactionDescription: "Application",
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
                        self.navigationController?.displayError(error: error)
                    }
                  })
                case .failure(let error):
                    self.navigationController?.displayError(error: error)
                }
                self.navigationController?.hideLoading()
              }
            case .failure(let error):
                self.navigationController?.hideLoading()
              var errorMessage = "Can not estimate Gas Limit"
              if case let APIKit.SessionTaskError.responseError(apiKitError) = error.error {
                if case let JSONRPCKit.JSONRPCError.responseError(_, message, _) = apiKitError {
                  errorMessage = "Cannot estimate gas, please try again later. Error: \(message)"
                }
              }
              if errorMessage.lowercased().contains("INSUFFICIENT_OUTPUT_AMOUNT".lowercased()) || errorMessage.lowercased().contains("Return amount is not enough".lowercased()) {
                errorMessage = "Transaction will probably fail. There may be low liquidity, you can try a smaller amount or increase the slippage."
              }
              if errorMessage.lowercased().contains("Unknown(0x)".lowercased()) {
                errorMessage = "Transaction will probably fail due to various reasons. Please try increasing the slippage or selecting a different platform."
              }
                self.navigationController?.showErrorTopBannerMessage(message: errorMessage)
            }
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
    self.navigationController?.present(controller, animated: true, completion: nil)
    self.transactionConfirm = controller
  }
  
  private func signMessage(with type: SignMessageType, callbackID: Int) {
    guard case .real(let account) = self.session.wallet.type, let keystore = self.session.externalProvider?.keystore else { return }
    var result: Result<Data, KeystoreError>
    switch type {
    case .message(let data):
      result  = keystore.signPersonalMessage(data, for: account)
    case .personalMessage(let data):
      result = keystore.signPersonalMessage(data, for: account)
    case .typedMessage(let typedData):
      if typedData.isEmpty {
        result = .failure(KeystoreError.failedToSignMessage)
      } else {
        result = keystore.signTypedMessage(typedData, for: account)
      }
    case .eip712v3And4(let data):
      result = keystore.signEip712TypedData(data, for: account)
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
}

extension MiniAppDetailViewController: BrowserOptionsViewControllerDelegate {
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
  
  fileprivate func openWalletListView() {
    let viewModel = WalletsListViewModel(
      walletObjects: KNWalletStorage.shared.availableWalletObjects,
      currentWallet: self.session.currentWalletObject
    )
    let walletsList = WalletsListViewController(viewModel: viewModel)
    walletsList.delegate = self
    self.present(walletsList, animated: true, completion: nil)
  }
}

extension MiniAppDetailViewController: WalletsListViewControllerDelegate {
  func walletsListViewController(_ controller: WalletsListViewController, run event: WalletsListViewEvent) {
    switch event {
    case .connectWallet:
      let qrcode = QRCodeReaderViewController()
      qrcode.delegate = self
        self.navigationController?.present(qrcode, animated: true, completion: nil)
    case .manageWallet:
      self.delegate?.dAppCoordinatorDidSelectManageWallet()
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
      self.delegate?.dAppCoordinatorDidSelectWallet(wal)
    case .addWallet:
      self.delegate?.dAppCoordinatorDidSelectAddWallet()
    }
  }
}

extension MiniAppDetailViewController: GasFeeSelectorPopupViewControllerDelegate {
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
        self.navigationController?.showBottomBannerView(
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
              self.navigationController?.showTopBannerView(message: errorMessage)
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
              self.navigationController?.showTopBannerView(message: errorMessage)
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
              self.navigationController?.showTopBannerView(message: errorMessage)
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
              self.navigationController?.showTopBannerView(message: errorMessage)
          }
        }
      }
      
    default:
      break
    }
  }
  
  
}

extension MiniAppDetailViewController: QRCodeReaderDelegate {
  func readerDidCancel(_ reader: QRCodeReaderViewController!) {
    reader.dismiss(animated: true, completion: nil)
  }

  func reader(_ reader: QRCodeReaderViewController!, didScanResult result: String!) {
    reader.dismiss(animated: true) {
      guard let url = WCURL(result) else {
        self.navigationController?.showTopBannerView(
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
            self.navigationController?.present(controller, animated: true, completion: nil)
          }
          
        case .failure(_):
            self.navigationController?.showTopBannerView(
            with: "Private Key Error",
            message: "Can not get Private key",
            time: 1.5
          )
        }
      }
    }
  }
}

extension MiniAppDetailViewController: KNTransactionStatusPopUpDelegate {
  func transactionStatusPopUp(_ controller: KNTransactionStatusPopUp, action: KNTransactionStatusPopUpEvent) {
    self.transactionStatusVC = nil
    switch action {
//    case .transfer:
//      self.openSendTokenView()
    case .openLink(let url):
        self.navigationController?.openSafari(with: url)
    case .speedUp(let tx):
      self.openTransactionSpeedUpViewController(transaction: tx)
    case .cancel(let tx):
      self.openTransactionCancelConfirmPopUpFor(transaction: tx)
    case .goToSupport:
        self.navigationController?.openSafari(with: "https://docs.krystal.app/")
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
    self.navigationController?.present(vc, animated: true, completion: nil)
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
    self.navigationController?.present(vc, animated: true, completion: nil)
  }
}

extension MiniAppDetailViewController: RateTransactionPopupDelegate {
  func didUpdateRate(rate: Int) {
    
  }

  func didSendRate() {
    
  }
  
  func didSendRate(rate: Int, comment: String) {
    let provider = MoyaProvider<KrytalService>(plugins: [NetworkLoggerPlugin(verbose: true)])
    self.showLoadingHUD()
    provider.request(.addReview(address: self.session.wallet.addressString, url: self.currentMiniApp.url, rating: Double(rate), comment: comment)) { (result) in
      DispatchQueue.main.async {
        self.hideLoading()
      }
      if case .success(let resp) = result {
        print("Success")
      } else {
        print("Error")
      }
    }
  }
}
