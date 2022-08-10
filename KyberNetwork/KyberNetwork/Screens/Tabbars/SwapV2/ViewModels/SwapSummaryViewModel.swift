//
//  SwapSummaryViewModel.swift
//  KyberNetwork
//
//  Created by Com1 on 10/08/2022.
//

import UIKit
import Moya
import BigInt

class SwapSummaryViewModel {
  var swapObject: SwapObject
  var rootViewController: SwapSummaryViewController?
  
  var rateString: Observable<String?> = .init(nil)
  var slippageString: Observable<String?> = .init(nil)
  var minReceiveString: Observable<String?> = .init(nil)
  var estimatedGasFeeString: Observable<String?> = .init(nil)
  var maxGasFeeString: Observable<String?> = .init(nil)
  var priceImpactString: Observable<String?> = .init(nil)
  
  var newRate: Rate?
  
  var showRevertedRate: Bool {
    didSet {
      self.rateString.value = self.getRateString()
    }
  }
  
  var minRatePercent: Double {
    didSet {
      self.slippageString.value = "\(String(format: "%.1f", self.minRatePercent))%"
    }
  }
  
  fileprivate var updateRateTimer: Timer?

  init(swapObject: SwapObject) {
    self.swapObject = swapObject
    self.showRevertedRate = swapObject.showRevertedRate
    self.minRatePercent = swapObject.minRatePercent
  }
  
  func updateData(controller: SwapSummaryViewController) {
    self.rootViewController = controller
    rateString.value = getRateString()
    minReceiveString.value = calculateMinReceiveString(rate: swapObject.rate)
    estimatedGasFeeString.value = calculateEstimatedGasFeeString(rate: swapObject.rate)
    priceImpactString.value = calculatePriceImpactString(rate: swapObject.rate)
    slippageString.value = "\(String(format: "%.1f", self.minRatePercent))%"
  }
  
  func updateRate() {
    if let newRate = newRate {
      swapObject.rate = newRate
      rateString.value = getRateString()
      priceImpactString.value = calculatePriceImpactString(rate: swapObject.rate)
    }
  }
  
  private func getPriceImpactState(change: Double) -> PriceImpactState {
    let absChange = abs(change)
    if 0 <= absChange && absChange < 5 {
      return .normal
    }
    if 5 <= absChange && absChange < 15 {
      return .high
    }
    return .veryHigh
  }
  
  private func calculatePriceImpactString(rate: Rate) -> String {
    if self.swapObject.refPrice == 0 {
      self.swapObject.priceImpactState = .normal
      return "0%"
    }
    let rateDouble = Double(BigInt(rate.rate) ?? .zero) / pow(10.0, 18)
    let change = (rateDouble - self.swapObject.refPrice) / self.swapObject.refPrice * 100
    self.swapObject.priceImpactState = self.getPriceImpactState(change: change)
    return "\(String(format: "%.2f", change))%"
  }
  
  private func calculateMinReceiveString(rate: Rate) -> String {
    let amount = BigInt(rate.amount) ?? BigInt(0)
    let minReceivingAmount = amount * BigInt(10000.0 - minRatePercent * 100.0) / BigInt(10000.0)
    return "\(NumberFormatUtils.amount(value: minReceivingAmount, decimals: self.swapObject.destToken.decimals)) \(self.swapObject.destToken.symbol)"
  }
  
  private func calculateEstimatedGasFeeString(rate: Rate) -> String {
    let gasFeeUSD = self.getGasFeeUSD(estGas: BigInt(rate.estimatedGas), gasPrice: self.swapObject.gasPrice)
    let gasFeeUSDString = NumberFormatUtils.gasFee(value: gasFeeUSD)
    let typeString: String = {
      switch self.swapObject.selectedGasPriceType {
      case .superFast:
        return "super.fast".toBeLocalised()
      case .fast:
        return "fast".toBeLocalised()
      case .medium:
        return "regular".toBeLocalised()
      case .slow:
        return "slow".toBeLocalised()
      case .custom:
        return "advanced".toBeLocalised()
      }
    }()
    return "$\(gasFeeUSDString) • \(typeString)"
  }
  
  private func getGasFeeUSD(estGas: BigInt, gasPrice: BigInt) -> BigInt {
    let decimals = KNGeneralProvider.shared.quoteTokenObject.decimals
    let rateUSDDouble = KNGeneralProvider.shared.quoteTokenPrice?.usd ?? 0
    let rateBigInt = BigInt(rateUSDDouble * pow(10.0, Double(decimals)))
    let feeUSD = (estGas * gasPrice * rateBigInt) / BigInt(10).power(decimals)
    return feeUSD
  }
  
  func startUpdateRate() {
    self.updateRateTimer?.invalidate()
    self.fetchRate()
    self.updateRateTimer = Timer.scheduledTimer(
      withTimeInterval: KNLoadingInterval.seconds15,
      repeats: true,
      block: { [weak self] _ in
        guard let `self` = self else { return }
        self.fetchRate()
      }
    )
  }
  
  private func getRateString() -> String? {
    let destToken = swapObject.destToken
    let sourceToken = swapObject.sourceToken
    let selectedPlatform = swapObject.rate
    if showRevertedRate {
      let rate = BigInt(selectedPlatform.rate) ?? .zero
      let revertedRate = rate.isZero ? 0 : (BigInt(10).power(36) / rate)
      let rateString = NumberFormatUtils.rate(value: revertedRate, decimals: 18)
      return "1 \(destToken.symbol) = \(rateString) \(sourceToken.symbol)"
    } else {
      let rateString = NumberFormatUtils.rate(value: BigInt(selectedPlatform.rate) ?? .zero, decimals: 18)
      return "1 \(sourceToken.symbol) = \(rateString) \(destToken.symbol)"
    }
  }
  
  
  func fetchRate() {
    let provider = MoyaProvider<KrytalService>(plugins: [NetworkLoggerPlugin(verbose: true)])
    provider.requestWithFilter(.getExpectedRate(src: self.swapObject.sourceToken.address.lowercased(), dst: self.swapObject.destToken.address.lowercased(), srcAmount: self.swapObject.sourceAmount.description, hint: self.swapObject.rate.hint, isCaching: true)) { [weak self] result in
      guard let `self` = self else { return }
      if case .success(let resp) = result, let json = try? resp.mapJSON() as? JSONDictionary ?? [:], let rate = json["rate"] as? String, let priceImpact = json["priceImpact"] as? Int {
//        if self.swapObject.rate.rate != rate {
        self.rootViewController?.rateUpdated(newRate: rate, priceImpact: priceImpact)
//        }
      } else {
        // do nothing in background
      }
    }
  }
}
