//
//  Overview.swift
//  KyberNetwork
//
//  Created by Ta Minh Quan on 26/07/2021.
//

import Foundation

// MARK: - OverviewResponse
struct OverviewResponse: Codable {
    let timestamp: Int
    let data: [OverviewData]
}

// MARK: - Datum
struct OverviewData: Codable {
    let address, symbol, name: String
    let decimals: Int
    let logo: String
    let quotes: [String: Quote]
}

// MARK: - Quote
struct Quote: Codable {
    let symbol: String
    let price, marketCap, volume24H, price24HChange: Double
    let price24HChangePercentage: Double

    enum CodingKeys: String, CodingKey {
        case symbol, price, marketCap
        case volume24H = "volume24h"
        case price24HChange = "price24hChange"
        case price24HChangePercentage = "price24hChangePercentage"
    }
}

// MARK: - TokenDetailResponse
struct TokenDetailResponse: Codable {
    let timestamp: Int
    let result: TokenDetailInfo
}

// MARK: - Result
struct TokenDetailInfo: Codable {
  let address, symbol, name: String
  let decimals: Int
  let logo, resultDescription: String
  let links: Links
  let markets: [String: Market]

  enum CodingKeys: String, CodingKey {
    case address, symbol, name, decimals, logo
    case resultDescription = "description"
    case links, markets
  }
}

// MARK: - Links
struct Links: Codable {
    let homepage: String
    let twitterScreenName: String
}

// MARK: - Market
struct Market: Codable {
    let symbol: String
    let price, priceChange24H, priceChange1HPercentage, priceChange24HPercentage: Double
    let priceChange7DPercentage, priceChange30DPercentage, priceChange200DPercentage, priceChange1YPercentage: Double
    let marketCap, marketCapChange24H, marketCapChange24HPercentage, volume24H: Double
    let high24H, low24H, ath, athChangePercentage: Double
    let athDate: Int
    let atl, atlChangePercentage: Double
    let atlDate: Int

    enum CodingKeys: String, CodingKey {
        case symbol, price
        case priceChange24H = "priceChange24h"
        case priceChange1HPercentage = "priceChange1hPercentage"
        case priceChange24HPercentage = "priceChange24hPercentage"
        case priceChange7DPercentage = "priceChange7dPercentage"
        case priceChange30DPercentage = "priceChange30dPercentage"
        case priceChange200DPercentage = "priceChange200dPercentage"
        case priceChange1YPercentage = "priceChange1yPercentage"
        case marketCap
        case marketCapChange24H = "marketCapChange24h"
        case marketCapChange24HPercentage = "marketCapChange24hPercentage"
        case volume24H = "volume24h"
        case high24H = "high24h"
        case low24H = "low24h"
        case ath, athChangePercentage, athDate, atl, atlChangePercentage, atlDate
    }
}

// MARK: - ChartDataResponse
struct ChartDataResponse: Codable {
    let timestamp: Int
    let prices: [[Double]]
}

// MARK: - NftResponse
struct NftResponse: Codable {
    let timestamp: Int
    let balances: [NFTSection]
}

// MARK: - Balance
struct NFTSection: Codable {
    let collectionName, collectionAddress, collectionSymbol: String
    let collectionLogo: String
    let items: [NFTItem]
}

// MARK: - Item
struct NFTItem: Codable {
    let tokenID, tokenBalance: String
    let tokenURL: String
    let externalData: ExternalData

    enum CodingKeys: String, CodingKey {
        case tokenID, tokenBalance
        case tokenURL = "tokenUrl"
        case externalData
    }
}

// MARK: - ExternalData
struct ExternalData: Codable {
    let name, externalDataDescription: String
    let image: String

    enum CodingKeys: String, CodingKey {
        case name
        case externalDataDescription = "description"
        case image
    }
}
