//
//  OverviewAddNFTViewController.swift
//  KyberNetwork
//
//  Created by Ta Minh Quan on 24/08/2021.
//

import UIKit
import QRCodeReaderViewController

enum AddNFTViewEvent {
  case done(address: String, id: String)
  
}

protocol OverviewAddNFTViewControllerDelegate: class {
  func addTokenViewController(_ controller: OverviewAddNFTViewController, run event: AddNFTViewEvent)
}

class OverviewAddNFTViewController: KNBaseViewController {
  @IBOutlet weak var tokenAddressField: UITextField!
  @IBOutlet weak var tokenIDField: UITextField!
  
  weak var delegate: OverviewAddNFTViewControllerDelegate?
  
  override func viewDidLoad() {
    super.viewDidLoad()
    //trick fix
    KNGeneralProvider.shared.getDecimalsEncodeData { result in
    }
  }
  
  fileprivate func openQRCode() {
    let qrcode = QRCodeReaderViewController()
    qrcode.delegate = self
    self.present(qrcode, animated: true, completion: nil)
  }
  
  @IBAction func backButtonTapped(_ sender: UIButton) {
    self.navigationController?.popViewController(animated: true)
  }
  
  @IBAction func doneButtonTapped(_ sender: UIButton) {
    guard let address = self.tokenAddressField.text, let id = self.tokenIDField.text, !address.isEmpty, !id.isEmpty else {
      self.showErrorTopBannerMessage(message: "Invaild input")
      return
    }
    self.delegate?.addTokenViewController(self, run: .done(address: address, id: id))
    MixPanelManager.track("add_nft_done", properties: ["screenid": "add_nft", "id": id, "address": address])
  }
  
  @IBAction func pasteButtonTapped(_ sender: UIButton) {
    if let string = UIPasteboard.general.string {
      self.tokenAddressField.text = string
      MixPanelManager.track("add_nft_paste_address", properties: ["screenid": "add_nft"])
    }
  }
  
  @IBAction func qrButtonTapped(_ sender: UIButton) {
    self.openQRCode()
    MixPanelManager.track("add_nft_scan", properties: ["screenid": "add_nft"])
  }
}

extension OverviewAddNFTViewController: QRCodeReaderDelegate {
  func readerDidCancel(_ reader: QRCodeReaderViewController!) {
    reader.dismiss(animated: true, completion: nil)
  }

  func reader(_ reader: QRCodeReaderViewController!, didScanResult result: String!) {
    reader.dismiss(animated: true) {
      self.tokenAddressField.text = result
    }
  }
}
