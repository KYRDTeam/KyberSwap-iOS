// Copyright SIX DAY LLC. All rights reserved.

import BigInt
import JSONRPCKit
import APIKit
import Result
import TrustKeystore

class KNBalanceCoordinator {

  fileprivate var session: KNSession!
  fileprivate var ethToken: TokenObject

  fileprivate var fetchETHBalanceTimer: Timer?
  fileprivate var isFetchingETHBalance: Bool = false
  var ethBalance: Balance = Balance(value: BigInt(0))

  fileprivate var fetchOtherTokensBalanceTimer: Timer?
  fileprivate var isFetchingOtherTokensBalance: Bool = false
  var otherTokensBalance: [String: Balance] = [:]

  var totalBalanceInUSD: BigInt {
    let balanceValue: BigInt = {
      var value = BigInt(0)
      if let ethRate = KNRateCoordinator.shared.usdRate(for: KNSupportedTokenStorage.shared.ethToken) {
        value = ethRate.rate * ethBalance.value / BigInt(EthereumUnit.ether.rawValue)
      }
      let tokens = self.session.tokenStorage.tokens
      for token in tokens {
        if let balance = otherTokensBalance[token.contract], !balance.value.isZero, let rate = KNRateCoordinator.shared.usdRate(for: token) {
          value += rate.rate * balance.value / BigInt(EthereumUnit.ether.rawValue)
        }
      }
      return value
    }()
    return balanceValue
  }

  var totalBalanceInETH: BigInt {
    let balanceValue: BigInt = {
      var value = ethBalance.value

      let tokenObjects = self.session.tokenStorage.tokens
      let ethToken = KNSupportedTokenStorage.shared.ethToken

      for tokenObj in tokenObjects {
        if let balance = otherTokensBalance[tokenObj.contract], !balance.value.isZero, let rate = KNRateCoordinator.shared.getRate(from: tokenObj, to: ethToken) {
          value += rate.rate * balance.value / BigInt(EthereumUnit.ether.rawValue)
        }
      }
      return value
    }()
    return balanceValue
  }

  deinit { self.session = nil }

  init(session: KNSession) {
    self.session = session
    self.ethToken = session.tokenStorage.ethToken
  }

  func restartNewSession(_ session: KNSession) {
    self.session = session
    self.ethToken = session.tokenStorage.ethToken
    self.ethBalance = Balance(value: BigInt(0))
    self.otherTokensBalance = [:]
    self.resume()
  }

  func resume() {
    fetchETHBalanceTimer?.invalidate()
    isFetchingETHBalance = false
    fetchETHBalance(nil)

    fetchETHBalanceTimer = Timer.scheduledTimer(
      timeInterval: KNLoadingInterval.defaultLoadingInterval,
      target: self,
      selector: #selector(self.fetchETHBalance(_:)),
      userInfo: nil,
      repeats: true
    )

    fetchOtherTokensBalanceTimer?.invalidate()
    isFetchingOtherTokensBalance = false
    fetchOtherTokensBalance(nil)

    fetchETHBalanceTimer = Timer.scheduledTimer(
      timeInterval: KNLoadingInterval.defaultLoadingInterval,
      target: self,
      selector: #selector(self.fetchOtherTokensBalance(_:)),
      userInfo: nil,
      repeats: true
    )
  }

  func pause() {
    fetchETHBalanceTimer?.invalidate()
    fetchETHBalanceTimer = nil
    isFetchingETHBalance = true

    fetchOtherTokensBalanceTimer?.invalidate()
    fetchOtherTokensBalanceTimer = nil
    isFetchingOtherTokensBalance = true
  }

  func exit() {
    pause()
  }

  @objc func fetchETHBalance(_ sender: Timer?) {
    if isFetchingETHBalance { return }
    isFetchingETHBalance = true
    self.session.externalProvider.getETHBalance { [weak self] result in
      guard let `self` = self else { return }
      self.isFetchingETHBalance = false
      switch result {
      case .success(let balance):
        self.ethBalance = balance
        if self.session != nil {
          self.session.tokenStorage.updateBalance(for: self.ethToken, balance: balance.value)
        }
        KNNotificationUtil.postNotification(for: kETHBalanceDidUpdateNotificationKey)
      case .failure(let error):
        NSLog("Load ETH Balance failed with error: \(error.description)")
      }
    }
  }

  @objc func fetchOtherTokensBalance(_ sender: Timer?) {
    if isFetchingOtherTokensBalance { return }
    isFetchingOtherTokensBalance = true
    let tokenContracts = self.session.tokenStorage.tokens.filter({ return !$0.isETH }).map({ $0.contract })
    let group = DispatchGroup()
    for contract in tokenContracts {
      if let contractAddress = Address(string: contract) {
        group.enter()
        self.session.externalProvider.getTokenBalance(for: contractAddress, completion: { [weak self] result in
          guard let `self` = self else { return }
          switch result {
          case .success(let bigInt):
            let balance = Balance(value: bigInt)
            self.otherTokensBalance[contract] = balance
            if self.session != nil {
              self.session.tokenStorage.updateBalance(for: contractAddress, balance: bigInt)
            }
          case .failure(let error):
            print("---- Balance: Fetch token balance failed with error: \(error.description). ----")
          }
          group.leave()
        })
      }
    }
    // notify when all load balances are done
    group.notify(queue: .main) {
      self.isFetchingOtherTokensBalance = false
      KNNotificationUtil.postNotification(for: kOtherBalanceDidUpdateNotificationKey)
    }
  }
}
