//
//  OverviewSearchTokenViewController.swift
//  KyberNetwork
//
//  Created by Ta Minh Quan on 6/25/21.
//

import UIKit
import TagListView

//protocol OverviewSearchTokenViewControllerDelegate: class {
//  func overviewSearchTokenViewController(_ controller: OverviewSearchTokenViewController, open token: Token)
//}

class OverviewSearchTokenViewController: KNBaseViewController, AdvanceSearchTokenViewProtocol {
  var presenter: AdvanceSearchTokenPresenterProtocol!
  @IBOutlet weak var searchViewRightConstraint: NSLayoutConstraint!
  @IBOutlet weak var topView: UIView!
  @IBOutlet weak var topViewHeight: NSLayoutConstraint!
  @IBOutlet weak var searchField: UITextField!
  @IBOutlet weak var tableView: UITableView!
  @IBOutlet weak var emptyView: UIView!
  @IBOutlet weak var recentSearchTitle: UILabel!
  @IBOutlet weak var recentSearchTagList: TagListView!
  @IBOutlet weak var suggestSearchTItle: UILabel!
  @IBOutlet weak var suggestSearchTagList: TagListView!
  @IBOutlet weak var suggestSearchTitleTopContraint: NSLayoutConstraint!
  @IBOutlet weak var cancelButton: UIButton!
  @IBOutlet weak var searchFieldActionButton: UIButton!
  var timer: Timer?
  override func viewDidLoad() {
    super.viewDidLoad()
    self.tableView.registerCellNib(AdvanceSearchTokenCell.self)
    self.tableView.registerCellNib(AdvanceSearchPortfolioCell.self)
    self.recentSearchTagList.textFont = UIFont.Kyber.regular(with: 14)
    self.suggestSearchTagList.textFont = UIFont.Kyber.regular(with: 14)
    self.suggestSearchTagList.addTags(presenter.recommendTags)
    self.updateUIEmptyView()
  }
  
  @IBAction func closeButtonTapped(_ sender: Any) {
    searchField.text = ""
    presenter.dataSource = nil
    updateUIEndSearchingMode()
    reloadData()
  }

  @IBAction func backButtonTapped(_ sender: UIButton) {
    self.navigationController?.popViewController(animated: true)
  }
  
  func showLoading() {
    self.showLoadingHUD()
  }
  
  func hideLoading() {
    self.hideLoading(animated: true)
  }
  
  func reloadData() {
    self.tableView.reloadData()
    self.updateUIEmptyView()
  }
  
  func updateUIEmptyView() {
    guard (presenter.dataSource) != nil else {
      self.emptyView.isHidden = false
      let recentTags = presenter.getRecentSearchTag()
      self.recentSearchTagList.removeAllTags()
      self.recentSearchTagList.addTags(recentTags)
      if recentTags.isEmpty {
        self.recentSearchTitle.isHidden = true
        self.recentSearchTagList.isHidden = true
        self.suggestSearchTitleTopContraint.constant = 10.0
      } else {
        self.recentSearchTitle.isHidden = false
        self.recentSearchTagList.isHidden = false
        self.suggestSearchTitleTopContraint.constant = 180.0
      }
      return
    }
    self.emptyView.isHidden = true
  }
  
  func updateUIStartSearchingMode() {
    self.view.layoutIfNeeded()
    UIView.animate(withDuration: 0.65, delay: 0, usingSpringWithDamping: 0.65, initialSpringVelocity: 0, options: .curveEaseInOut) {
      self.searchViewRightConstraint.constant = 77
      self.topViewHeight.constant = 0
      self.topView.isHidden = true
      self.cancelButton.isHidden = false
      self.searchFieldActionButton.setImage(UIImage(named: "close-search-icon"), for: .normal)
      self.view.layoutIfNeeded()
    }
  }
  
  func updateUIEndSearchingMode() {
    self.view.layoutIfNeeded()
    UIView.animate(withDuration: 0.65, delay: 0, usingSpringWithDamping: 0.65, initialSpringVelocity: 0, options: .curveEaseInOut) {
      self.searchViewRightConstraint.constant = 21
      self.topViewHeight.constant = 90
      self.topView.isHidden = false
      self.cancelButton.isHidden = true
      self.searchFieldActionButton.setImage(UIImage(named: "search_blue_icon"), for: .normal)
      self.view.endEditing(true)
      self.view.layoutIfNeeded()
    }
  }
  
  @IBAction func cancelButtonTapped(_ sender: Any) {
    self.searchField.resignFirstResponder()
    self.updateUIEndSearchingMode()
  }

}

extension OverviewSearchTokenViewController: UITableViewDataSource {
  
  func numberOfSections(in tableView: UITableView) -> Int {
    return 2
  }
  
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    guard let dataSource = presenter.dataSource else {
      return 0
    }
    return section == 0 ? dataSource.portfolios.count : dataSource.tokens.count
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    if indexPath.section == 0 {
      let cell = tableView.dequeueReusableCell(AdvanceSearchPortfolioCell.self, indexPath: indexPath)!
      let portfolio = presenter.dataSource?.portfolios[indexPath.row]
      cell.updateUI(portfolio: portfolio)
      return cell
    } else {
      let cell = tableView.dequeueReusableCell(AdvanceSearchTokenCell.self, indexPath: indexPath)!
      let token = presenter.dataSource?.tokens[indexPath.row]
      cell.updateUI(token: token)
      return cell
    }
  }
}

extension OverviewSearchTokenViewController: UITableViewDelegate {
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    if indexPath.section == 0 {
      
    } else {
      if let token = presenter.dataSource?.tokens[indexPath.row] {
        let tokenModel = Token(name: token.name, symbol: token.symbol, address: token.id, decimals: token.decimals, logo: token.logo)
        presenter.openChartToken(token: tokenModel)
        presenter.saveNewSearchTag(token.symbol)
      }
    }
  }
}

extension OverviewSearchTokenViewController: UITextFieldDelegate {
  
  func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
    self.updateUIStartSearchingMode()
    return true
  }
  
  func textFieldDidEndEditing(_ textField: UITextField) {
    self.updateUIEndSearchingMode()
  }
  
  func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
    
    timer?.invalidate()
    timer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(doSearch), userInfo: nil, repeats: false)
    
    return true
  }
  
  @objc func doSearch() {
    if let text = self.searchField.text {
      presenter.doSearch(keyword: text)
    }
    self.updateUIEmptyView()
  }
  
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    return false
  }
}

extension OverviewSearchTokenViewController: TagListViewDelegate {
  func tagPressed(_ title: String, tagView: TagView, sender: TagListView) {
    let tokens = KNSupportedTokenStorage.shared.allActiveTokens
    if let found = tokens.first(where: { (token) -> Bool in
      return token.symbol.lowercased() == title.lowercased()
    }) {
      presenter.openChartToken(token: found)
    }
  }
}
