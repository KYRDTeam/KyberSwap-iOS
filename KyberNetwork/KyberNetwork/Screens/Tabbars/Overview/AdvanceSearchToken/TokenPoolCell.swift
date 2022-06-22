//
//  TokenPoolCell.swift
//  KyberNetwork
//
//  Created by Com1 on 20/06/2022.
//

import UIKit

class TokenPoolCell: UITableViewCell {

  @IBOutlet weak var token0Icon: UIImageView!
  @IBOutlet weak var token1Icon: UIImageView!
  @IBOutlet weak var pairNameLabel: UILabel!
  @IBOutlet weak var fullNameLabel: UILabel!
  @IBOutlet weak var valueLabel: UILabel!
  @IBOutlet weak var chainIcon: UIImageView!
  @IBOutlet weak var addressLabel: UILabel!
  @IBOutlet weak var totalValueLabel: UILabel!

  @IBOutlet weak var pairNameLabelWidth: NSLayoutConstraint!
  @IBOutlet weak var valueLabelWidth: NSLayoutConstraint!
  
  
  
  override func awakeFromNib() {
    super.awakeFromNib()
    // Initialization code
  }

  override func setSelected(_ selected: Bool, animated: Bool) {
    super.setSelected(selected, animated: animated)
  }
    
  func updateUI(poolDetail: TokenPoolDetail, baseTokenSymbol: String) {
    var baseToken = poolDetail.token0
    var otherToken = poolDetail.token1
    
    if poolDetail.token1.symbol == baseTokenSymbol {
      baseToken = poolDetail.token1
      otherToken = poolDetail.token0
    }

    if let url = URL(string: baseToken.logo) {
      token0Icon.setImage(with: url, placeholder: nil)
    }
    if let url = URL(string: otherToken.logo) {
      token1Icon.setImage(with: url, placeholder: nil)
    }

    self.pairNameLabel.text = "\(baseToken.symbol)/\(otherToken.symbol)"
    self.pairNameLabelWidth.constant = "\(baseToken.symbol)/\(otherToken.symbol)".width(withConstrainedHeight: 21, font: UIFont.Kyber.regular(with: 18))
    self.fullNameLabel.text = poolDetail.name
    self.valueLabel.text = "\(baseToken.usdValue)"
    self.valueLabelWidth.constant = "\(baseToken.usdValue)".width(withConstrainedHeight: 21, font: UIFont.Kyber.regular(with: 16))
    self.chainIcon.image = ChainType.make(chainID: poolDetail.chainId)?.chainIcon()
    self.addressLabel.text = "\(poolDetail.address.prefix(7))...\(poolDetail.address.suffix(4))"
    self.totalValueLabel.text = StringFormatter.usdString(value: poolDetail.tvl)
  }
}