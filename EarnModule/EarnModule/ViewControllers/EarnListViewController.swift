//
//  EarnListViewController.swift
//  KyberNetwork
//
//  Created by Com1 on 12/10/2022.
//

import UIKit
import SkeletonView
import BaseModule
import Dependencies
import AppState
import Services
import DesignSystem
import FittedSheets
import Utilities

protocol EarnListViewControllerDelegate: class {
    func didSelectPlatform(platform: EarnPlatform, pool: EarnPoolModel)
}

class EarnListViewController: InAppBrowsingViewController {
    @IBOutlet weak var searchTextField: UITextField!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var searchFieldActionButton: UIButton!
    @IBOutlet weak var filterButton: UIButton!
    @IBOutlet weak var emptyView: UIView!
    @IBOutlet weak var emptyIcon: UIImageView!
    @IBOutlet weak var emptyLabel: UILabel!
    weak var delegate: EarnListViewControllerDelegate?
    var isNeedReloadFilter = true
    var dataSource: [EarnPoolViewCellViewModel] = []
    var displayDataSource: [EarnPoolViewCellViewModel] = []
    var timer: Timer?
    var currentSelectedChain: ChainType = AppState.shared.isSelectedAllChain ? .all : AppState.shared.currentChain
    var selectedPlatforms: Set<EarnPlatform>!
    var selectedTypes: [EarningType] = [.staking, .lending]
    var isSupportEarnv2: Observable<Bool> = .init(true)
    var isEditingField: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        selectedPlatforms = Set(getAllPlatform())
        fetchData(chainId: currentSelectedChain == .all ? nil : currentSelectedChain.getChainId())
        Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            self?.fetchData(chainId: self?.currentSelectedChain == .all ? nil : self?.currentSelectedChain.getChainId(), isAutoReload: true)
        }
        setupUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        hideLoading()
    }
    
    func resetFilter() {
        self.selectedPlatforms = []
        self.selectedTypes = [.staking, .lending]
    }
    
    override func onAppSwitchChain() {
        isNeedReloadFilter = true
        currentSelectedChain = AppState.shared.currentChain
        fetchData(chainId: currentSelectedChain == .all ? nil : currentSelectedChain.getChainId())
        resetFilter()
    }
    
    override func onAppSelectAllChain() {
        isNeedReloadFilter = true
        currentSelectedChain = .all
        fetchData()
        resetFilter()
    }
    
    override func onAppSwitchAddress(switchChain: Bool) {
        resetFilter()
    }
    
    func setupUI() {
        self.searchTextField.setPlaceholder(text: Strings.searchToken, color: AppTheme.current.secondaryTextColor)
        self.tableView.registerCellNib(EarnPoolViewCell.self)
    }
    
    private func isSelectedAllPlatforms() -> Bool {
        return selectedPlatforms.isEmpty || selectedPlatforms.count == getAllPlatform().count
    }
    
    private func isSelectedAllType() -> Bool {
        return selectedTypes.contains(.staking) && selectedTypes.contains(.lending)
    }
    
    func reloadUI() {
        displayDataSource = dataSource
        if let text = self.searchTextField.text, !text.isEmpty {
            self.displayDataSource = self.dataSource.filter({ viewModel in
                let containSymbol = viewModel.earnPoolModel.token.symbol.lowercased().contains(text.lowercased())
                let containName = viewModel.earnPoolModel.token.name.lowercased().contains(text.lowercased())
                return containSymbol || containName
            })
            if self.displayDataSource.isEmpty {
                self.emptyIcon.image = UIImage(named: "empty-search-token")
                self.emptyLabel.text = Strings.noRecordFound
            }
        }
        
        if selectedTypes.isEmpty {
            displayDataSource.removeAll()
        }

        if !isSelectedAllType() {
            displayDataSource = displayDataSource.filter { element in
                let filterPlatforms = element.earnPoolModel.platforms.filter { platform in
                    let earningType = EarningType(value: platform.type)
                    return self.selectedTypes.contains(earningType)
                }
                return filterPlatforms.count >= 1
            }
        }

        if !isSelectedAllPlatforms() {
            self.displayDataSource = self.displayDataSource.filter { element in
                let modelPfSet: Set<EarnPlatform> = Set(element.earnPoolModel.platforms)
                var filterPlatform = modelPfSet.intersection(self.selectedPlatforms).filter { platform in
                    let earningType = EarningType(value: platform.type)
                    return self.selectedTypes.contains(earningType)
                }
                return filterPlatform.count >= 1
            }
            
            displayDataSource.forEach { item in
                item.filteredPlatform = self.selectedPlatforms
                item.filteredType = self.selectedTypes
            }
            if self.displayDataSource.isEmpty {
                self.emptyIcon.image = UIImage(named: "empty-search-token")
                self.emptyLabel.text = Strings.noRecordFound
            }
        } else {
            displayDataSource.forEach { item in
                item.filteredPlatform = nil
                item.filteredType = self.selectedTypes
            }
        }

        self.emptyView.isHidden = !self.displayDataSource.isEmpty
        self.isSupportEarnv2.value = !self.dataSource.isEmpty
        self.tableView.reloadData()
    }
    
    func fetchData(chainId: Int? = nil, isAutoReload: Bool = false) {
        if !isAutoReload {
            self.displayDataSource.forEach { viewModel in
                viewModel.isExpanse = false
            }
            reloadUI()
        }
        let service = EarnServices()
        if !isAutoReload {
            showLoading()
        }
        
        var chainIdString: String?
        if let chainId = chainId {
            chainIdString = "\(chainId)"
        }
        service.getEarnListData(chainId: chainIdString) { listData in
            var data: [EarnPoolViewCellViewModel] = []
            listData.forEach { earnPoolModel in
                data.append(EarnPoolViewCellViewModel(earnPool: earnPoolModel))
            }
            if data.isEmpty {
                self.emptyIcon.image = UIImage(named: "empty_earn_icon")
                self.emptyLabel.text = Strings.earnIsCurrentlyNotSupportedOnThisChainYet
            } else {
                self.emptyIcon.image = UIImage(named: "empty-search-token")
                self.emptyLabel.text = Strings.noRecordFound
            }
            
            self.dataSource = data
            var displayData: [EarnPoolViewCellViewModel] = []
            data.forEach { cellVM in
                if let oldVM = self.displayDataSource.first { object in
                    return object.earnPoolModel.chainID == cellVM.earnPoolModel.chainID && object.earnPoolModel.token.address.lowercased() == cellVM.earnPoolModel.token.address.lowercased()
                } {
                    cellVM.isExpanse = oldVM.isExpanse
                }
                displayData.append(cellVM)
            }
            
            self.displayDataSource = displayData
            if let text = self.searchTextField.text, !text.isEmpty {
                self.filterDataSource(text: text)
            }
            self.hideLoading()
            if self.isNeedReloadFilter {
                self.isNeedReloadFilter = false
                self.selectedPlatforms = self.getAllPlatform()
            }
            self.reloadUI()
        }
    }
    
    private func getAllPlatform() -> Set<EarnPlatform> {
        var platformSet = Set<EarnPlatform>()
        
        dataSource.forEach { item in
            item.earnPoolModel.platforms.forEach { element in
                platformSet.insert(element)
            }
        }
        return platformSet
    }
    
    
    func updateUIStartSearchingMode() {
        self.view.layoutIfNeeded()
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.65, initialSpringVelocity: 0, options: .curveEaseInOut) {
            self.searchFieldActionButton.setImage(UIImage(named: "close-search-icon"), for: .normal)
            self.view.layoutIfNeeded()
        }
        isEditingField = true
    }
    
    func updateUIEndSearchingMode() {
        self.view.layoutIfNeeded()
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.65, initialSpringVelocity: 0, options: .curveEaseInOut) {
            self.searchFieldActionButton.setImage(UIImage(named: "search_blue_icon"), for: .normal)
            self.view.endEditing(true)
            self.view.layoutIfNeeded()
        }
        isEditingField = false
    }
    
    @IBAction func filterButtonTapped(_ sender: Any) {
        let allPlatforms = getAllPlatform()
        let viewModel = PlatformFilterViewModel(dataSource: allPlatforms, selected: selectedPlatforms)
        viewModel.shouldShowType = true
        viewModel.selectedType = self.selectedTypes

        let viewController = PlatformFilterViewController.instantiateFromNib()
        viewController.viewModel = viewModel
        viewController.delegate = self
        let sheetOptions = SheetOptions(pullBarHeight: 0)
        let sheet = SheetViewController(controller: viewController, sizes: [.intrinsic], options: sheetOptions)
        present(sheet, animated: true)
    }
    
    @IBAction func onSearchButtonTapped(_ sender: Any) {
        if isEditingField {
            updateUIEndSearchingMode()
            searchTextField.text = ""
            searchTextField.resignFirstResponder()
            reloadUI()
        } else {
            updateUIStartSearchingMode()
        }
    }
}

extension EarnListViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return displayDataSource.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(EarnPoolViewCell.self, indexPath: indexPath)!
        let viewModel = displayDataSource[indexPath.row]
        cell.updateUI(viewModel: viewModel, shouldShowChainIcon: currentSelectedChain == .all)
        cell.delegate = self
        return cell
    }
}

extension EarnListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cellViewModel = displayDataSource[indexPath.row]
        cellViewModel.isExpanse = !cellViewModel.isExpanse
        self.tableView.beginUpdates()
        if let cell = self.tableView.cellForRow(at: indexPath) as? EarnPoolViewCell {
            animateCellHeight(cell: cell, viewModel: cellViewModel)
        }
        self.tableView.endUpdates()
        AppDependencies.tracker.track("mob_earn_select_token", properties: ["screenid": "earn_v2"])
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let cellViewModel = displayDataSource[indexPath.row]
        return cellViewModel.height()
    }
    
    func animateCellHeight(cell: EarnPoolViewCell, viewModel: EarnPoolViewCellViewModel) {
        self.view.layoutIfNeeded()
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.65, initialSpringVelocity: 0, options: .curveEaseInOut) {
            var rect = cell.frame
            rect.size.height = viewModel.height()
            cell.frame = rect
            cell.updateUIExpanse(viewModel: viewModel)
            self.view.layoutIfNeeded()
        }
    }
}

extension EarnListViewController: SkeletonTableViewDelegate, SkeletonTableViewDataSource {
    
    func showLoading() {
        let gradient = SkeletonGradient(baseColor: AppTheme.current.sectionBackgroundColor)
        view.showAnimatedGradientSkeleton(usingGradient: gradient)
    }
    
    func hideLoading() {
        DispatchQueue.main.async {
            self.view.hideSkeleton()
        }
    }
    
    func collectionSkeletonView(_ skeletonView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 2
    }
    
    func collectionSkeletonView(_ skeletonView: UITableView, skeletonCellForRowAt indexPath: IndexPath) -> UITableViewCell? {
        let cell = skeletonView.dequeueReusableCell(EarnPoolViewCell.self, indexPath: indexPath)!
        return cell
    }
    
    func collectionSkeletonView(_ skeletonView: UITableView, cellIdentifierForRowAt indexPath: IndexPath) -> ReusableCellIdentifier {
        return EarnPoolViewCell.className
    }
}

extension EarnListViewController: UITextFieldDelegate {
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
    
    func filterDataSource(text: String) {
        self.displayDataSource = self.dataSource.filter({ viewModel in
            let containSymbol = viewModel.earnPoolModel.token.symbol.lowercased().contains(text.lowercased())
            let containName = viewModel.earnPoolModel.token.name.lowercased().contains(text.lowercased())
            return containSymbol || containName
        })
    }
    
    @objc func doSearch() {
        if let text = self.searchTextField.text, !text.isEmpty {
            filterDataSource(text: text)
            if self.displayDataSource.isEmpty {
                self.emptyIcon.image = UIImage(named: "empty-search-token")
                self.emptyLabel.text = Strings.noRecordFound
            }
            self.reloadUI()
        } else {
            self.fetchData(chainId: currentSelectedChain == .all ? nil : currentSelectedChain.getChainId())
        }
    }
}

extension EarnListViewController: EarnPoolViewCellDelegate {
    func didSelectRewardApy(platform: EarnPlatform, pool: EarnPoolModel) {
        let messge = String(format: Strings.rewardApyInfoText, NumberFormatUtils.percent(value: platform.apy.roundedValue()), NumberFormatUtils.percent(value: platform.rewardApy.roundedValue()))
        showBottomBannerView(message: messge)
    }
    
    func didSelectPlatform(platform: EarnPlatform, pool: EarnPoolModel) {
        delegate?.didSelectPlatform(platform: platform, pool: pool)
    }
    
    func showWarning(_ type: String) {
        switch type {
        case "disabled":
            self.showErrorTopBannerMessage(message: Strings.stakeDisableMessage)
        case "warning":
            self.showErrorTopBannerMessage(message: Strings.stakeWarningMessage)
        default:
            break
        }
    }
}

extension EarnListViewController: PlatformFilterViewControllerDelegate {
    func didSelectPlatform(viewController: PlatformFilterViewController, selected: Set<EarnPlatform>, types: [EarningType]) {
        selectedPlatforms = selected
        selectedTypes = types
        viewController.dismiss(animated: true) {
            self.reloadUI()
        }
    }
}
