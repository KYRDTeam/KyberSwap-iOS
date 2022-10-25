//
//  ApprovalListViewController.swift
//  KyberNetwork
//
//  Created by Tung Nguyen on 25/10/2022.
//

import UIKit
import BaseModule
import DesignSystem
import SkeletonView

class ApprovalListViewController: BaseWalletOrientedViewController {
    
    @IBOutlet weak var searchField: UITextField!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var riskAmountLabel: UILabel!
    
    var viewModel: ApprovalListViewModel!
    
    override var supportAllChainOption: Bool {
        return true
    }
    
    override var currentChain: ChainType {
        return viewModel.selectedChain
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupViews()
        bindViewModel()
        showLoading()
        viewModel.fetchApprovals()
    }
    
    override func onAppSwitchChain() {
        viewModel.selectedChain = KNGeneralProvider.shared.currentChain
        super.onAppSwitchChain()
        showLoading()
        viewModel.fetchApprovals()
    }
    
    override func onAppSelectAllChain() {
        viewModel.selectedChain = .all
        super.onAppSwitchChain()
        showLoading()
        viewModel.fetchApprovals()
    }
    
    override func onAppSwitchAddress() {
        super.onAppSwitchAddress()
        
        showLoading()
        viewModel.fetchApprovals()
    }
    
    func showLoading() {
        let gradient = SkeletonGradient(baseColor: UIColor.Kyber.cellBackground)
        view.showAnimatedGradientSkeleton(usingGradient: gradient)
    }
    
    func hideLoading() {
        view.hideSkeleton()
    }
    
    func bindViewModel() {
        viewModel.onFetchApprovals = { [weak self] in
            DispatchQueue.main.async {
                self?.hideLoading()
                self?.tableView.reloadData()
            }
        }
        
        viewModel.onFilterApprovalsUpdated = { [weak self] in
            DispatchQueue.main.async {
                self?.tableView.reloadData()
            }
        }
    }
    
    func setupViews() {
        setupTableView()
        setupSearchField()
    }
    
    func setupSearchField() {
        searchField.delegate = self
        searchField.setPlaceholder(text: Strings.approvalSearchPlaceholder, color: AppTheme.current.secondaryTextColor)
    }
    
    func setupTableView() {
        tableView.contentInset = .init(top: -16, left: 0, bottom: 0, right: 0)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableHeaderView = .init(frame: .init(x: 0, y: 0, width: 0, height: CGFloat.leastNonzeroMagnitude))
        tableView.registerCellNib(ApprovedTokenCell.self)
        tableView.registerCellNib(OverviewSkeletonCell.self)
    }
    
    @IBAction func backWasTapped(_ sender: Any) {
        viewModel.onTapBack()
    }
    
}

extension ApprovalListViewController: UITextFieldDelegate {
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let text = ((textField.text ?? "") as NSString).replacingCharacters(in: range, with: string)
        viewModel.searchText = text
        return true
    }
    
}

extension ApprovalListViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.filteredApprovals.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(ApprovedTokenCell.self, indexPath: indexPath)!
        cell.selectionStyle = .none
        cell.configure(viewModel: viewModel.filteredApprovals[indexPath.row])
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 84
    }
    
}

extension ApprovalListViewController: SkeletonTableViewDataSource {
    
    func collectionSkeletonView(_ skeletonView: UITableView, cellIdentifierForRowAt indexPath: IndexPath) -> ReusableCellIdentifier {
        return OverviewSkeletonCell.className
    }
    
    func collectionSkeletonView(_ skeletonView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 10
    }
    
}

