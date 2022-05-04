//
//  KrystalSolanaTransactionItemViewModel.swift
//  KyberNetwork
//
//  Created by Nguyen Tung on 22/04/2022.
//

import Foundation
import UIKit
import BigInt

class SolanaTransactionItemViewModel: TransactionHistoryItemViewModelProtocol {
  
  let transaction: SolanaTransaction
  
  init(transaction: SolanaTransaction) {
    self.transaction = transaction
  }
}

extension SolanaTransactionItemViewModel {
  
  var interactProgram: String {
    return transaction.details.inputAccount.last?.account ?? ""
  }
  
  var fromIconSymbol: String {
    return swapEvents.first?.symbol ?? ""
  }
  
  var toIconSymbol: String {
    return swapEvents.last?.symbol ?? ""
  }
  
  var txType: HistoryModelType {
    switch transaction.type {
    case .swap:
      return .swap
    case .solTransfer, .splTransfer:
      return .transferToken
    default:
      return .contractInteraction
    }
  }
  
  var displayedAmountString: String {
    switch transaction.type {
    case .swap:
      return tokenSwapAmountString
    case .splTransfer:
      return tokenTransferTxAmountString
    case .solTransfer:
      return solanaTransferTxAmountString
    default:
      return Strings.application
    }
  }
  
  var transactionDetailsString: String {
    switch transaction.type {
    case .swap:
      return swapRateString
    case .splTransfer:
      return tokenTransferInfoString
    case .solTransfer:
      return solTransferString
    default:
      return interactProgram
    }
  }
  
  var isError: Bool {
    return transaction.status.lowercased() != "success"
  }
  
  var transactionTypeImage: UIImage {
    return txType.displayIcon
  }
  
  var displayTime: String {
    return DateFormatterUtil.shared.historyTransactionDateFormatter.string(from: transaction.txDate)
  }
  
  var transactionTypeString: String {
    return txType.displayString
  }
  
  var swapEvents: [SolanaTransaction.Details.Event] {
    let unknownTransfers = transaction.details.unknownTransfers.flatMap(\.event)
    let raydiumTransactions = transaction.details.raydiumTransactions.compactMap { $0.swap }.flatMap { $0.event }
    if !unknownTransfers.isEmpty {
      return unknownTransfers
    } else {
      return raydiumTransactions
    }
  }
  
  private var solTransferString: String {
    guard !transaction.details.solTransfers.isEmpty else { return "" }
    let tx = transaction.details.solTransfers[0]
    if transaction.isTransferToOther {
      return String(format: Strings.toColonX, tx.destination)
    } else {
      return String(format: Strings.fromColonX, tx.source)
    }
  }
  
  private var tokenTransferInfoString: String {
    guard !transaction.details.tokenTransfers.isEmpty else { return "" }
    let tx = transaction.details.tokenTransfers[0]
    if transaction.isTransferToOther {
      return String(format: Strings.toColonX, tx.destinationOwner)
    } else {
      return String(format: Strings.fromColonX, tx.sourceOwner)
    }
  }
  
  private var swapRateString: String {
    guard swapEvents.count > 1 else { return "" }
    let tx0 = swapEvents.first!
    let tx1 = swapEvents.last!
    let formattedRate = formattedSwapRate(tx0: tx0, tx1: tx1)
    return "1 \(tx0.symbol) = \(formattedRate) \(tx1.symbol)"
  }
  
  private var tokenSwapAmountString: String {
    guard swapEvents.count > 1 else { return "" }
    let tx0 = swapEvents.first!
    let tx1 = swapEvents.last!
    let fromAmount = formattedAmount(amount: tx0.amount, decimals: tx0.decimals)
    let toAmount = formattedAmount(amount: tx1.amount, decimals: tx1.decimals)
    return String(format: "%@ %@ → %@ %@", fromAmount, tx0.symbol, toAmount, tx1.symbol)
  }
  
  private var tokenTransferTxAmountString: String {
    guard !transaction.details.tokenTransfers.isEmpty else { return "" }
    let tx = transaction.details.tokenTransfers[0]
    let amountString = formattedAmount(amount: tx.amount, decimals: tx.token.decimals)
    let symbol = tx.token.symbol
    return transaction.isTransferToOther ? "-\(amountString) \(symbol)": "\(amountString) \(symbol)"
  }
  
  private var solanaTransferTxAmountString: String {
    guard !transaction.details.solTransfers.isEmpty else { return "" }
    let tx = transaction.details.solTransfers[0]
    let quoteToken = KNGeneralProvider.shared.currentChain.quoteTokenObject()
    let amountString = formattedAmount(amount: tx.amount, decimals: quoteToken.decimals)
    return transaction.isTransferToOther
      ? "-\(amountString) \(quoteToken.symbol)"
      : "\(amountString) \(quoteToken.symbol)"
  }
  
  private func formattedSwapRate(tx0: SolanaTransaction.Details.Event, tx1: SolanaTransaction.Details.Event) -> String {
    let sourceAmountBigInt = BigInt(tx0.amount)
    let destAmountBigInt = BigInt(tx1.amount)
    
    let amountFrom = sourceAmountBigInt * BigInt(10).power(18) / BigInt(10).power(tx0.decimals)
    let amountTo = destAmountBigInt * BigInt(10).power(18) / BigInt(10).power(tx1.decimals)
    let rate = amountTo * BigInt(10).power(18) / amountFrom
    return rate.displayRate(decimals: 18)
  }
  
  private func formattedAmount(amount: Double, decimals: Int) -> String {
    let bigIntAmount = BigInt(amount)
    return bigIntAmount.string(decimals: decimals, minFractionDigits: 0, maxFractionDigits: 6)
  }
}