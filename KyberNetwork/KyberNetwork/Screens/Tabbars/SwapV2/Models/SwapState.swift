//
//  SwapState.swift
//  KyberNetwork
//
//  Created by Tung Nguyen on 09/08/2022.
//

import Foundation
import BigInt

enum SwapState {
  case emptyAmount
  case fetchingRates
  case refreshingRates
  case rateNotFound
  case notConnected
  case insufficientBalance
  case checkingAllowance
  case notApproved(currentAllowance: BigInt)
  case approving
  case requiredExpertMode
  case ready
  
  var isActiveState: Bool {
    switch self {
    case .emptyAmount:
      return false
    default:
      return true
    }
  }
}
