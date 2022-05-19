//
//  BridgeViewController.swift
//  KyberNetwork
//
//  Created by Com1 on 18/05/2022.
//

import UIKit
import SwiftUI

enum BridgeEvent {
  case switchChain
  case openHistory
  case openWalletsList
  case addChainWallet(chainType: ChainType)
}

protocol BridgeViewControllerDelegate: class {
  func bridgeViewControllerController(_ controller: BridgeViewController, run event: BridgeEvent)
}


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
  var showFromPoolInfo: Bool = true
  var showToPoolInfo: Bool = true
  var showSendAddress: Bool = true
  var showReminder: Bool = true
  var showError: Bool = false
  var data: [SourceBridgeToken] = []
  
  init(wallet: Wallet) {
    self.wallet = wallet
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
        cell.arrowIcon.isHidden = false
        return cell
      case .poolInfoRow:
        let cell = tableView.dequeueReusableCell(ChainInfoCell.self, indexPath: indexPath)!
        return cell
      case .selectTokenRow:
        let cell = tableView.dequeueReusableCell(SelectTokenCell.self, indexPath: indexPath)!
        cell.selectTokenBlock = {
          
        }
        return cell
      }
    } else {
      switch self.toDataSource()[indexPath.row] {
      case .selectChainRow:
        let cell = tableView.dequeueReusableCell(SelectChainCell.self, indexPath: indexPath)!
        cell.nameLabel.text = ""
        cell.arrowIcon.isHidden = false
        return cell
      case .poolInfoRow:
        let cell = tableView.dequeueReusableCell(ChainInfoCell.self, indexPath: indexPath)!
        return cell
      case .selectTokenRow:
        let cell = tableView.dequeueReusableCell(SelectTokenCell.self, indexPath: indexPath)!
        return cell
      case .sendToRow:
        let cell = tableView.dequeueReusableCell(BridgeSendToCell.self, indexPath: indexPath)!
        return cell
      case .addressRow:
        let cell = tableView.dequeueReusableCell(SelectChainCell.self, indexPath: indexPath)!
        cell.arrowIcon.isHidden = true
        cell.nameLabel.text = ""
        return cell
      case .reminderRow:
        let cell = tableView.dequeueReusableCell(BridgeReminderCell.self, indexPath: indexPath)!
        return cell
      case .errorRow:
        return UITableViewCell()
      case .swapRow:
          let cell = tableView.dequeueReusableCell(BridgeSwapButtonCell.self, indexPath: indexPath)!
          return cell
      }
    }
  }
  
  func didSelectRow(indexPath: IndexPath) {
    
  }
}

class BridgeViewController: KNBaseViewController {
  @IBOutlet weak var chainIcon: UIImageView!
  @IBOutlet weak var tableView: UITableView!
  @IBOutlet weak var walletsListButton: UIButton!
  weak var delegate: BridgeViewControllerDelegate?
  var viewModel: BridgeViewModel
  
  init(viewModel: BridgeViewModel) {
    self.viewModel = viewModel
    super.init(nibName: BridgeViewController.className, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    self.setupUI()
  }
  
  func setupUI() {
    self.tableView.registerCellNib(SelectChainCell.self)
    self.tableView.registerCellNib(SelectTokenCell.self)
    self.tableView.registerCellNib(ChainInfoCell.self)
    self.tableView.registerCellNib(BridgeSendToCell.self)
    self.tableView.registerCellNib(BridgeReminderCell.self)
    self.tableView.registerCellNib(BridgeSwapButtonCell.self)
    self.updateUISwitchChain()
  }
  
  func updateUISwitchChain() {
    let icon = KNGeneralProvider.shared.chainIconImage
    self.chainIcon.image = icon
    self.walletsListButton.setTitle(self.viewModel.wallet.getWalletObject()?.name ?? "---", for: .normal)
  }
  
  func coordinatorDidUpdateChain() {
    self.updateUISwitchChain()
  }
  
  func coordinatorUpdateNewSession(wallet: Wallet) {
    self.viewModel.updateWallet(wallet)
    self.walletsListButton.setTitle(self.viewModel.wallet.getWalletObject()?.name ?? "---", for: .normal)
  }

  @IBAction func switchWalletButtonTapped(_ sender: Any) {
    self.delegate?.bridgeViewControllerController(self, run: .openWalletsList)
  }

  @IBAction func backButtonTapped(_ sender: Any) {
    self.navigationController?.popViewController(animated: true)
  }

  @IBAction func switchChainButtonTapped(_ sender: Any) {
    let popup = SwitchChainViewController()
    popup.completionHandler = { selected in
      if KNWalletStorage.shared.getAvailableWalletForChain(selected).isEmpty {
        self.delegate?.bridgeViewControllerController(self, run: .addChainWallet(chainType: selected))
        return
      } else {
        let viewModel = SwitchChainWalletsListViewModel(selected: selected)
        let secondPopup = SwitchChainWalletsListViewController(viewModel: viewModel)
        self.present(secondPopup, animated: true, completion: nil)
      }
    }
    self.present(popup, animated: true, completion: nil)
  }

  @IBAction func showHistoryButtonTapped(_ sender: Any) {
    
  }
}

extension BridgeViewController {
  func coordinatorDidUpdateData(tokens: [SourceBridgeToken]) {
    guard tokens.isNotEmpty else { return }
    self.viewModel.data = tokens
    self.tableView.reloadData()
  }
}

extension BridgeViewController: UITableViewDataSource {
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    return self.viewModel.cellForRows(tableView: tableView, indexPath: indexPath)
  }
  
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return self.viewModel.numberOfRows(section: section)
  }

  func numberOfSections(in tableView: UITableView) -> Int {
    return self.viewModel.numberOfSection()
  }
}

extension BridgeViewController: UITableViewDelegate {
  func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
    return CGFloat(32.0)
  }
  
  func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
    return section == 0 ? CGFloat(80) : CGFloat(0.01)
  }
  
  func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
    return self.viewModel.viewForHeader(section: section)
  }
  
  func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
    return section == 0 ? self.viewModel.viewForFooter() : nil
  }
  
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    self.viewModel.didSelectRow(indexPath: indexPath)
  }
}
