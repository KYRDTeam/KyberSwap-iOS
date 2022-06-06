//
//  BridgeViewModel.swift
//  KyberNetwork
//
//  Created by Com1 on 20/05/2022.
//

import UIKit
import BigInt

enum FromSectionRows: CaseIterable {
  case selectChainRow
  case poolInfoRow
  case selectTokenRow
  
  static func sectionRows(showPoolInfo: Bool) -> [FromSectionRows] {
    var allRows = FromSectionRows.allCases
    if !showPoolInfo {
      allRows = allRows.filter { $0 != .poolInfoRow }
    }
    return allRows
  }
}

enum ToSectionRows: CaseIterable {
  case selectChainRow
  case poolInfoRow
  case selectTokenRow
  case sendToRow
  case addressRow
  case reminderRow
  case errorRow
  case swapRow
  
  static func sectionRows(showPoolInfo: Bool, showSendAddress: Bool, showReminder: Bool, showError: Bool) -> [ToSectionRows] {
    var allRows = ToSectionRows.allCases
    if !showPoolInfo {
      allRows = allRows.filter { $0 != .poolInfoRow }
    }
    if !showSendAddress {
      allRows = allRows.filter { $0 != .addressRow }
    }
    if !showReminder {
      allRows = allRows.filter { $0 != .reminderRow }
    }
    if !showError {
      allRows = allRows.filter { $0 != .errorRow }
    }
    return allRows
  }
}
class BridgeViewModel {
  fileprivate(set) var wallet: Wallet
  var showFromPoolInfo: Bool = false
  var showToPoolInfo: Bool = false
  var showSendAddress: Bool = false
  var showReminder: Bool = false
  var showError: Bool = false
  var isNeedApprove: Bool = false
  var remainApprovedAmount: (TokenObject, BigInt)?
  
  var selectSourceChainBlock: (() -> Void)?
  var selectMaxBlock: (() -> Void)?
  var selectSourceTokenBlock: (() -> Void)?
  var selectDestChainBlock: (() -> Void)?
  var selectDestTokenBlock: (() -> Void)?
  var selectSenToBlock: (() -> Void)?
  var changeAmountBlock: ((String) -> Void)?
  var changeAddressBlock: ((String) -> Void)?
  var swapBlock: (() -> Void)?
  
  var currentSourceChain: ChainType? = KNGeneralProvider.shared.currentChain
  var currentSourceToken: TokenObject?
  var currentSourcePoolInfo: PoolInfo?
  var currentDestPoolInfo: PoolInfo?
  var currentDestChain: ChainType?
  var currentDestToken: DestBridgeToken?
  var currentSendToAddress: String = ""
  var sourceAmount: Double = 0.0

  init(wallet: Wallet) {
    self.wallet = wallet
    self.currentSendToAddress = wallet.addressString
  }

  func updateWallet(_ wallet: Wallet) {
    self.wallet = wallet
  }

  func fromDataSource() -> [FromSectionRows] {
    return FromSectionRows.sectionRows(showPoolInfo: self.showFromPoolInfo)
  }
  
  func toDataSource() -> [ToSectionRows] {
    return ToSectionRows.sectionRows(showPoolInfo: self.showToPoolInfo, showSendAddress: self.showSendAddress, showReminder: self.showReminder, showError: self.showError)
  }

  func numberOfSection() -> Int {
    return 2
  }
  
  func numberOfRows(section: Int) -> Int {
    if section == 0 {
      return self.fromDataSource().count
    }
    return self.toDataSource().count
  }
  
  func calculateFee() -> Double {
    guard let currentDestToken = self.currentDestToken else {
      return 0.0
    }
    let destAmount = self.sourceAmount
    var fee = destAmount * currentDestToken.swapFeeRatePerMillion / 100
    fee = max(fee, currentDestToken.minimumSwapFee)
    fee = min(fee, currentDestToken.maximumSwapFee)

    return fee
  }
  
  func calculateDesAmountString() -> String {
    return StringFormatter.amountString(value: self.sourceAmount < self.calculateFee() ? 0 : self.sourceAmount - self.calculateFee())
  }
  
  func viewForHeader(section: Int) -> UIView {
    let view = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.size.width, height: 32))
    view.backgroundColor = UIColor(named: "mainViewBgColor")!
    let label = UILabel(frame: CGRect(x: 49, y: 0, width: 40, height: 24))
    label.text = section == 0 ? "From" : "To"
    label.textColor = UIColor(named: "textWhiteColor")!
    view.addSubview(label)
    return view
  }
  
  func viewForFooter() -> UIView {
    let view = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.size.width, height: 80))
    view.backgroundColor = UIColor(named: "mainViewBgColor")!
    let icon = UIImageView(frame: CGRect(x: (UIScreen.main.bounds.size.width - 24) / 2, y: 20, width: 24, height: 24))
    icon.image = UIImage(named: "circle_arrow_down_icon")
    view.addSubview(icon)
    return view
  }
  
  func cellForRows(tableView: UITableView, indexPath: IndexPath) -> UITableViewCell {
    if indexPath.section == 0 {
      switch self.fromDataSource()[indexPath.row] {
      case .selectChainRow:
        let cell = tableView.dequeueReusableCell(SelectChainCell.self, indexPath: indexPath)!
        cell.nameLabel.text = KNGeneralProvider.shared.currentChain.chainName()
        cell.selectionBlock = self.selectSourceChainBlock
        cell.arrowIcon.isHidden = false
        return cell
      case .poolInfoRow:
        let cell = tableView.dequeueReusableCell(ChainInfoCell.self, indexPath: indexPath)!
        if let currentSourcePoolInfo = self.currentSourcePoolInfo {
          cell.icon.image = KNGeneralProvider.shared.currentChain.chainIcon()
          cell.titleLabel.text = KNGeneralProvider.shared.currentChain.chainName() + currentSourcePoolInfo.liquidityPoolString()
        }
        return cell
      case .selectTokenRow:
        let cell = tableView.dequeueReusableCell(SelectTokenCell.self, indexPath: indexPath)!
        cell.setDisableSelectToken(shouldDisable: false)
        cell.selectTokenBlock = self.selectSourceTokenBlock
        cell.amountChangeBlock = self.changeAmountBlock
        cell.selectMaxBlock = self.selectMaxBlock
        cell.amountTextField.text = StringFormatter.amountString(value: self.sourceAmount)
        if let currentSourceToken = self.currentSourceToken {
          cell.selectTokenButton.setTitle(currentSourceToken.symbol, for: .normal)
          let bal: BigInt = currentSourceToken.getBalanceBigInt()
          let string = bal.string(
            decimals: currentSourceToken.decimals,
            minFractionDigits: 0,
            maxFractionDigits: min(currentSourceToken.decimals, 5)
          )
          if let double = Double(string.removeGroupSeparator()), double == 0 {
            cell.balanceLabel.text = "0"
          } else {
            cell.balanceLabel.text = "\(string.prefix(15)) \(currentSourceToken.symbol)"
          }
          
        } else {
          cell.selectTokenButton.setTitle("Select", for: .normal)
          cell.balanceLabel.text = "0"
        }
        var errMsg: String?
        if let currentDestToken = self.currentDestToken {
          if currentDestToken.minimumSwap > self.sourceAmount {
            errMsg = "Insufficient".toBeLocalised() + " \(currentDestToken.symbol) " + "balance".toBeLocalised()
          }
          if currentDestToken.maximumSwap < self.sourceAmount {
            errMsg = "Swap limit exceeded".toBeLocalised()
          }
          
          if let currentSourceToken = self.currentSourceToken {
            let amountString = currentSourceToken.getBalanceBigInt().fullString(decimals: currentSourceToken.decimals)
            let amountDouble = Double(amountString) ?? 0.0
            if self.sourceAmount > amountDouble {
              errMsg = "Insufficient".toBeLocalised() + " \(currentDestToken.symbol) " + "balance".toBeLocalised()
            }
          }
        }
        cell.showErrorIfNeed(errorMsg: errMsg)
        return cell
      }
    } else {
      switch self.toDataSource()[indexPath.row] {
      case .selectChainRow:
        let cell = tableView.dequeueReusableCell(SelectChainCell.self, indexPath: indexPath)!
        cell.nameLabel.text = ""
        cell.arrowIcon.isHidden = false
        cell.selectionBlock = self.selectDestChainBlock
        if let currentDestChain = self.currentDestChain {
          cell.nameLabel.text = currentDestChain.chainName()
        }
        return cell
      case .poolInfoRow:
        let cell = tableView.dequeueReusableCell(ChainInfoCell.self, indexPath: indexPath)!
        if let currentDestPoolInfo = self.currentDestPoolInfo, let currentDestChain = self.currentDestChain {
          cell.icon.image = currentDestChain.chainIcon()
          cell.titleLabel.text = currentDestChain.chainName() + currentDestPoolInfo.liquidityPoolString()
        }
        return cell
      case .selectTokenRow:
        let cell = tableView.dequeueReusableCell(SelectTokenCell.self, indexPath: indexPath)!
        cell.selectTokenBlock = self.selectDestTokenBlock
        cell.balanceLabel.text = ""
        cell.selectTokenButton.setTitle(self.currentDestToken?.symbol ?? "", for: .normal)
        cell.setDisableSelectToken(shouldDisable: true)
        cell.amountTextField.text = self.calculateDesAmountString()
        cell.showErrorIfNeed(errorMsg: nil)
        return cell
      case .sendToRow:
        let cell = tableView.dequeueReusableCell(BridgeSendToCell.self, indexPath: indexPath)!
        cell.sendButtonTapped = self.selectSenToBlock
        cell.icon.image = self.showSendAddress ? UIImage(named: "green_subtract_icon") : UIImage(named: "green_plus_icon")
        return cell
      case .addressRow:
        let cell = tableView.dequeueReusableCell(TextFieldCell.self, indexPath: indexPath)!
        cell.textField.text = self.currentSendToAddress
        cell.textChangeBlock = self.changeAddressBlock
        return cell
      case .reminderRow:
        let cell = tableView.dequeueReusableCell(BridgeReminderCell.self, indexPath: indexPath)!
          if let currentDestToken = self.currentDestToken {
            let crossChainFee = currentDestToken.maximumSwapFee == currentDestToken.minimumSwapFee ? "0.0" : String(format: "%.1f", currentDestToken.swapFeeRatePerMillion)
            let fee = self.calculateFee()
            let miniAmount = StringFormatter.amountString(value: currentDestToken.minimumSwap) + " \(currentDestToken.symbol)"
            let maxAmount = StringFormatter.amountString(value: currentDestToken.maximumSwap) + " \(currentDestToken.symbol)"
            let thresholdString = StringFormatter.amountString(value: currentDestToken.bigValueThreshold) + " \(currentDestToken.symbol)"
            cell.updateReminderText(crossChainFee: crossChainFee, gasFeeString: String(format: "%.1f \(currentDestToken.symbol)", fee), miniAmount: miniAmount, maxAmount: maxAmount, thresholdString: thresholdString)
          }
        return cell
      case .errorRow:
        return UITableViewCell()
      case .swapRow:
        let cell = tableView.dequeueReusableCell(BridgeSwapButtonCell.self, indexPath: indexPath)!
        cell.swapBlock = self.swapBlock
        if let currentSourceToken = currentSourceToken {
          cell.swapButton.setTitle(self.isNeedApprove ? "Approve \(currentSourceToken.symbol)" : "Swap Now", for: .normal)
        } else {
          cell.swapButton.setTitle("Swap Now", for: .normal)
        }
        return cell
      }
    }
  }
}