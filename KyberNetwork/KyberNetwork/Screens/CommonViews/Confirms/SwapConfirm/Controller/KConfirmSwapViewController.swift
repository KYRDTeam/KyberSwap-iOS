// Copyright SIX DAY LLC. All rights reserved.

import UIKit



protocol KConfirmSwapViewControllerDelegate: class {
  func kConfirmSwapViewController(_ controller: KConfirmSwapViewController, confirm data: KNDraftExchangeTransaction, signTransaction: SignTransaction, internalHistoryTransaction: InternalHistoryTransaction)
  func kConfirmSwapViewControllerDidCancel(_ controller: KConfirmSwapViewController)
}

class KConfirmSwapViewController: KNBaseViewController {


  @IBOutlet weak var titleLabel: UILabel!

  @IBOutlet weak var fromAmountLabel: UILabel!
  @IBOutlet weak var toAmountLabel: UILabel!

  @IBOutlet weak var equivalentUSDValueLabel: UILabel!
  @IBOutlet weak var minAcceptableRateTextLabel: UILabel!
  @IBOutlet weak var transactionFeeTextLabel: UILabel!

  @IBOutlet weak var expectedRateLabel: UILabel!
  @IBOutlet weak var minAcceptableRateValueButton: UIButton!

  @IBOutlet weak var transactionFeeETHLabel: UILabel!
  @IBOutlet weak var transactionFeeUSDLabel: UILabel!
  @IBOutlet weak var transactionGasPriceLabel: UILabel!
  @IBOutlet weak var warningETHBalImageView: UIImageView!
  @IBOutlet weak var warningETHBalanceLabel: UILabel!

  @IBOutlet weak var confirmButton: UIButton!
  @IBOutlet weak var cancelButton: UIButton!
  @IBOutlet weak var reserveRoutingMessageContainer: UIView!
  @IBOutlet weak var reserveRoutingMessageLabel: UILabel!
  @IBOutlet weak var reserveRountingContainerTopConstraint: NSLayoutConstraint!
  @IBOutlet weak var contentViewTopContraint: NSLayoutConstraint!
  @IBOutlet weak var contentView: UIView!
  @IBOutlet weak var rateWarningLabel: UILabel!
  @IBOutlet weak var rateTopContraint: NSLayoutConstraint!
  
  fileprivate var viewModel: KConfirmSwapViewModel
  weak var delegate: KConfirmSwapViewControllerDelegate?
  let transitor = TransitionDelegate()

  init(viewModel: KConfirmSwapViewModel) {
    self.viewModel = viewModel
    super.init(nibName: KConfirmSwapViewController.className, bundle: nil)
    self.modalPresentationStyle = .custom
    self.transitioningDelegate = transitor
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    self.setupUI()
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    self.confirmButton.removeSublayer(at: 0)
    self.confirmButton.applyHorizontalGradient(with: UIColor.Kyber.SWButtonColors)
  }

  fileprivate func setupUI() {
    self.titleLabel.text = self.viewModel.titleString
    self.titleLabel.addLetterSpacing()

    self.fromAmountLabel.text = self.viewModel.leftAmountString
    self.fromAmountLabel.addLetterSpacing()
    self.toAmountLabel.text = self.viewModel.rightAmountString
    self.toAmountLabel.addLetterSpacing()

    self.expectedRateLabel.text = self.viewModel.displayEstimatedRate
    self.expectedRateLabel.addLetterSpacing()
    self.minAcceptableRateValueButton.setTitle(self.viewModel.minRateString, for: .normal)
    self.minAcceptableRateValueButton.setTitleColor(
      self.viewModel.warningMinAcceptableRateMessage == nil ? UIColor(red: 245, green: 246, blue: 249) : UIColor(red: 250, green: 101, blue: 102),
      for: .normal
    )
    self.minAcceptableRateValueButton.isEnabled = self.viewModel.warningMinAcceptableRateMessage != nil
    self.minAcceptableRateValueButton.semanticContentAttribute = .forceRightToLeft
    self.minAcceptableRateValueButton.setImage(
      self.viewModel.warningMinAcceptableRateMessage == nil ? nil : UIImage(named: "info_red_icon"),
      for: .normal
    )

    self.transactionFeeETHLabel.text = self.viewModel.feeETHString
    self.transactionFeeETHLabel.addLetterSpacing()
    self.transactionFeeUSDLabel.text = self.viewModel.feeUSDString
    self.transactionFeeUSDLabel.addLetterSpacing()
    transactionGasPriceLabel.text = viewModel.transactionGasPriceString
    transactionGasPriceLabel.addLetterSpacing()

    self.confirmButton.rounded(radius: self.confirmButton.frame.size.height / 2)
    self.confirmButton.setTitle(
      NSLocalizedString("confirm", value: "Confirm", comment: ""),
      for: .normal
    )
    self.confirmButton.applyHorizontalGradient(with: UIColor.Kyber.SWButtonColors)
    self.cancelButton.setTitle(
      NSLocalizedString("cancel", value: "Cancel", comment: ""),
      for: .normal
    )
    self.cancelButton.rounded(color: UIColor(red: 35, green: 167, blue: 181), width: 1, radius: self.cancelButton.frame.size.height / 2)

    self.minAcceptableRateTextLabel.text = NSLocalizedString("min.acceptable.rate", value: "Min Acceptable Rate", comment: "")
    self.transactionFeeTextLabel.text = "Maximum gas fee".toBeLocalised()
    self.transactionFeeTextLabel.addLetterSpacing()
    self.equivalentUSDValueLabel.text = self.viewModel.displayEquivalentUSDAmount

    let warningBalShown = self.viewModel.warningETHBalanceShown
    self.warningETHBalanceLabel.isHidden = !warningBalShown
    self.warningETHBalImageView.isHidden = !warningBalShown
    self.warningETHBalanceLabel.text = "After this swap you will not have enough ETH for further transactions.".toBeLocalised()

    self.reserveRoutingMessageContainer.isHidden = self.viewModel.hint == "" || self.viewModel.hint == "0x"
    if !warningBalShown {
      self.reserveRountingContainerTopConstraint.constant = 23
    } else {
      self.reserveRountingContainerTopConstraint.constant = 62.5
    }

    self.reserveRoutingMessageLabel.text = self.viewModel.reverseRoutingText
    self.rateWarningLabel.isHidden = !self.viewModel.hasRateWarning
    self.rateTopContraint.constant = self.viewModel.hasRateWarning ? 60.0 : 14.0

    self.view.layoutIfNeeded()
  }

  @IBAction func tapMinAcceptableRateValue(_ sender: Any?) {
    guard let message = self.viewModel.warningMinAcceptableRateMessage else { return }
    self.showTopBannerView(
      with: "",
      message: message,
      icon: UIImage(named: "info_red_icon"),
      time: 2.0
    )
  }

  @IBAction func confirmButtonPressed(_ sender: Any) {
    KNCrashlyticsUtil.logCustomEvent(withName: "screen_confirm_swap", customAttributes: ["action": "confirmed_\(self.viewModel.transaction.from.symbol)_\(self.viewModel.transaction.to.symbol)"])
    self.dismiss(animated: true, completion: nil)
    
    let internalHistory = InternalHistoryTransaction(type: .swap, state: .pending, fromSymbol: self.viewModel.transaction.from.symbol, toSymbol: self.viewModel.transaction.to.symbol, transactionDescription: "\(self.viewModel.rightAmountString) -> \(self.viewModel.leftAmountString)", transactionDetailDescription: self.viewModel.displayEstimatedRate)
    
    self.delegate?.kConfirmSwapViewController(self, confirm: self.viewModel.transaction, signTransaction: self.viewModel.signTransaction, internalHistoryTransaction: internalHistory)
  }

  @IBAction func cancelButtonPressed(_ sender: Any) {
    self.dismiss(animated: true, completion: nil)
    KNCrashlyticsUtil.logCustomEvent(withName: "swapconfirm_cancel",
                                     customAttributes: [
                                      "token_pair": self.viewModel.titleString,
                                      "amount": self.viewModel.leftAmountString,
                                      "current_rate": self.viewModel.displayEstimatedRate,
                                      "min_rate": self.viewModel.minRateString,
                                      "tx_fee": self.viewModel.feeETHString,
      ]
    )
    self.delegate?.kConfirmSwapViewControllerDidCancel(self)
//    self.delegate?.kConfirmSwapViewController(self, run: .cancel)
  }

  @IBAction func helpButtonTapped(_ sender: UIButton) {
    KNCrashlyticsUtil.logCustomEvent(withName: "swapconfirm_gas_fee_info_tapped", customAttributes: nil)
    self.showBottomBannerView(
      message: "The.actual.cost.of.the.transaction.is.generally.lower".toBeLocalised(),
      icon: UIImage(named: "help_icon_large") ?? UIImage(),
      time: 10
    )
  }

  @IBAction func tapOutsidePopup(_ sender: UITapGestureRecognizer) {
    self.dismiss(animated: true, completion: nil)
  }
}

extension KConfirmSwapViewController: BottomPopUpAbstract {
  func setTopContrainConstant(value: CGFloat) {
    self.contentViewTopContraint.constant = value
  }

  func getPopupHeight() -> CGFloat {
    return 574
  }

  func getPopupContentView() -> UIView {
    return self.contentView
  }
}
