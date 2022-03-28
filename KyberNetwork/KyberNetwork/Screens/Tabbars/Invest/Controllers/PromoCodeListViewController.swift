//
//  PromoCodeListViewController.swift
//  KyberNetwork
//
//  Created by Ta Minh Quan on 11/03/2022.
//

import UIKit

enum PromoCodeListViewEvent {
  case checkCode(code: String)
  case loadUsedCode
  case claim(code: String)
  case openDetail(item: PromoCode)
}

protocol PromoCodeListViewControllerDelegate: class {
  func promoCodeListViewController(_ viewController: PromoCodeListViewController, run event: PromoCodeListViewEvent)
}

class PromoCodeListViewModel {
  
  var searchCodes: [PromoCode] = []
  var usedCodes: [PromoCode] = []
  
  var unusedDataSource: [PromoCodeCellModel] = []
  var usedDataSource: [PromoCodeCellModel] = []
  
  var searchText = ""
  
  func reloadDataSource() {
    unusedDataSource.removeAll()
    usedDataSource.removeAll()
    
    self.unusedDataSource = self.searchCodes.map({ element in
      return PromoCodeCellModel(item: element)
    })
    
    self.usedDataSource = self.usedCodes.map({ element in
      return PromoCodeCellModel(item: element)
    })
  }

  var numberOfSection: Int {
    return self.usedDataSource.isEmpty ? 1 : 2
  }
  
  func clearSearchData() {
    unusedDataSource.removeAll()
    self.searchCodes.removeAll()
  }
}

class PromoCodeListViewController: KNBaseViewController {
  
  @IBOutlet weak var searchTextField: UITextField!
  @IBOutlet weak var promoCodeTableView: UITableView!
  @IBOutlet weak var searchContainerView: UIView!
  @IBOutlet weak var errorLabel: UILabel!
  
  
  let viewModel: PromoCodeListViewModel
  var cachedCell: [IndexPath: PromoCodeCell] = [:]
  var keyboardTimer: Timer?
  weak var delegate: PromoCodeListViewControllerDelegate?
  
  init(viewModel: PromoCodeListViewModel) {
    self.viewModel = viewModel
    super.init(nibName: PromoCodeListViewController.className, bundle: nil)
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    
    let nib = UINib(nibName: PromoCodeCell.className, bundle: nil)
    self.promoCodeTableView.register(nib, forCellReuseIdentifier: PromoCodeCell.cellID)
    self.promoCodeTableView.rowHeight = UITableView.automaticDimension
    self.promoCodeTableView.estimatedRowHeight = 200
    self.delegate?.promoCodeListViewController(self, run: .loadUsedCode)
    self.updateUIForSearchField(error: "")
    
  }
  
  @IBAction func backButtonTapped(_ sender: UIButton) {
    self.navigationController?.popViewController(animated: true, completion: nil)
  }
  
  private func updateUIForSearchField(error: String) {
    if error.isEmpty {
      self.searchContainerView.rounded(radius: 16)
      self.searchTextField.textColor = UIColor(named: "textWhiteColor")
      self.errorLabel.isHidden = true
    } else {
      self.searchContainerView.rounded(color: UIColor(named: "textRedColor")!, width: 1, radius: 16)
      self.searchTextField.textColor = UIColor(named: "textRedColor")
      self.errorLabel.isHidden = false
      self.errorLabel.text = error
    }
  }
  
  func coordinatorDidUpdateSearchPromoCodeItems(_ codes: [PromoCode], searchText: String) {
    guard self.viewModel.searchText == searchText else { return }
    self.viewModel.searchCodes = codes
    self.viewModel.reloadDataSource()
    guard self.isViewLoaded else { return }
    self.promoCodeTableView.reloadData()
    self.updateUIForSearchField(error: "")
  }

  func coordinatorDidUpdateUsedPromoCodeItems(_ codes: [PromoCode]) {
    self.viewModel.usedCodes = codes
    self.viewModel.reloadDataSource()
    guard self.isViewLoaded else { return }
    self.promoCodeTableView.reloadData()
  }
  
  func coordinatorDidClaimSuccessCode() {
    self.viewModel.clearSearchData()
    self.searchTextField.text = ""
    self.delegate?.promoCodeListViewController(self, run: .loadUsedCode)
  }
  
  func coordinatorDidReceiveClaimError(_ error: String) {
    self.updateUIForSearchField(error: error)
  }
}


extension PromoCodeListViewController: UITableViewDataSource {
  func numberOfSections(in tableView: UITableView) -> Int {
    return self.viewModel.numberOfSection
  }
  
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    if section == 0 {
      return self.viewModel.unusedDataSource.count
    } else {
      return self.viewModel.usedDataSource.count
    }
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(
      withIdentifier: PromoCodeCell.cellID,
      for: indexPath
    ) as! PromoCodeCell
    
    if indexPath.section == 0 {
      let cm = self.viewModel.unusedDataSource[indexPath.row]
      cell.updateCellModel(cm)
    } else {
      let cm = self.viewModel.usedDataSource[indexPath.row]
      cell.updateCellModel(cm)
    }
    cell.delegate = self
    self.cachedCell[indexPath] = cell
    return cell
  }
}

extension PromoCodeListViewController: UITableViewDelegate {
  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    if let cell = self.cachedCell[indexPath] {
      let value = self.calculateHeightForConfiguredSizingCell(cell: cell)
      return value
    }

    return UITableView.automaticDimension
  }

  func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
    guard section == 1 else { return UIView(frame: CGRect.zero) }
    let view = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.size.width, height: 40))
    view.backgroundColor = .clear
    let titleLabel = UILabel(frame: CGRect(x: 31, y: 0, width: 200, height: 40))
    titleLabel.center.y = view.center.y
    titleLabel.text = "Promo Code Used"
    titleLabel.font = UIFont.Kyber.bold(with: 16)
    titleLabel.textColor = UIColor.Kyber.SWWhiteTextColor
    view.addSubview(titleLabel)
    
    return view
  }
  
  func tableView(_ tableView: UITableView, estimatedHeightForHeaderInSection section: Int) -> CGFloat {
    if section == 0 {
      return 0
    } else {
      return 40
    }
  }
  
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    if indexPath.section == 0 {
      let cm = self.viewModel.unusedDataSource[indexPath.row]
      self.delegate?.promoCodeListViewController(self, run: .openDetail(item: cm.item))
    } else {
      let cm = self.viewModel.usedDataSource[indexPath.row]
      self.delegate?.promoCodeListViewController(self, run: .openDetail(item: cm.item))
    }
  }
  
  func calculateHeightForConfiguredSizingCell(cell: PromoCodeCell) -> CGFloat {
    cell.setNeedsLayout()
    cell.layoutIfNeeded()
    let height = cell.containerView.systemLayoutSizeFitting(UIView.layoutFittingExpandedSize).height + 42.0
    return height
  }
}

extension PromoCodeListViewController: UITextFieldDelegate {
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    if let empty = textField.text?.isEmpty, empty == true {
      self.viewModel.clearSearchData()
      self.promoCodeTableView.reloadData()
    }
    textField.resignFirstResponder()
    return true
  }

  func textFieldDidEndEditing(_ textField: UITextField) {
    self.checkRequestCode()
  }
  
  func textFieldShouldClear(_ textField: UITextField) -> Bool {
    self.viewModel.clearSearchData()
    self.promoCodeTableView.reloadData()
    self.viewModel.searchText = ""
    return true
  }

  func textFieldDidBeginEditing(_ textField: UITextField) {
    self.updateUIForSearchField(error: "")
  }
  
  func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
    self.keyboardTimer?.invalidate()
    self.keyboardTimer = Timer.scheduledTimer(
            timeInterval: 1,
            target: self,
            selector: #selector(PromoCodeListViewController.keyboardPauseTyping),
            userInfo: ["textField": textField],
            repeats: false)
    return true
  }
  
  @objc func keyboardPauseTyping(timer: Timer) {
    self.checkRequestCode()
  }
  
  fileprivate func checkRequestCode() {
    guard let text = self.searchTextField.text, text != self.viewModel.searchText else {
//      self.viewModel.clearSearchData()
//      self.promoCodeTableView.reloadData()
//      self.updateUIForSearchField(error: "")
      return
    }
    self.delegate?.promoCodeListViewController(self, run: .checkCode(code: text))
    self.viewModel.searchText = text
  }
}

extension PromoCodeListViewController: PromoCodeCellDelegate {
  func promoCodeCell(_ cell: PromoCodeCell, claim code: String) {
    self.delegate?.promoCodeListViewController(self, run: .claim(code: code))
  }
}