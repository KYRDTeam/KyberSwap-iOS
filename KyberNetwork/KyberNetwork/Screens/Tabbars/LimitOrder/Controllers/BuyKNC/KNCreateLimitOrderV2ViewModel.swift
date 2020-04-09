// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import BigInt

class KNCreateLimitOrderV2ViewModel {
  fileprivate(set) var wallet: Wallet
  fileprivate(set) var walletObject: KNWalletObject
  fileprivate(set) var market: KNMarket?
  fileprivate(set) var balances: [String: Balance] = [:]
  fileprivate(set) var balance: Balance?
  var isUseAllBalance: Bool = false
  let supportedTokens: [TokenObject] = KNSupportedTokenStorage.shared.supportedTokens
  fileprivate(set) var from: TokenObject
  fileprivate(set) var to: TokenObject
  let eth = KNSupportedTokenStorage.shared.ethToken
  let knc = KNSupportedTokenStorage.shared.kncToken
  let weth = KNSupportedTokenStorage.shared.wethToken
  fileprivate(set) var pendingBalances: JSONDictionary = [:]
  fileprivate(set) var targetPrice: String = ""
  fileprivate(set) var amountFrom: String = ""
  fileprivate(set) var amountTo: String = ""
  var feePercentage: Double = 0 // example: 0.005 -> 0.5%
  var discountPercentage: Double = 0 // example: 40 -> 40%
  var feeBeforeDiscount: Double = 0 // same as fee percentage
  var transferFeePercent: Double = 0
  let isBuy: Bool

  init(wallet: Wallet, isBuy: Bool = true) {
    self.isBuy = isBuy
    self.wallet = wallet
    let addr = wallet.address.description
    self.walletObject = KNWalletStorage.shared.get(forPrimaryKey: addr) ?? KNWalletObject(address: addr)
    if isBuy {
      self.from = KNSupportedTokenStorage.shared.wethToken ?? KNSupportedTokenStorage.shared.ethToken
      self.to = KNSupportedTokenStorage.shared.kncToken
    } else {
      self.to = KNSupportedTokenStorage.shared.wethToken ?? KNSupportedTokenStorage.shared.ethToken
      self.from = KNSupportedTokenStorage.shared.kncToken
    }
  }

  var walletNameString: String {
    let addr = self.walletObject.address.lowercased()
    return "|  \(addr.prefix(10))...\(addr.suffix(8))"
  }

  var targetPriceFromMarket: String {
    let formatter = NumberFormatterUtil.shared.limitOrderFormatter
    let marketPrice = self.isBuy ? self.market?.buyPrice : self.market?.sellPrice
    return formatter.string(from: NSNumber(value: marketPrice ?? 0)) ?? ""
  }

  func updateMarket(name: String = "ETH_KNC") {
    self.market = KNRateCoordinator.shared.getMarketWith(name: name)
    // TODO: Update from and to
  }

  func updateBalance(_ balances: [String: Balance]) {
    balances.forEach { (key, value) in
      self.balances[key] = value
    }
    if let bal = balances[self.from.contract] {
      if let oldBal = self.balance, oldBal.value != bal.value {
        self.isUseAllBalance = false
      }
      self.balance = bal
    }
  }

  func updateTargetPrice(_ price: String) {
    self.targetPrice = price
  }

  var availableBalance: BigInt {
    let balance: BigInt = {
      if self.from.isWETH {
        let wethBalance = self.balance?.value ?? BigInt(0)
        let ethBalance = self.balances[self.eth.contract]?.value ?? BigInt(0)
        return wethBalance + ethBalance
      }
      return self.balance?.value ?? BigInt(0)
    }()
    var availableAmount = balance
    if let pendingAmount = self.pendingBalances[self.from.symbol] as? Double {
      availableAmount -= BigInt(pendingAmount * pow(10.0, Double(self.from.decimals)))
    }
    availableAmount = max(availableAmount, BigInt(0))
    return availableAmount
  }

  var balanceText: String {
    let bal: BigInt = self.availableBalance
    let string = bal.string(
      decimals: self.from.decimals,
      minFractionDigits: 0,
      maxFractionDigits: min(self.from.decimals, 6)
    )
    if let double = Double(string), double == 0 { return "0" }
    return "\(string.prefix(12))"
  }

  var percentageRateDiff: Double {
    guard let marketPrice = self.market?.buyPrice else { return 0.0 }
    let currentPrice = self.targetPrice.doubleValue
    return (currentPrice - marketPrice) / marketPrice * 100.0
  }

  var differentRatePercentageDisplay: String? {
    let change = self.percentageRateDiff
    let display = NumberFormatterUtil.shared.displayPercentage(from: fabs(change))
    return "\(display)%"
  }

  var displayRateCompareAttributedString: NSAttributedString {
    let attributedString = NSMutableAttributedString()
    let rateChange = self.percentageRateDiff
    if fabs(rateChange) < 0.1 { return attributedString }
    guard let rate = self.differentRatePercentageDisplay else { return attributedString }
    let normalAttributes: [NSAttributedStringKey: Any] = [
      NSAttributedStringKey.font: UIFont.Kyber.medium(with: 12),
      NSAttributedStringKey.foregroundColor: UIColor(red: 90, green: 94, blue: 103),
    ]
    let higherAttributes: [NSAttributedStringKey: Any] = [
      NSAttributedStringKey.font: UIFont.Kyber.semiBold(with: 12),
      NSAttributedStringKey.foregroundColor: UIColor.Kyber.shamrock,
    ]
    let lowerAttributes: [NSAttributedStringKey: Any] = [
      NSAttributedStringKey.font: UIFont.Kyber.semiBold(with: 12),
      NSAttributedStringKey.foregroundColor: UIColor.Kyber.strawberry,
    ]
    attributedString.append(NSAttributedString(string: "Your target rate is".toBeLocalised(), attributes: normalAttributes))
    if rateChange > 0 {
      attributedString.append(NSAttributedString(string: " \(rate) ", attributes: higherAttributes))
      attributedString.append(NSAttributedString(string: "higher than current Market rate".toBeLocalised(), attributes: normalAttributes))
    } else {
      attributedString.append(NSAttributedString(string: " \(rate) ", attributes: lowerAttributes))
      attributedString.append(NSAttributedString(string: "lower than current rate".toBeLocalised(), attributes: normalAttributes))
    }
    return attributedString
  }

  func updateAmountFrom(_ amount: String) {
    self.amountFrom = amount
    let toDouble = self.isBuy ? amount.doubleValue / self.targetPrice.doubleValue : amount.doubleValue * self.targetPrice.doubleValue
    if toDouble > 0 {
      let formatter = NumberFormatterUtil.shared.limitOrderFormatter
      self.amountTo = formatter.string(from: NSNumber(value: toDouble)) ?? ""
    }
  }

  func updateAmountTo(_ amount: String) {
    self.amountTo = amount
    let fromDouble = self.isBuy ? amount.doubleValue * self.targetPrice.doubleValue : amount.doubleValue / self.targetPrice.doubleValue
    if fromDouble > 0 {
      let formatter = NumberFormatterUtil.shared.limitOrderFormatter
      self.amountFrom = formatter.string(from: NSNumber(value: fromDouble)) ?? ""
    }
  }

  var isShowingDiscount: Bool {
    let discountVal = self.totalAmountDouble * self.feeBeforeDiscount * (self.discountPercentage / 100.0)
    return discountVal >= 0.000001
  }

  var fromSymbol: String {
    return self.from.isETH || self.from.isWETH ? "ETH*" : self.from.symbol
  }

  var toSymBol: String {
    return self.to.isETH || self.to.isWETH ? "ETH*" : self.to.symbol
  }

  lazy var feeNoteHighlightedAttributes: [NSAttributedStringKey: Any] = {
    return [
      NSAttributedStringKey.font: UIFont.Kyber.semiBold(with: 14),
      NSAttributedStringKey.foregroundColor: UIColor(red: 90, green: 94, blue: 103),
    ]
  }()

  lazy var feeNoteNormalAttributes: [NSAttributedStringKey: Any] = {
    return [
      NSAttributedStringKey.font: UIFont.Kyber.medium(with: 12),
      NSAttributedStringKey.foregroundColor: UIColor(red: 90, green: 94, blue: 103),
      NSAttributedStringKey.strikethroughStyle: NSUnderlineStyle.styleSingle.rawValue,
    ]
  }()

  var displayFeeString: String {
    let feeDouble = self.totalAmountDouble * (self.feePercentage + transferFeePercent)
    let feeDisplay = NumberFormatterUtil.shared.displayLimitOrderValue(from: feeDouble)
    let fromSymbol = self.fromSymbol
    let string = "\(feeDisplay.prefix(12)) \(fromSymbol)"
    if self.isShowingDiscount || self.totalAmountDouble == 0.0 { return string }
    let percentage = NumberFormatterUtil.shared.displayPercentage(from: (self.feePercentage + self.transferFeePercent) * 100.0)
    return "\(string) (\(percentage)%)"
  }

  var displayFeeBeforeDiscountString: String {
    let feeDouble = self.totalAmountDouble * (self.feePercentage + transferFeePercent)
    let feeDisplay = NumberFormatterUtil.shared.displayLimitOrderValue(from: feeDouble)
    let fromSymbol = self.fromSymbol
    return "\(feeDisplay.prefix(12)) \(fromSymbol)"
  }

  var beforeDiscountAttributeString: NSAttributedString {
    let attributedString = NSMutableAttributedString()
    attributedString.append(NSAttributedString(string: self.displayFeeBeforeDiscountString, attributes: self.feeNoteNormalAttributes))
    return attributedString
  }

  var displayDiscountPercentageString: String {
    let discount = NumberFormatterUtil.shared.displayPercentage(from: self.discountPercentage)
    return "\(discount)% OFF"
  }

  var amountFromBigInt: BigInt {
    return EtherNumberFormatter.full.number(from: self.amountFrom.removeGroupSeparator(), decimals: self.from.decimals) ?? BigInt(0)
  }

  var targetPriceBigInt: BigInt {
    if isBuy {
      // reverse of sell
      if self.targetPrice.doubleValue == 0.0 { return BigInt(0) }
      return BigInt(pow(10.0, Double(self.from.decimals)) / self.targetPrice.doubleValue)
    }

    return self.targetPrice.removeGroupSeparator().amountBigInt(decimals: self.to.decimals) ?? BigInt(0)
  }

  var estimateAmountToBigInt: BigInt {
    let rate = self.targetPriceBigInt
    if rate.isZero { return BigInt(0) }
    return self.amountFromBigInt * rate / BigInt(10).power(self.from.decimals)
  }

  var amountToBigInt: BigInt {
    return self.amountTo.removeGroupSeparator().amountBigInt(decimals: self.to.decimals) ?? BigInt(0)
  }

  var amountToDouble: Double {
    return self.amountTo.doubleValue
  }

  var totalCostString: String {
    let cost = amountFrom.doubleValue * targetPrice.doubleValue
    return "\(cost) \(self.fromSymbol)"
  }

  func amountFromWithPercentage(_ percentage: Int) -> BigInt {
    let amount = self.availableBalance * BigInt(percentage) / BigInt(100)
    if !(self.from.isETH || self.from.isWETH) { return amount }
    let fee: BigInt = {
      if let bal = self.balances[self.eth.contract]?.value, !bal.isZero {
        return KNGasCoordinator.shared.fastKNGas * BigInt(600_000) // approve + convet if needed
      }
      return BigInt(0)
    }()
    return min(amount, max(0, self.availableBalance - fee))
  }

  var allFromTokenBalanceString: String {
    if !(self.from.isETH || self.from.isWETH) { return self.balanceText.removeGroupSeparator() }
    let fee: BigInt = {
      if let bal = self.balances[self.eth.contract]?.value, !bal.isZero {
        return KNGasCoordinator.shared.fastKNGas * BigInt(600_000) // approve + convet if needed
      }
      return BigInt(0)
    }()
    let bal: BigInt = max(BigInt(0), self.availableBalance - fee)
    let string = bal.string(
      decimals: self.from.decimals,
      minFractionDigits: 0,
      maxFractionDigits: min(self.from.decimals, 6)
    ).removeGroupSeparator()
    if let value = Double(string), value == 0 { return "0" }
    return "\(string.prefix(12))"
  }

  var totalAmountDouble: Double {
    return self.amountTo.doubleValue * self.targetPrice.doubleValue
  }

  var totalAmountString: String {
    let formatter = NumberFormatterUtil.shared.limitOrderFormatter
    return formatter.string(from: NSNumber(value: self.totalAmountDouble)) ?? ""
  }

  var isBalanceEnough: Bool {
    if self.amountFromBigInt > self.availableBalance { return false }
    return true
  }

  var isAmountTooBig: Bool {
    return !self.isBalanceEnough
  }

  var equivalentETHAmount: BigInt {
    if self.amountFromBigInt <= BigInt(0) { return BigInt(0) }
    if self.from.isETH || self.from.isWETH {
      return self.amountFromBigInt
    }
    if self.to.isETH || self.to.isWETH {
      return self.amountToBigInt
    }
    let ethRate: BigInt = {
      let cacheRate = KNTrackerRateStorage.shared.trackerRate(for: self.from)
      return BigInt((cacheRate?.rateETHNow ?? 0.0) * pow(10.0, 18.0))
    }()
    let valueInETH = ethRate * self.amountFromBigInt / BigInt(10).power(self.from.decimals)
    return valueInETH
  }

  var isAmountTooSmall: Bool {
    let amount: Double = {
      if KNEnvironment.default == .production { return 0.1 }
      return 0.001
    }()
    let minValueInETH = BigInt(amount * Double(EthereumUnit.ether.rawValue))
    return minValueInETH > self.equivalentETHAmount
  }

  var isRateTooSmall: Bool {
    return self.targetPrice.doubleValue == 0.0
  }

  var isRateTooBig: Bool {
    let marketPrice = self.targetPriceFromMarket.doubleValue
    return self.targetPrice.doubleValue > 10 * marketPrice
  }
}
