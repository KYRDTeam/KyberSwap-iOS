//
//  EarnEndpoint.swift
//  Services
//
//  Created by Com1 on 27/10/2022.
//

import Foundation
import Moya
import Utilities

enum EarnEndpoint {
  case listOption(chainId: String?)
  case getEarningBalances(address: String)
  case getPendingUnstakes(address: String)
}

extension EarnEndpoint: TargetType {
  var baseURL: URL {
    return URL(string: ServiceConfig.baseAPIURL + "/all")!
  }
  
  var path: String {
    switch self {
    case .listOption:
      return "v1/earning/options"
    case .getEarningBalances:
      return "/v1/earning/earningBalances"
    case .getPendingUnstakes:
      return "/v1/earning/pendingUnstakes"
    }
  }
  
  var method: Moya.Method {
    return .get
  }
  
  var sampleData: Data {
    return Data()
  }
  
  var task: Moya.Task {
    switch self {
    case .listOption(let chainId):
      var json: JSONDictionary = [:]
      if let chainId = chainId {
        json["chainID"] = chainId
      }
      return json.isEmpty ? .requestPlain : .requestParameters(parameters: json, encoding: URLEncoding.queryString)
    case .getEarningBalances(address: let address):
      var json: JSONDictionary = [
        "address": address
      ]
      return .requestParameters(parameters: json, encoding: URLEncoding.queryString)
    case .getPendingUnstakes(address: let address):
      var json: JSONDictionary = [
        "address": address
      ]
      return .requestParameters(parameters: json, encoding: URLEncoding.queryString)
    }
  }
  
  var headers: [String : String]? {
    var json: [String: String] = ["client": "com.kyrd.krystal.ios"]
    return json
  }
}
