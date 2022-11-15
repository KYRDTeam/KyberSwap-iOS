//
//  PortfolioStaking.swift
//  KyberNetwork
//
//  Created by Ta Minh Quan on 13/10/2022.
//

import Foundation

// MARK: - PendingUnstakesResponse
public struct PendingUnstakesResponse: Codable {
  public let pendingUnstakes: [PendingUnstake]
}

// MARK: - PendingUnstake
public struct PendingUnstake: Codable {
  public let chainID: Int
  public let address, symbol: String
  public let logo: String
  public let balance: String
  public let decimals: Int
  public let platform: Platform
  public let extraData: StakingExtraData
  public let priceUsd: Double

    enum CodingKeys: String, CodingKey {
        case chainID = "chainId"
        case address, symbol, logo, balance, decimals, platform, extraData, priceUsd
    }
}

// MARK: - ExtraData
public struct StakingExtraData: Codable {
  public let status, nftID: String?

    enum CodingKeys: String, CodingKey {
        case status
        case nftID = "nftId"
    }
}

// MARK: - Platform
public struct Platform: Codable {
  public let name: String
  public let logo: String
  public let type, desc: String
}

// MARK: - EarningBalancesResponse
public struct EarningBalancesResponse: Codable {
  public let earningBalances: [EarningBalance]
}

// MARK: - EarningBalance
public struct EarningBalance: Codable {
  public let chainID: Int
  public let platform: Platform
  public let stakingToken, toUnderlyingToken: IngToken
  public let underlyingUsd, apy, ratio: Double

    enum CodingKeys: String, CodingKey {
        case chainID = "chainId"
        case platform, stakingToken, toUnderlyingToken, underlyingUsd, apy, ratio
    }
}

// MARK: - IngToken
public struct IngToken: Codable {
  public let address, symbol: String
  public let logo: String
  public let balance: String
  public let decimals: Int
}

// MARK: - OptionDetailResponse
public struct OptionDetailResponse: Codable {
    public let earningTokens: [EarningToken]
    public var validation: EarnOptionValidation?
}
// MARK: - EarningToken
public struct EarningToken: Codable {
  public let addressStr, address, symbol, name: String
  public let decimals: Int
  public let logo: String
  public let tag: String
  public let exchangeRate: Double
  public let desc: String
}

public struct EarnOptionValidation: Codable {
    public var minStakeAmount: Double?
    public var maxStakeAmount: Double?
    public var minUnstakeAmount: Double?
    public var stakeInterval: Double?
}
