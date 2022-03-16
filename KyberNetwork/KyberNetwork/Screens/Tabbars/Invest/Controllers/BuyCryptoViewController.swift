//
//  BuyCryptoViewController.swift
//  KyberNetwork
//
//  Created by Com1 on 23/02/2022.
//

import UIKit

enum BuyCryptoEvent {
  case openHistory
  case openWalletsList
  case updateRate
  case selectNetwork
  case selectFiat(fiat: [FiatModel])
  case selectCrypto(crypto: [FiatModel])
}

protocol BuyCryptoViewControllerDelegate: class {
  func buyCryptoViewController(_ controller: BuyCryptoViewController, run event: BuyCryptoEvent)
  func didBuyCrypto(_ buyCryptoModel: BuyCryptoModel)
}

class BuyCryptoViewModel {
  var wallet: Wallet
  var dataSource: [FiatCryptoModel]?
  var fiatCurrency: [String]?
  var cryptoCurrency: [String]?
  init(wallet: Wallet) {
    self.wallet = wallet
  }
  
}

class BuyCryptoViewController: KNBaseViewController {
  @IBOutlet weak var walletsListButton: UIButton!
  @IBOutlet weak var pendingTxIndicatorView: UIView!
  @IBOutlet weak var cryptoButton: UIButton!
  @IBOutlet weak var fiatButton: UIButton!
  @IBOutlet weak var networkLabel: UILabel!
  @IBOutlet weak var addressTextField: UITextField!
  @IBOutlet weak var cryptoInputView: UIView!
  @IBOutlet weak var fiatInputView: UIView!
  @IBOutlet weak var addressInputView: UIView!
  @IBOutlet weak var fiatTextField: UITextField!
  @IBOutlet weak var cryptoTextField: UITextField!
  @IBOutlet weak var networkInputView: UIView!
  //  var buyCryptoModel: BuyCryptoModel?

  weak var delegate: BuyCryptoViewControllerDelegate?
  let transitor = TransitionDelegate()
  let viewModel: BuyCryptoViewModel
  
  init(viewModel: BuyCryptoViewModel) {
    self.viewModel = viewModel
    super.init(nibName: BuyCryptoViewController.className, bundle: nil)
    self.modalPresentationStyle = .custom
    self.transitioningDelegate = transitor
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    self.updateUI()
  }
  
  func updateUI() {
    self.walletsListButton.setTitle(self.viewModel.wallet.address.description, for: .normal)
    self.addressTextField.text = self.viewModel.wallet.address.description
    self.updateUIPendingTxIndicatorView()
  }
  
  fileprivate func updateUIPendingTxIndicatorView() {
    guard self.isViewLoaded else {
      return
    }
    let pendingTransaction = EtherscanTransactionStorage.shared.getInternalHistoryTransaction().first { transaction in
      transaction.state == .pending
    }
    self.pendingTxIndicatorView.isHidden = pendingTransaction == nil
  }
  
  func coordinatorDidUpdateWallet(_ wallet: Wallet) {
    self.viewModel.wallet = wallet
    guard self.isViewLoaded else { return }
    self.updateUI()
  }

  func coordinatorDidUpdatePendingTx() {
    self.updateUIPendingTxIndicatorView()
  }
  
  func coordinatorDidSelectFiatCrypto(model: FiatModel, type: SearchCurrencyType) {
    switch type {
    case .fiat:
      self.fiatButton.setTitle(model.currency, for: .normal)
    case .crypto:
      self.cryptoButton.setTitle(model.currency, for: .normal)
    }
  }
  
  func coordinatorDidSelectNetwork(chain: String) {
    self.networkLabel.text = chain
    self.networkInputView.layer.borderColor = UIColor.clear.cgColor
    self.networkInputView.layer.borderWidth = 1.0
  }

  func coordinatorDidUpdateFiatCrypto(data: [FiatCryptoModel]) {
    var fiatCurrency: [String] = []
    var cryptoCurrency: [String] = []
    
    data.forEach { model in
      if !fiatCurrency.contains(model.fiatCurrency) {
        fiatCurrency.append(model.fiatCurrency)
      }
      
      if !cryptoCurrency.contains(model.cryptoCurrency) {
        cryptoCurrency.append(model.cryptoCurrency)
      }
    }

    self.viewModel.fiatCurrency = fiatCurrency
    self.viewModel.cryptoCurrency = cryptoCurrency
  }

  @IBAction func backButtonTapped(_ sender: Any) {
    self.navigationController?.popViewController(animated: true)
  }

  @IBAction func historyListButtonTapped(_ sender: UIButton) {
    self.delegate?.buyCryptoViewController(self, run: .openHistory)
  }

  @IBAction func walletsListButtonTapped(_ sender: UIButton) {
    self.delegate?.buyCryptoViewController(self, run: .openWalletsList)
  }
  
  @IBAction func updateRateButtonTapped(_ sender: Any) {
    self.delegate?.buyCryptoViewController(self, run: .updateRate)
  }

  @IBAction func buyNowButtonTapped(_ sender: Any) {
    guard let buyCryptoModel = self.validateInput() else {
      return
    }
    self.delegate?.didBuyCrypto(buyCryptoModel)
  }

  @IBAction func selectFiatButtonTapped(_ sender: Any) {
    guard let fiatCurrency = self.viewModel.fiatCurrency else { return }
    var fiatModels: [FiatModel] = []
    fiatCurrency.forEach { item in
      fiatModels.append(FiatModel(url: item, currency: item))
    }
    self.delegate?.buyCryptoViewController(self, run: .selectFiat(fiat: fiatModels))
  }

  @IBAction func selectCryptoButtonTapped(_ sender: Any) {
    guard let cryptoCurrency = self.viewModel.cryptoCurrency else { return }
    var cryptoModels: [FiatModel] = []
    cryptoCurrency.forEach { item in
      cryptoModels.append(FiatModel(url: item, currency: item))
    }
    self.delegate?.buyCryptoViewController(self, run: .selectCrypto(crypto: cryptoModels))
  }

  @IBAction func selectNetworkButtonTapped(_ sender: Any) {
    self.delegate?.buyCryptoViewController(self, run: .selectNetwork)
  }
  
  func validateInput() -> BuyCryptoModel? {
    // validate fiat input
    guard let fiatAmount = self.fiatTextField.text, !fiatAmount.isEmpty else {
      self.fiatInputView.layer.borderColor = UIColor.red.cgColor
      self.fiatInputView.layer.borderWidth = 1.0
      self.shakeView(viewToShake: self.fiatInputView)
      return nil
    }
    
    guard let fiatCurrency = self.fiatButton.titleLabel?.text, !fiatCurrency.isEmpty else {
      self.fiatInputView.layer.borderColor = UIColor.red.cgColor
      self.fiatInputView.layer.borderWidth = 1.0
      self.shakeView(viewToShake: self.fiatInputView)
      return nil
    }

    // validate crypto input
    guard let cryptoAmount = self.cryptoTextField.text, !cryptoAmount.isEmpty else {
      self.cryptoInputView.layer.borderColor = UIColor.red.cgColor
      self.cryptoInputView.layer.borderWidth = 1.0
      self.shakeView(viewToShake: self.cryptoInputView)
      return nil
    }
    
    guard let cryptoCurrency = self.cryptoButton.titleLabel?.text, !cryptoCurrency.isEmpty else {
      self.cryptoInputView.layer.borderColor = UIColor.red.cgColor
      self.cryptoInputView.layer.borderWidth = 1.0
      self.shakeView(viewToShake: self.cryptoInputView)
      return nil
    }

    // validate address
    guard let address = self.addressTextField.text, !address.isEmpty else {
      self.addressInputView.layer.borderColor = UIColor.red.cgColor
      self.addressInputView.layer.borderWidth = 1.0
      self.shakeView(viewToShake: self.addressInputView)
      return nil
    }

    // validate network
    if self.networkLabel.text == "Select Network" {
      self.networkInputView.layer.borderColor = UIColor.red.cgColor
      self.networkInputView.layer.borderWidth = 1.0
      self.shakeView(viewToShake: self.networkInputView)
      return nil
    }
    

    let buyCryptoModel = BuyCryptoModel(cryptoAddress: address, cryptoCurrency: cryptoCurrency, cryptoNetWork: self.networkLabel.text ?? "", fiatCurrency: fiatCurrency, orderAmount: cryptoAmount.doubleValue, requestPrice: fiatAmount.doubleValue)
    return buyCryptoModel
  }

  func shakeView(viewToShake: UIView) {
    let animation = CABasicAnimation(keyPath: "position")
    animation.duration = 0.07
    animation.repeatCount = 2
    animation.autoreverses = true
    animation.fromValue = NSValue(cgPoint: CGPoint(x: viewToShake.center.x - 10, y: viewToShake.center.y))
    animation.toValue = NSValue(cgPoint: CGPoint(x: viewToShake.center.x + 10, y: viewToShake.center.y))

    viewToShake.layer.add(animation, forKey: "position")
  }
}

extension BuyCryptoViewController: UITextFieldDelegate {
  func textFieldDidBeginEditing(_ textField: UITextField) {
    if textField == self.fiatTextField {
      self.fiatInputView.layer.borderColor = UIColor.clear.cgColor
      self.fiatInputView.layer.borderWidth = 1.0
    } else if textField == self.cryptoTextField {
      self.cryptoInputView.layer.borderColor = UIColor.clear.cgColor
      self.cryptoInputView.layer.borderWidth = 1.0
    } else if textField == self.addressTextField {
      self.addressInputView.layer.borderColor = UIColor.clear.cgColor
      self.addressInputView.layer.borderWidth = 1.0
    }
  }
}
