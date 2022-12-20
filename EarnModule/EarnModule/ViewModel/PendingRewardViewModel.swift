//
//  PendingRewardViewModel.swift
//  EarnModule
//
//  Created by Ta Minh Quan on 12/12/2022.
//

import Foundation
import Services
import AppState

struct RewardItem {
    let rewardToken: RewardToken
    let chain: Chain
    let platform: RewardPlatform
}

class PendingRewardViewModel {
    let apiService = EarnServices()
    var searchText = ""
    var rewardData: [RewardItem] = []
    var chainID: Int?
    var dataSource: Observable<[PendingRewardCellModel]> = .init([])
    var isLoading: Observable<Bool> = .init(true)
    var isClaiming: Observable<Bool> = .init(false)
    var confirmViewModel: Observable<PendingRewardClaimConfirmPopUpViewModel?> = .init(nil)
    var errorMsg: Observable<String> = .init("")
    
    func reloadDataSource() {
        dataSource.value.removeAll()
        
        var data = rewardData
        
        if let chainID = chainID {
            data = data.filter({ item in
                return item.chain.id == chainID
            })
        }
        
        if !searchText.isEmpty {
            data = data.filter({ item in
                return item.rewardToken.tokenInfo.symbol.lowercased().contains(searchText)
            })
        }
        let cellModels = data.map { PendingRewardCellModel(item: $0) }
        dataSource.value = cellModels
    }
    
    func requestData() {
        isLoading.value = true
        apiService.getPendingReward(address: AppState.shared.currentAddress.addressString) { result in
            switch result {
            case .success(let rewards):
                var items: [RewardItem] = []
                rewards.forEach { element in
                    element.earningRewards.forEach { earningItem in
                        earningItem.rewardTokens?.forEach({ tokenItem in
                            let rewardItem = RewardItem(rewardToken: tokenItem, chain: earningItem.chain, platform: element.platform)
                            items.append(rewardItem)
                        })
                    }
                }
                self.rewardData = items
                self.reloadDataSource()
            case .failure(let error):
                print(error.description)
                self.rewardData = []
                self.reloadDataSource()
            }
            self.isLoading.value = false
        }
    }
    
    
    func isEmpty() -> Bool {
        return dataSource.value.isEmpty
    }
    
    func buildClaimReward(item: RewardItem) {
        isClaiming.value = true
        apiService.buildClaimReward(chainId: item.chain.id, from: AppState.shared.currentAddress.addressString, platform: item.platform.name) { result in
            switch result {
            case .success(let txObject):
                let popupViewModel = PendingRewardClaimConfirmPopUpViewModel(item: item, txObject: txObject)
                self.confirmViewModel.value = popupViewModel
            case .failure(let error):
                self.errorMsg.value = error.description
            }
            self.isClaiming.value = false
        }
    }
}
