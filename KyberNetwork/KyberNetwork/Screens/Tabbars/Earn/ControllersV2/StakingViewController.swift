//
//  StakingViewController.swift
//  KyberNetwork
//
//  Created by Ta Minh Quan on 26/10/2022.
//

import UIKit
import BigInt

typealias UserSettings = (BasicTransactionSettings, AdvancedTransactionSettings?)
typealias StakeDisplayInfo = (amount: String, apy: String, receiveAmount: String, rate: String, fee: String, platform: String, stakeTokenIcon: String, fromSym: String, toSym: String)

protocol StakingViewControllerDelegate: class {
  func didSelectNext(_ viewController: StakingViewController, settings: UserSettings, txObject: TxObject, displayInfo: StakeDisplayInfo)
  func sendApprove(_ viewController: StakingViewController, tokenAddress: String, remain: BigInt, symbol: String, toAddress: String)
}

enum FormState: Equatable {
  case valid
  case error(msg: String)
  case empty
  
  static public func == (lhs: FormState, rhs: FormState) -> Bool {
    switch (lhs, rhs) {
    case (.valid, .valid), (.empty, .empty):
      return true
    default:
      return false
    }
  }
}

enum NextButtonState {
  case notApprove
  case needApprove
  case approved
  case noNeed
}

class StakingViewModel {
  let pool: EarnPoolModel
  let selectedPlatform: EarnPlatform
  let apiService = KrystalService()
  var optionDetail: Observable<[EarningToken]?> = .init(nil)
  var error: Observable<Error?> = .init(nil)
  var amount: Observable<String> = .init("")
  var selectedEarningToken: Observable<EarningToken?> = .init(nil)
  var formState: Observable<FormState> = .init(.empty)
  var gasPrice: Observable<BigInt> = .init(KNGasCoordinator.shared.standardKNGas)
  var gasLimit: Observable<BigInt> = .init(KNGasConfiguration.earnGasLimitDefault)
  var baseGasLimit: BigInt = KNGasConfiguration.earnGasLimitDefault
  var txObject: Observable<TxObject?> = .init(nil)
  var isLoading: Observable<Bool> = .init(false)
  var basicSetting: BasicTransactionSettings = BasicTransactionSettings(gasPriceType: .medium) {
    didSet {
      let gas = self.basicSetting.gasPriceType.getGasValue()
      self.gasPrice.value = gas
    }
  }
  var advancedSetting: AdvancedTransactionSettings? = nil {
    didSet {
      guard let setting = self.advancedSetting else { return }
      self.gasPrice.value = setting.maxFee
      self.gasLimit.value = setting.gasLimit
    }
  }
  
  var nextButtonStatus: Observable<NextButtonState> = .init(.notApprove)
  
  var tokenAllowance: BigInt? {
    didSet {
      self.checkNextButtonStatus()
    }
  }
  
  init(pool: EarnPoolModel, platform: EarnPlatform) {
    self.pool = pool
    self.selectedPlatform = platform
  }
  
  var displayMainHeader: String {
    return "Stake \(pool.token.symbol.uppercased()) on \(selectedPlatform.name.uppercased())"
  }
  
  var displayStakeToken: String {
    return pool.token.getBalanceBigInt().shortString(decimals: pool.token.decimals) + " " + pool.token.symbol.uppercased()
  }
  
  var displayAPY: String {
    return selectedPlatform.apy.description + " %"
  }
  
  var amountBigInt: BigInt {
    return self.amount.value.amountBigInt(decimals: pool.token.decimals) ?? BigInt(0)
  }
  
  var transactionFee: BigInt {
    return self.gasPrice.value * self.gasLimit.value
  }
  
  var feeETHString: String {
    let string: String = self.transactionFee.displayRate(decimals: 18)
    return "\(string) \(KNGeneralProvider.shared.quoteToken)"
  }

  var feeUSDString: String {
    guard let price = KNTrackerRateStorage.shared.getETHPrice() else { return "" }
    let usd = self.transactionFee * BigInt(price.usd * pow(10.0, 18.0)) / BigInt(10).power(18)
    let valueString: String = usd.displayRate(decimals: 18)
    return "(~ \(valueString) USD)"
  }
  
  var displayFeeString: String {
    return "\(feeETHString) \(feeUSDString)"
  }
  
  func requestOptionDetail() {
    apiService.getStakingOptionDetail(platform: selectedPlatform.name, earningType: selectedPlatform.type, chainID: "\(pool.chainID)", tokenAddress: pool.token.address) { result in
      switch result {
      case .success(let detail):
        self.optionDetail.value = detail
        self.selectedEarningToken.value = detail.first
      case .failure(let error):
        self.error.value = error
      }
    }
  }
  
  func checkNextButtonStatus() {
    guard let tokenAllowance = tokenAllowance else {
      self.nextButtonStatus.value = .notApprove
      getAllowance()
      return
    }
    if amountBigInt > tokenAllowance {
      self.nextButtonStatus.value = .needApprove
    } else {
      self.nextButtonStatus.value = .noNeed
    }
  }
  
  var buildTxRequestParams: JSONDictionary {
    var params: JSONDictionary = [
      "tokenAmount": amountBigInt.description,
      "chainID": pool.chainID,
      "earningType": selectedPlatform.type,
      "platform": selectedPlatform.name,
      "userAddress": AppDelegate.session.address.addressString,
      "tokenAddress": pool.token.address
    ]
    if selectedPlatform.name.lowercased() == "ankr" {
      var useC = false
      if selectedEarningToken.value?.name.suffix(1).description.lowercased() == "c" {
        useC = true
      }
      
      params["extraData"] = ["ankr": ["useTokenC": useC]]
    }
    return params
  }
  
  func requestBuildStateTx(showLoading: Bool = false, completion: @escaping BlankBlock = {}) {
    if showLoading { isLoading.value = true }
    apiService.buildStakeTx(param: buildTxRequestParams) { result in
      switch result {
      case .success(let tx):
        self.txObject.value = tx
        self.gasLimit.value = BigInt(tx.gasLimit.drop0x, radix: 16) ?? KNGasConfiguration.earnGasLimitDefault
        completion()
      case .failure(let error):
        self.error.value = error
      }
      if showLoading { self.isLoading.value = false }
    }
  }
  
  var displayAmountReceive: String {
    guard let detail = selectedEarningToken.value, !amount.value.isEmpty, let amountDouble = Double(amount.value) else { return "---" }
    let receiveAmt = detail.exchangeRate * amountDouble
    return receiveAmt.description + " " + detail.symbol
  }
  
  var displayRate: String {
    guard let detail = selectedEarningToken.value else { return "---" }
    return "1 \(pool.token.symbol) = \(detail.exchangeRate) \(detail.symbol)"
  }
  
  var isAmountTooSmall: Bool {
    
    return self.amountBigInt == BigInt(0)
  }

  var isAmountTooBig: Bool {
    return self.amountBigInt > pool.token.getBalanceBigInt()
  }
  
  func getAllowance() {
    guard !pool.token.isQuoteToken else {
      nextButtonStatus.value = .noNeed
      return
    }
    guard let tx = txObject.value else {
      requestBuildStateTx(showLoading: false, completion: {
        self.getAllowance()
      })
      return
    }
    
    let contractAddress = tx.to
    
    KNGeneralProvider.shared.getAllowance(for: AppDelegate.session.address.addressString, networkAddress: contractAddress, tokenAddress: pool.token.address) { result in
      switch result {
      case .success(let number):
        self.tokenAllowance = number
      case .failure(let error):
        self.error.value = error
        self.tokenAllowance = nil
      }
    }
  }
}

class StakingViewController: InAppBrowsingViewController {
  
  @IBOutlet weak var stakeMainHeaderLabel: UILabel!
  @IBOutlet weak var stakeTokenLabel: UILabel!
  @IBOutlet weak var stakeTokenImageView: UIImageView!
  @IBOutlet weak var amountTextField: UITextField!
  @IBOutlet weak var apyInfoView: SwapInfoView!
  @IBOutlet weak var amountReceiveInfoView: SwapInfoView!
  @IBOutlet weak var rateInfoView: SwapInfoView!
  @IBOutlet weak var networkFeeInfoView: SwapInfoView!
  
  @IBOutlet weak var earningTokenContainerView: StakingEarningTokensView!
  @IBOutlet weak var infoAreaTopContraint: NSLayoutConstraint!
  @IBOutlet weak var errorMsgLabel: UILabel!
  @IBOutlet weak var amountFieldContainerView: UIView!
  @IBOutlet weak var nextButton: UIButton!
  
  var viewModel: StakingViewModel!
  var keyboardTimer: Timer?
  
  weak var delegate: StakingViewControllerDelegate?
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setupUI()
    bindingViewModel()
    viewModel.requestOptionDetail()
    viewModel.getAllowance()
  }
  
  private func setupUI() {
    apyInfoView.setTitle(title: "APY (Est. Yield", underlined: false)
    apyInfoView.iconImageView.isHidden = true
    
    amountReceiveInfoView.setTitle(title: "You will receive", underlined: false)
    amountReceiveInfoView.iconImageView.isHidden = true
    
    rateInfoView.setTitle(title: "Rate", underlined: false, shouldShowIcon: true)
    rateInfoView.iconImageView.isHidden = true
    
    networkFeeInfoView.setTitle(title: "Network Fee", underlined: false)
    networkFeeInfoView.iconImageView.isHidden = true
    
    earningTokenContainerView.delegate = self
    updateUIGasFee()
  }
  
  fileprivate func updateRateInfoView() {
    self.amountReceiveInfoView.setValue(value: self.viewModel.displayAmountReceive)
    self.rateInfoView.setValue(value: self.viewModel.displayRate)
  }
  
  fileprivate func updateUIEarningTokenView() {
    if let data = viewModel.optionDetail.value, data.count <= 1 {
      earningTokenContainerView.isHidden = true
      infoAreaTopContraint.constant = 40
    } else {
      earningTokenContainerView.isHidden = false
      infoAreaTopContraint.constant = 211
    }
  }
  
  fileprivate func updateUIError() {
    switch viewModel.formState.value {
    case .valid:
      amountFieldContainerView.rounded(radius: 16)
      errorMsgLabel.text = ""
      nextButton.alpha = 1
    case .error(let msg):
      amountFieldContainerView.rounded(color: UIColor.Kyber.textRedColor, width: 1, radius: 16)
      errorMsgLabel.text = msg
      nextButton.alpha = 0.2
    case .empty:
      amountFieldContainerView.rounded(radius: 16)
      errorMsgLabel.text = ""
      nextButton.alpha = 0.2
    }
  }
  
  fileprivate func updateUIGasFee() {
    networkFeeInfoView.setValue(value: viewModel.displayFeeString)
  }
  
  private func bindingViewModel() {
    stakeMainHeaderLabel.text = viewModel.displayMainHeader
    stakeTokenLabel.text = viewModel.displayStakeToken
    stakeTokenImageView.setImage(urlString: viewModel.pool.token.logo, symbol: viewModel.pool.token.symbol)
    apyInfoView.setValue(value: viewModel.selectedPlatform.apy.description, highlighted: true)
    viewModel.selectedEarningToken.observeAndFire(on: self) { _ in
      self.updateRateInfoView()
    }
    viewModel.optionDetail.observeAndFire(on: self) { data in
      if let unwrap = data {
        self.earningTokenContainerView.updateData(unwrap)
      }
      self.updateUIEarningTokenView()
    }
    viewModel.amount.observeAndFire(on: self) { _ in
      self.updateRateInfoView()
      self.updateUIError()
      self.viewModel.checkNextButtonStatus()
    }
    viewModel.formState.observeAndFire(on: self) { _ in
      self.updateUIError()
    }
    
    viewModel.txObject.observeAndFire(on: self, observerBlock: { value in
      guard let tx = value else { return }
      print("[Stake] \(tx)")
    })
    
    viewModel.isLoading.observeAndFire(on: self) { value in
      if value {
        self.displayLoading()
      } else {
        self.hideLoading()
        guard !self.viewModel.amount.value.isEmpty else { return }
        self.nextButtonTapped(self.nextButton)
      }
    }
    
    viewModel.gasLimit.observeAndFire(on: self) { _ in
      self.updateUIGasFee()
    }
    
    viewModel.gasPrice.observeAndFire(on: self) { _ in
      self.updateUIGasFee()
    }
    
    viewModel.nextButtonStatus.observeAndFire(on: self) { value in
      switch value {
      case .notApprove:
        self.nextButton.setTitle(String(format: "Checking", self.viewModel.pool.token.symbol), for: .normal)
        self.nextButton.alpha = 0.2
        self.nextButton.isEnabled = false
      case .needApprove:
        self.nextButton.setTitle(String(format: Strings.approveToken, self.viewModel.pool.token.symbol), for: .normal)
        self.nextButton.alpha = 1
        self.nextButton.isEnabled = true
      case .approved:
        self.nextButton.setTitle("Stake Now", for: .normal)
        self.updateUIError()
      case .noNeed:
        self.nextButton.setTitle("Stake Now", for: .normal)
        self.updateUIError()
      }
    }
  }

  @IBAction func backButtonTapped(_ sender: UIButton) {
    navigationController?.popViewController(animated: true)
  }
  
  @IBAction func maxButtonTapped(_ sender: UIButton) {
    viewModel.amount.value = viewModel.pool.token.getBalanceBigInt().fullString(decimals: viewModel.pool.token.decimals)
    amountTextField.text = viewModel.amount.value
  }
  
  @IBAction func nextButtonTapped(_ sender: UIButton) {
    if viewModel.nextButtonStatus.value == .needApprove {
      delegate?.sendApprove(self, tokenAddress: viewModel.pool.token.address, remain: viewModel.tokenAllowance ?? .zero, symbol: viewModel.pool.token.symbol, toAddress: viewModel.txObject.value?.to ?? "")
    } else {
      //    guard viewModel.formState.value == .valid else { return }
      if let tx = viewModel.txObject.value {
        let displayInfo = ("\(viewModel.amount.value) \(viewModel.pool.token.symbol)", viewModel.displayAPY, viewModel.displayAmountReceive, viewModel.displayRate, viewModel.displayFeeString, viewModel.selectedPlatform.name, viewModel.pool.token.logo, viewModel.pool.token.symbol, viewModel.selectedEarningToken.value?.symbol ?? "")
        delegate?.didSelectNext(self, settings: (viewModel.basicSetting, viewModel.advancedSetting), txObject: tx, displayInfo: displayInfo)
      } else {
        viewModel.requestBuildStateTx(showLoading: true)
      }
    }
    
  }
  
  func coordinatorSuccessApprove(address: String) {
    viewModel.nextButtonStatus.value = .approved
    viewModel.tokenAllowance = nil
  }
  
  func coordinatorFailApprove(address: String) {
    viewModel.nextButtonStatus.value = .notApprove
  }
  
}

extension StakingViewController: UITextFieldDelegate {
  func textFieldShouldClear(_ textField: UITextField) -> Bool {
    textField.text = ""
    self.viewModel.amount.value = ""
    return false
  }
  
  func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
    let text = ((textField.text ?? "") as NSString).replacingCharacters(in: range, with: string)
    let cleanedText = text.cleanStringToNumber()
    if cleanedText.amountBigInt(decimals: self.viewModel.pool.token.decimals) == nil { return false }
    textField.text = cleanedText
    self.viewModel.amount.value = cleanedText
    self.keyboardTimer?.invalidate()
    self.keyboardTimer = Timer.scheduledTimer(
            timeInterval: 1,
            target: self,
            selector: #selector(StakingViewController.keyboardPauseTyping),
            userInfo: ["textField": textField],
            repeats: false)
    return false
  }
  
  @objc func keyboardPauseTyping(timer: Timer) {
    updateRateInfoView()
    viewModel.requestBuildStateTx()
  }
  
  func textFieldDidEndEditing(_ textField: UITextField) {
//    showWarningInvalidAmountDataIfNeeded()
  }
  
//  fileprivate func showWarningInvalidAmountDataIfNeeded() {
//    guard !self.viewModel.amount.value.isEmpty else {
//      viewModel.formState.value = .empty
//      return
//    }
////    guard self.viewModel.isEnoughFee else {
////      self.showWarningTopBannerMessage(
////        with: NSLocalizedString("Insufficient \(KNGeneralProvider.shared.quoteToken) for transaction", value: "Insufficient \(KNGeneralProvider.shared.quoteToken) for transaction", comment: ""),
////        message: String(format: "Deposit more \(KNGeneralProvider.shared.quoteToken) or click Advanced to lower GAS fee".toBeLocalised(), self.viewModel.transactionFee.shortString(units: .ether, maxFractionDigits: 6))
////      )
////      return true
////    }
//
//    guard !self.viewModel.isAmountTooSmall else {
//      viewModel.formState.value = .error(msg: "amount.to.send.greater.than.zero".toBeLocalised())
//      return
//    }
//    guard !self.viewModel.isAmountTooBig else {
//      viewModel.formState.value = .error(msg: "balance.not.enough.to.make.transaction".toBeLocalised())
//      return
//    }
//    viewModel.formState.value = .valid
//  }
}

extension StakingViewController: StakingEarningTokensViewDelegate {
  func didSelectEarningToken(_ token: EarningToken) {
    viewModel.selectedEarningToken.value = token
  }
}
