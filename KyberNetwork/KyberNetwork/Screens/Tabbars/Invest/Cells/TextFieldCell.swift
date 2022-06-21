//
//  TextFieldCell.swift
//  KyberNetwork
//
//  Created by Com1 on 22/05/2022.
//

import UIKit

class TextFieldCell: UITableViewCell {
  @IBOutlet weak var textField: UITextField!
  @IBOutlet weak var inputContainView: UIView!
  @IBOutlet weak var containViewBottomConstraint: NSLayoutConstraint!
  @IBOutlet weak var errorLabel: UILabel!
  @IBOutlet weak var textFieldTrailingConstraint: NSLayoutConstraint!
  @IBOutlet weak var scanButton: UIButton!
  var textChangeBlock: ((String) -> Void)?
  var scanQRBlock: (() -> Void)?
  var isEditingAddress: Bool = false

  override func awakeFromNib() {
    super.awakeFromNib()
    self.textField.delegate = self
    self.textField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingDidEnd)
  }

  override func setSelected(_ selected: Bool, animated: Bool) {
    super.setSelected(selected, animated: animated)
  }
  
  func showErrorIfNeed(errorMsg: String?) {
    if let errorMsg = errorMsg {
      self.containViewBottomConstraint.constant = 35
      self.errorLabel.text = errorMsg
      self.errorLabel.isHidden = false
      self.inputContainView.shakeViewError()
    } else {
      self.inputContainView.layer.borderColor = UIColor.clear.cgColor
      self.inputContainView.layer.borderWidth = 1.0
      self.containViewBottomConstraint.constant = 0.0
      self.errorLabel.isHidden = true
    }
  }
  
  func updateUI() {
    if let text = self.textField.text {
      if CryptoAddressValidator.isValidAddress(text) {
        self.showErrorIfNeed(errorMsg: nil)
      } else {
        self.showErrorIfNeed(errorMsg: "Invalid Address".toBeLocalised())
      }
    }
  }
  
  @objc func textFieldDidChange(_ textField: UITextField) {
    self.scanButton.setImage(UIImage(named: "qr_code_blue_icon"), for: .normal)
    self.isEditingAddress = false
    if let textChangeBlock = self.textChangeBlock, let text = textField.text {
      self.updateUI()
      textChangeBlock(text)
    }
  }

  @IBAction func scanButtonTapped(_ sender: Any) {
    if self.isEditingAddress {
      self.textField.text = ""
      self.textFieldDidChange(self.textField)
    } else if let scanQRBlock = self.scanQRBlock {
      scanQRBlock()
    }
  }
}

extension TextFieldCell: UITextFieldDelegate {
  func textFieldDidBeginEditing(_ textField: UITextField) {
    self.scanButton.setImage(UIImage(named: "advanced_close_icon"), for: .normal)
    self.isEditingAddress = true
  }
}
