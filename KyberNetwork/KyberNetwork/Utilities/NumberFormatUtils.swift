//
//  NumberFormatUtils.swift
//  KyberNetwork
//
//  Created by Tung Nguyen on 08/08/2022.
//

import Foundation
import BigInt

class NumberFormatUtils {
  
  static let withSeparator: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.locale = .init(identifier: "en_US")
    return formatter
  }()
  
  static func rate(value: BigInt, decimals: Int) -> String {
    return format(value: value, decimals: decimals, maxDecimalMeaningDigits: 4, maxDecimalDigits: 4)
  }
  
  static func gasFee(value: BigInt) -> String {
    if String(value).count > 18 {
      return format(value: value, decimals: 18, maxDecimalMeaningDigits: 2, maxDecimalDigits: 2)
    } else {
      return format(value: value, decimals: 18, maxDecimalMeaningDigits: 4, maxDecimalDigits: 8)
    }
  }
  
  static func amount(value: BigInt, decimals: Int) -> String {
    return format(value: value, decimals: decimals, maxDecimalMeaningDigits: 6, maxDecimalDigits: 6)
  }
  
  static func format(value: BigInt, decimals: Int, maxDecimalMeaningDigits: Int, maxDecimalDigits: Int) -> String {
    if value.isZero {
      return "0"
    }
    
    var stringValue = String(value)
    
    // Fill zeros to leading
    let maxTotalDigits = decimals + 1 // For 0 before .
    let missingDigits = maxTotalDigits - stringValue.count
    if missingDigits > 0 {
      let prefixZeros = [String](repeating: "0", count: missingDigits).joined()
      stringValue = prefixZeros + stringValue
    }
    let suffix = stringValue.suffix(decimals)
    stringValue = stringValue.dropLast(decimals) + "." + suffix
    
    let components = stringValue.components(separatedBy: ".")
    
    if components.count > 1 {
      let beforeDot = components.first!
      let afterDot = components.last!
      var totalLeadingZeros = 0
      
      for char in afterDot {
        if char != "0" {
          break
        } else {
          totalLeadingZeros += 1
        }
      }
      
      let decimalPart = afterDot.prefix(totalLeadingZeros + maxDecimalMeaningDigits).prefix(maxDecimalDigits)
      let integerPath = withSeparator.string(from: (Int(beforeDot) ?? 0) as NSNumber) ?? "0"
      stringValue = integerPath + "." + decimalPart
    }
    
    // Remove leading zeros
    while stringValue.first == "0" {
      stringValue.removeFirst()
    }
    if stringValue.first == "." {
      stringValue = "0" + stringValue
    }
    
    // Remove trailing zeros
    while stringValue.last == "0" {
      stringValue.removeLast()
    }
    if stringValue.last == "." {
      stringValue.removeLast()
    }
    
    return stringValue
  }
  
}