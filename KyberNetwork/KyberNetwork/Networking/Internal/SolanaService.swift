//
//  SolanaService.swift
//  KyberNetwork
//
//  Created by Com1 on 20/04/2022.
//

import Foundation
import Moya

enum SolanaService {
  case getRecentBlockhash
  case getMinimumBalanceForRentExemption
  case sendTransaction(signedTransaction: String)
  case getSignatureStatuses(signature: String)
  case getTokenAccountsByOwner(ownerAddress: String, tokenAddress: String)
}

extension SolanaService: TargetType {
  var baseURL: URL {
//    return URL(string: "https://api.mainnet-beta.solana.com")!
    return URL(string: "https://solana-api.projectserum.com")!
  }
  
  var path: String {
    return ""
  }

  var method: Moya.Method {
    return .post
  }

  var sampleData: Data {
    return Data()
  }
  
  var task: Task {
    switch self {
    case .getRecentBlockhash:
      let json: JSONDictionary = [
        "jsonrpc": "2.0",
        "id": 1,
        "method": self.methodName()
      ]
      return .requestParameters(parameters: json, encoding: JSONEncoding.default)
    case .getMinimumBalanceForRentExemption:
      let json: JSONDictionary = [
        "jsonrpc": "2.0",
        "id": 1,
        "params":[50],
        "method": self.methodName()
      ]
      return .requestParameters(parameters: json, encoding: JSONEncoding.default)
    case .sendTransaction(let signedTransactionString):
      let json: JSONDictionary = [
        "jsonrpc": "2.0",
        "id": 1,
        "method": self.methodName(),
        "params": [signedTransactionString]
      ]
      return .requestParameters(parameters: json, encoding: JSONEncoding.default)
    case .getSignatureStatuses(let signature):
      let json: JSONDictionary = [
        "jsonrpc": "2.0",
        "id": 1,
        "method": self.methodName(),
        "params": [[signature]]
      ]
      return .requestParameters(parameters: json, encoding: JSONEncoding.default)
    case .getTokenAccountsByOwner(let ownerAddress, let tokenAddress):
      let json: JSONDictionary = [
        "jsonrpc": "2.0",
        "id": 1,
        "method": self.methodName(),
        "params": [ownerAddress , ["mint" : tokenAddress], ["encoding" : "jsonParsed"]]
      ]
      return .requestParameters(parameters: json, encoding: JSONEncoding.default)
    }
  }

  var headers: [String : String]? {
    return ["Content-Type": "application/json"]
  }

  func methodName() -> String {
    switch self {
    case .getRecentBlockhash:
      return "getRecentBlockhash"
    case .getMinimumBalanceForRentExemption:
      return "getMinimumBalanceForRentExemption"
    case .sendTransaction:
      return "sendTransaction"
    case .getSignatureStatuses:
      return "getSignatureStatuses"
    case .getTokenAccountsByOwner:
      return "getTokenAccountsByOwner"
    }
  }
}