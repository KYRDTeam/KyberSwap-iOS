//
//  SolanaTransaction.swift
//  KyberNetwork
//
//  Created by Nguyen Tung on 25/04/2022.
//

import Foundation

struct SolanaTransaction {
  var userAddress: String
  var blockTime: Int
  var slot: Int
  var txHash: String
  var fee: Int
  var status: String
  var lamport: Int
  var signer: [String]
  var details: Details
  var parsedInstruction: [Instruction]
  
  struct Details {
    var recentBlockhash: String
    var solTransfers: [SolTransferTx]
    var tokenTransfers: [TokenTransferTx]
    var unknownTransfers: [UnknownTransferTx]
    var raydiumTransactions: [RaydiumTx]
    var inputAccount: [InputAccount]
    
    struct InputAccount {
      var account: String
      var signer: Bool
      var writable: Bool
      var preBalance: Int
      var postBalance: Int
    }
    
    struct SolTransferTx {
      var source: String
      var destination: String
      var amount: Double
    }
    
    struct TokenTransferTx {
      var amount: Double
      var destination: String
      var destinationOwner: String
      var source: String
      var sourceOwner: String
      var token: Token
      var type: String?

      struct Token {
        var address: String
        var decimals: Int
        var icon: String
        var symbol: String
      }
    }
    
    struct UnknownTransferTx {
      var event: [Event]
      var programId: String
    }
    
    struct RaydiumTx {
      var swap: Swap?
      
      struct Swap {
        var event: [Event]
        
        struct Coin {
          var amount: Double
          var decimals: Int
          var symbol: String
          var tokenAddress: String
        }
      }
    }
    
    struct Event {
      var amount: Double
      var decimals: Int
      var destination: String?
      var destinationOwner: String?
      var icon: String?
      var source: String?
      var sourceOwner: String?
      var symbol: String
      var tokenAddress: String?
      var type: String
    }
  }
  
  struct Instruction {
    var programId: String
    var type: String
  }
  
  enum SolanaTransactionType {
    case swap
    case solTransfer
    case splTransfer
    case unknownTransfer
    case other
  }
  
  var type: SolanaTransactionType {
    if swapEvents.count >= 2 {
      return .swap
    } else if !details.tokenTransfers.isEmpty {
      return .splTransfer
    } else if !details.solTransfers.isEmpty {
      return .solTransfer
    } else if !details.unknownTransfers.isEmpty {
      return .unknownTransfer
    } else {
      return .other
    }
  }
  
  var swapEvents: [Details.Event] {
    let unknownTransfers = details.unknownTransfers.flatMap(\.event)
    let raydiumTransactions = details.raydiumTransactions.compactMap { $0.swap }.flatMap { $0.event }
    if !unknownTransfers.isEmpty {
      return unknownTransfers
    } else {
      return raydiumTransactions
    }
  }
  
  var isTransferToOther: Bool {
    switch type {
    case .swap:
      return false
    case .splTransfer:
      return details.tokenTransfers.first?.sourceOwner == userAddress
    case .solTransfer:
      return details.solTransfers.first?.source == userAddress
    case .unknownTransfer:
      return details.unknownTransfers.first?.event.first?.source == userAddress
    default:
      return false
    }
  }
  
}
