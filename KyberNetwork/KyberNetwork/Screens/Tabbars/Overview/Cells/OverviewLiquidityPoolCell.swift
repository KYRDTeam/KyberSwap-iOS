//
//  OverviewLiquidityPoolCell.swift
//  KyberNetwork
//
//  Created by Com1 on 04/10/2021.
//

import UIKit
import BigInt

class OverviewLiquidityPoolViewModel {
  let currency: CurrencyMode
  let pairTokens: [LPTokenModel]
  init(currency: CurrencyMode, pairToken: [LPTokenModel]) {
    self.currency = currency
    self.pairTokens = pairToken
  }

  func firstTokenSymbol() -> String {
    guard !pairTokens.isEmpty else {
      return ""
    }
    return pairTokens[0].token.symbol
  }

  func secondTokenSymbol() -> String {
    guard pairTokens.count > 1 else {
      return ""
    }
    return pairTokens[1].token.symbol
  }

  func firstTokenValue() -> String {
    guard !pairTokens.isEmpty else {
      return ""
    }
    let tokenModel = pairTokens[0]
    return tokenModel.getBalanceBigInt(self.currency).string(decimals: tokenModel.token.decimals, minFractionDigits: 0, maxFractionDigits: min(tokenModel.token.decimals, 5)) + " " + firstTokenSymbol()
  }
  
  func secondTokenValue() -> String {
    guard pairTokens.count > 1 else {
      return ""
    }
    let tokenModel = pairTokens[1]
    return tokenModel.getBalanceBigInt(self.currency).string(decimals: tokenModel.token.decimals, minFractionDigits: 0, maxFractionDigits: min(tokenModel.token.decimals, 5)) + " " + secondTokenSymbol()
  }
  
  func balanceValue() -> String {
    var total = 0.0
    for tokenModel in pairTokens {
      total += tokenModel.getTokenValue(self.currency)
    }
    let currencyFormatter = StringFormatter()
    return self.currency.symbol() + currencyFormatter.currencyString(value: total, decimals: self.currency.decimalNumber())
  }
}

class OverviewLiquidityPoolCell: UITableViewCell {
  static let kCellID: String = "OverviewLiquidityPoolCell"
  static let kCellHeight: CGFloat = 85
  @IBOutlet weak var cellBackgroundView: UIView!
  @IBOutlet weak var firstTokenIcon: UIImageView!
  @IBOutlet weak var secondTokenIcon: UIImageView!
  @IBOutlet weak var firstTokenValueLabel: UILabel!
  @IBOutlet weak var secondTokenValueLabel: UILabel!
  @IBOutlet weak var balanceLabel: UILabel!

  override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

  override func setSelected(_ selected: Bool, animated: Bool) {
      super.setSelected(selected, animated: animated)

      // Configure the view for the selected state
  }

  func updateCell(_ viewModel: OverviewLiquidityPoolViewModel) {
    self.firstTokenIcon.setSymbolImage(symbol: viewModel.firstTokenSymbol())
    self.secondTokenIcon.setSymbolImage(symbol: viewModel.secondTokenSymbol())
    self.firstTokenValueLabel.text = viewModel.firstTokenValue()
    self.secondTokenValueLabel.text = viewModel.secondTokenValue()
    self.balanceLabel.text = viewModel.balanceValue()
  }
}
