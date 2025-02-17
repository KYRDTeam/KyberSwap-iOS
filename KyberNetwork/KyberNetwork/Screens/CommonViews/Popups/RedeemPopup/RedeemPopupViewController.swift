//
//  RedeemPopupViewController.swift
//  KyberNetwork
//
//  Created by Tung Nguyen on 20/09/2022.
//

import UIKit
import Moya
import SafariServices

protocol RedeemPopupViewControllerDelegate: AnyObject {
  func onRedeemPopupClose()
  func onOpenTxHash(popup: RedeemPopupViewController, txHash: String, chainID: Int)
}

class RedeemPopupViewController: UIViewController {
  @IBOutlet weak var tokenIcon: UIImageView!
  @IBOutlet weak var tokenSymbolLabel: UILabel!
  @IBOutlet weak var chainIcon: UIImageView!
  @IBOutlet weak var messageLabel: UILabel!
  @IBOutlet weak var hashLabel: UILabel!
  @IBOutlet weak var progressView: SRCountdownTimer!
  @IBOutlet weak var titleLabel: UILabel!
  @IBOutlet weak var statusIcon: UIImageView!
  @IBOutlet weak var viewAssetsButton: UIButton!
  @IBOutlet weak var hashLinkButton: UIButton!
  
  weak var delegate: RedeemPopupViewControllerDelegate?
  
  var promoCode: PromoCode!
  var txHash: String?
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    setupViews()
    setupLoadingView()
    updateUI()
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    
    progressView.start(beginingValue: 1)
  }
  
  var status: RedeemPromotionStatus = .processing {
    didSet {
      self.updateUI()
    }
  }
  
  func setupViews() {
    tokenIcon.kf.setImage(with: URL(string: promoCode.campaign.logoURL), placeholder: UIImage(named: "promo_code_default_icon"), options: [.cacheMemoryOnly])
    chainIcon.image = ChainType.getChain(id: promoCode.campaign.chainID)?.squareIcon()
    tokenSymbolLabel.text = promoCode.reward.uppercased()
    hashLabel.text = nil
  }
  
  func setupLoadingView() {
    progressView.lineWidth = 2
    progressView.lineColor = .Kyber.buttonBg
    progressView.labelTextColor = .Kyber.buttonBg
    progressView.trailLineColor = .Kyber.buttonBg.withAlphaComponent(0.2)
    progressView.isLoadingIndicator = true
    progressView.isLabelHidden = true
  }
  
  func updateUI() {
    switch status {
    case .processing, .normal:
      statusIcon.isHidden = true
      progressView.isHidden = false
      titleLabel.text = Strings.redeeming
      messageLabel.text = Strings.redeemProcessingMessage
      viewAssetsButton.isHidden = true
      hashLinkButton.isHidden = true
    case .success:
      statusIcon.image = Images.success
      statusIcon.isHidden = false
      progressView.isHidden = true
      titleLabel.text = Strings.redeemSuccess
      messageLabel.text = Strings.redeemSuccessMessage
      viewAssetsButton.isHidden = false
      hashLinkButton.isHidden = false
    case .failure(let message):
      statusIcon.image = Images.failure
      statusIcon.isHidden = false
      progressView.isHidden = true
      titleLabel.text = Strings.redeemFailed
      messageLabel.text = message
      viewAssetsButton.isHidden = true
      hashLinkButton.isHidden = true
    }
  }
  
  func updateTxHash(hash: String?) {
    self.txHash = hash
    self.hashLinkButton.isHidden = hash?.isEmpty ?? true
    self.hashLabel.text = hash
  }
  
  @IBAction func closeWasTapped(_ sender: Any) {
    sheetViewController?.dismiss(animated: true, completion: { [weak self] in
      self?.delegate?.onRedeemPopupClose()
    })
  }
  
  @IBAction func viewAssetsWasTapped(_ sender: Any) {
    sheetViewController?.dismiss(animated: true, completion: {
      AppDelegate.shared.coordinator.tabbarController.selectedIndex = 0
    })
  }
  
  @IBAction func openTxHashWasTapped(_ sender: Any) {
    guard let hash = txHash, !hash.isEmpty else { return }
    let chainID = promoCode.campaign.chainID
    delegate?.onOpenTxHash(popup: self, txHash: hash, chainID: chainID)
  }
  
}
