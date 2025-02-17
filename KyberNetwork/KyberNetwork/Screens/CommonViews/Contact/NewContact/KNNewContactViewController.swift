// Copyright SIX DAY LLC. All rights reserved.

import UIKit
import TrustKeystore
import QRCodeReaderViewController

enum KNNewContactViewEvent {
  case dismiss
  case send(address: String)
}

protocol KNNewContactViewControllerDelegate: class {
  func newContactViewController(_ controller: KNNewContactViewController, run event: KNNewContactViewEvent)
}

class KNNewContactViewModel {

  fileprivate(set) var contact: KNContact
  fileprivate(set) var isEditing: Bool
  fileprivate(set) var address: String?
  fileprivate(set) var addressString: String

  init(
    address: String, ens: String? = nil
  ) {
    if let contact = KNContactStorage.shared.contacts.first(where: { $0.address.lowercased() == address.lowercased() }) {
      self.contact = contact
      self.isEditing = true
    } else {
      let chainType = KNGeneralProvider.shared.currentChain == .solana ? 2 : 1
      self.contact = KNContact(address: address.lowercased(), name: ens ?? "", chainType: chainType)
      self.isEditing = false
    }
    self.address = address
    self.addressString = ens ?? address
  }

  var title: String {
    return isEditing ? NSLocalizedString("edit.contact", value: "Edit Contact", comment: "") : NSLocalizedString("add.contact", value: "Add Contact", comment: "")
  }

  var displayEnsMessage: String? {
    if self.addressString.isEmpty { return nil }
    if KNGeneralProvider.shared.currentChain == .solana && self.addressString.isValidSolanaAddress() { return nil }
    if self.address == nil { return "Invalid address or your ens is not mapped yet" }
    if KNGeneralProvider.shared.isAddressValid(address: self.addressString) { return nil }
    let address = self.address?.description ?? ""
    return "\(address.prefix(12))...\(address.suffix(10))"
  }

  var displayEnsMessageColor: UIColor {
    if KNGeneralProvider.shared.currentChain == .solana && self.addressString.isValidSolanaAddress() { return UIColor.Kyber.blueGreen }
    if self.address != nil { return UIColor.Kyber.blueGreen }
    return UIColor.Kyber.strawberry
  }

  func updateViewModel(address: String) {
    self.addressString = address
    self.address = address
  }

  func updateAddressFromENS(name: String, ensAddr: String?) {
    self.addressString = name
    self.address = ensAddr
    if let contact = KNContactStorage.shared.contacts.first(where: { $0.address.lowercased() == (ensAddr?.description.lowercased() ?? "") }) {
      self.contact = contact
      self.isEditing = true
    } else if let addr = ensAddr {
      let chainType = KNGeneralProvider.shared.currentChain == .solana ? 2 : 1
      self.contact = KNContact(
        address: addr,
        name: self.contact.name.isEmpty ? name : self.contact.name,
        chainType: chainType
      )
      self.isEditing = false
    }
  }
}

class KNNewContactViewController: KNBaseViewController {

  weak var delegate: KNNewContactViewControllerDelegate?
  fileprivate var viewModel: KNNewContactViewModel

  @IBOutlet weak var headerContainerView: UIView!
  @IBOutlet weak var titleLabel: UILabel!
  @IBOutlet weak var deleteButton: UIButton!
  @IBOutlet weak var sendButton: UIButton!
  @IBOutlet weak var nameTextField: UITextField!
  @IBOutlet weak var addressTextField: UITextField!
  @IBOutlet weak var ensMessageLabel: UILabel!
  @IBOutlet weak var sendButtonTitleLabel: UILabel!
  @IBOutlet weak var deleteButtonTitleLabel: UILabel!
  @IBOutlet weak var sendButtonContainerView: UIView!
  @IBOutlet weak var deleteButtonContainerView: UIView!
  @IBOutlet weak var doneButton: UIButton!
  @IBOutlet weak var separateView: UIView!
  @IBOutlet weak var doneButtonTopContraint: NSLayoutConstraint!

  init(viewModel: KNNewContactViewModel) {
    self.viewModel = viewModel
    super.init(nibName: KNNewContactViewController.className, bundle: nil)
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    self.setupUI()
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    self.nameTextField.becomeFirstResponder()
    if viewModel.isEditing {
      MixPanelManager.track("contact_edit_open", properties: ["screenid": "contact_edit"])
    } else {
      MixPanelManager.track("contact_add_open", properties: ["screenid": "contact_add"])
    }
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    self.view.endEditing(true)
  }

  fileprivate func setupUI() {
    self.deleteButtonTitleLabel.text = NSLocalizedString("delete.contact", value: "Delete Contact", comment: "")
    self.sendButtonTitleLabel.text = NSLocalizedString("transfer", value: "Transfer", comment: "")
    self.addressTextField.delegate = self
    self.nameTextField.attributedPlaceholder = NSAttributedString(
      string: "name".toBeLocalised(),
      attributes: [
        NSAttributedString.Key.foregroundColor: UIColor.Kyber.SWTextFieldPlaceHolderColor,
        NSAttributedString.Key.font: UIFont.Kyber.latoRegular(with: 14),
      ]
    )
    self.addressTextField.attributedPlaceholder = NSAttributedString(
      string: "address".toBeLocalised(),
      attributes: [
        NSAttributedString.Key.foregroundColor: UIColor.Kyber.SWTextFieldPlaceHolderColor,
        NSAttributedString.Key.font: UIFont.Kyber.latoRegular(with: 14),
      ]
    )
    self.doneButton.rounded(radius: 16)
    self.updateUI()
  }

  fileprivate func updateUI() {
    self.titleLabel.text = self.viewModel.title
    self.nameTextField.text = self.viewModel.contact.name
    self.addressTextField.text = self.viewModel.addressString
    self.deleteButtonContainerView.isHidden = !self.viewModel.isEditing
    self.sendButtonContainerView.isHidden = !self.viewModel.isEditing
    self.separateView.isHidden = !self.viewModel.isEditing
    self.doneButtonTopContraint.constant = self.viewModel.isEditing ? 184 : 51
    self.doneButton.setTitle(self.viewModel.isEditing ? NSLocalizedString("done", value: "Done", comment: "") : NSLocalizedString("add", value: "Add", comment: ""), for: .normal)
    self.ensMessageLabel.text = self.viewModel.displayEnsMessage
    self.ensMessageLabel.textColor = self.viewModel.displayEnsMessageColor
    self.ensMessageLabel.isHidden = false
  }

  fileprivate func addressTextFieldDidChange() {
    if self.nameTextField.text == nil || self.nameTextField.text?.isEmpty == true {
      self.nameTextField.text = self.viewModel.contact.name
    }
    self.titleLabel.text = self.viewModel.title
    self.deleteButtonContainerView.isHidden = !self.viewModel.isEditing

    self.ensMessageLabel.text = self.viewModel.displayEnsMessage
    self.ensMessageLabel.textColor = self.viewModel.displayEnsMessageColor
    self.ensMessageLabel.isHidden = false
  }

  func updateView(viewModel: KNNewContactViewModel) {
    self.viewModel = viewModel
    self.updateUI()
  }

  @IBAction func backButtonPressed(_ sender: Any) {
    self.delegate?.newContactViewController(self, run: .dismiss)
  }

  @IBAction func saveButtonPressed(_ sender: Any) {
    guard let name = self.nameTextField.text, !name.isEmpty else {
      self.showWarningTopBannerMessage(with: "", message: NSLocalizedString("contact.should.have.a.name", value: "Contact should have a name", comment: ""))
      return
    }
    guard let contactAddress = self.addressTextField.text, KNGeneralProvider.shared.isAddressValid(address: contactAddress) else {
      self.showErrorTopBannerMessage(
        with: Strings.invalidAddress,
        message: Strings.pleaseEnterValidAddress,
        time: 2.0
      )
      return
    }
    
    let chainType = KNGeneralProvider.shared.currentChain == .solana ? 2 : 1
    let contact = KNContact(address: contactAddress, name: name, chainType: chainType)
    KNContactStorage.shared.update(contacts: [contact])
    KNNotificationUtil.postNotification(for: kUpdateListContactNotificationKey)
    self.delegate?.newContactViewController(self, run: .dismiss)
    self.navigationController?.showTopBannerView(message: "New contact is added")
    if !viewModel.isEditing {
      MixPanelManager.track("contact_add_add", properties: ["screenid": "contact_add"])
    } else {
      MixPanelManager.track("contact_edit_done", properties: ["screenid": "contact_edit"])
    }
  }

  @IBAction func deleteButtonPressed(_ sender: Any) {
    let alertController = KNPrettyAlertController(
            title: "",
            message: NSLocalizedString("do.you.want.to.delete.this.contact", value: "Do you want to delete this contact?", comment: ""),
            secondButtonTitle: "OK".toBeLocalised(),
            firstButtonTitle: "Cancel".toBeLocalised(),
            secondButtonAction: {
                KNContactStorage.shared.delete(contacts: [self.viewModel.contact])
                KNNotificationUtil.postNotification(for: kUpdateListContactNotificationKey)
                self.delegate?.newContactViewController(self, run: .dismiss)
            },
            firstButtonAction: nil
          )
    self.present(alertController, animated: true, completion: nil)
    if viewModel.isEditing {
      MixPanelManager.track("contact_edit_delete", properties: ["screenid": "contact_edit"])
    }
  }

  @IBAction func sendButtonPressed(_ sender: Any) {
    let address = self.addressTextField.text ?? ""
    guard KNGeneralProvider.shared.isAddressValid(address: address) else {
      self.showErrorTopBannerMessage(
        with: Strings.invalidAddress,
        message: Strings.pleaseEnterValidAddress,
        time: 2.0
      )
      return
    }
    self.delegate?.newContactViewController(self, run: .send(address: address))
    if viewModel.isEditing {
      MixPanelManager.track("contact_edit_transfer", properties: ["screenid": "contact_edit"])
    }
  }

  @IBAction func qrcodeButtonPressed(_ sender: Any) {
    if KNOpenSettingsAllowCamera.openCameraNotAllowAlertIfNeeded(baseVC: self) {
      return
    }
    let qrcodeVC = QRCodeReaderViewController()
    qrcodeVC.delegate = self
    self.present(qrcodeVC, animated: true, completion: nil)
    if !viewModel.isEditing {
      MixPanelManager.track("contact_add_scan", properties: ["screenid": "contact_add"])
    }
    
  }

  @IBAction func screenEdgePanAction(_ sender: UIScreenEdgePanGestureRecognizer) {
    if sender.state == .ended {
      self.delegate?.newContactViewController(self, run: .dismiss)
    }
  }
}

extension KNNewContactViewController: UITextFieldDelegate {
  func textFieldShouldClear(_ textField: UITextField) -> Bool {
    textField.text = ""
    if textField == self.addressTextField {
      self.viewModel.updateViewModel(address: "")
      self.addressTextFieldDidChange()
      self.getEnsAddressFromName("")
    }
    return false
  }
  func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
    let text = ((textField.text ?? "") as NSString).replacingCharacters(in: range, with: string)
    textField.text = text
    if textField == self.addressTextField {
      self.viewModel.updateViewModel(address: text)
      self.addressTextFieldDidChange()
      self.getEnsAddressFromName(text)
    }
    return false
  }
}

extension KNNewContactViewController: QRCodeReaderDelegate {
  func readerDidCancel(_ reader: QRCodeReaderViewController!) {
    reader.dismiss(animated: true, completion: nil)
  }

  func reader(_ reader: QRCodeReaderViewController!, didScanResult result: String!) {
    reader.dismiss(animated: true) {
      let address: String = {
        if result.count < 42 { return result }
        if result.starts(with: "0x") { return result }
        let string = "\(result.suffix(42))"
        if string.starts(with: "0x") { return string }
        return result
      }()
      self.addressTextField.text = address
      self.viewModel.updateViewModel(address: address)
      self.addressTextFieldDidChange()
      self.getEnsAddressFromName(address)
    }
  }

  fileprivate func getEnsAddressFromName(_ name: String) {
    if KNGeneralProvider.shared.currentChain == .solana {
      return
    }
    if KNGeneralProvider.shared.isAddressValid(address: name) { return }
    if !name.contains(".") {
      self.viewModel.updateAddressFromENS(name: name, ensAddr: nil)
      self.updateUI()
      return
    }
    DispatchQueue.main.async {
      KNGeneralProvider.shared.getAddressByEnsName(name.lowercased()) { [weak self] result in
        guard let `self` = self else { return }
        DispatchQueue.main.async {
          if name != self.viewModel.addressString { return }
          if case .success(let addr) = result, let address = addr, address != "0x0000000000000000000000000000000000000000" {
            self.viewModel.updateAddressFromENS(name: name, ensAddr: address)
          } else {
            self.viewModel.updateAddressFromENS(name: name, ensAddr: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
              self.getEnsAddressFromName(self.viewModel.addressString)
            }
          }
          self.updateUI()
        }
      }
    }
  }
}
