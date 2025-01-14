//
//  StakingSummaryViewModel.swift
//  EarnModule
//
//  Created by Tung Nguyen on 09/11/2022.
//

import KrystalWallets
import BigInt
import AppState
import Result
import APIKit
import JSONRPCKit
import Services
import Dependencies
import TransactionModule

class StakingSummaryViewModel: TxConfirmViewModelProtocol {
    
    var currentAddress: KAddress {
        return AppState.shared.currentAddress
    }
    
    var currentChain: ChainType {
        return AppState.shared.currentChain
    }
    
    var currentNonce: Int {
        return AppDependencies.nonceStorage.currentNonce(chain: currentChain, address: currentAddress.addressString)
    }
    
    let earnToken: EarningToken
    let txObject: TxObject
    var setting: TxSettingObject
    let token: Token
    let platform: EarnPlatform
    let displayInfo: StakeDisplayInfo
    let earningType: EarningType
    
    var shouldDiplayLoading: Observable<Bool> = .init(false)

    init(earnToken: EarningToken, txObject: TxObject, setting: TxSettingObject, token: Token, platform: EarnPlatform, displayInfo: StakeDisplayInfo) {
        self.earnToken = earnToken
        self.token = token
        self.platform = platform
        self.displayInfo = displayInfo
        self.txObject = txObject
        self.setting = setting
        self.earningType = .init(value: platform.type)
    }
    
    var title: String {
        switch earningType {
        case .staking:
            return Strings.stakeSummary
        case .lending:
            return Strings.supplySummary
        }
    }
    
    var chain: ChainType {
        return currentChain
    }
    
    var action: String {
        switch earningType {
        case .staking:
            return Strings.youAreStaking
        case .lending:
            return Strings.youAreSupplying
        }
    }
    
    var tokenIconURL: String {
        return token.logo
    }
    
    var tokenAmountString: String {
        return displayInfo.stakeAmount + " " + displayInfo.stakeToken.symbol
    }
    
    var platformName: String {
        return platform.name.uppercased()
    }
    
    var buttonTitle: String {
        switch earningType {
        case .staking:
            return Strings.confirmStake
        case .lending:
            return Strings.confirmSupply
        }
    }
    
    var rows: [TxInfoRowData] {
        return [
            .init(title: Strings.apyTitle, value: displayInfo.apy, isHighlighted: true),
            .init(title: Strings.youWillReceive, value: displayInfo.receiveAmount),
            .init(title: Strings.rate, value: displayInfo.rate),
            .init(title: Strings.networkFee, value: displayInfo.fee),
        ]
    }
    
    var isRequesting: Bool = false
    
    var onError: (String) -> Void = { _ in }
    
    var onSuccess: (PendingTxInfo) -> Void = { _ in }
    
    var onSelectOpenSetting: (() -> ())? = nil
    
    var onDataChanged: (() -> ())? = nil
    
    func onTapConfirm() {
        sendTransaction()
    }
    
    func onSettingChanged(settingObject: TxSettingObject) {
        setting = settingObject
    }
    
    func sendTransaction() {
        TransactionManager.txProcessor.process(address: currentAddress, chain: currentChain, txObject: txObject, setting: setting) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let txResult):
                let trackingExtraData = StakingTrackingExtraData(
                    token: self.token.symbol,
                    tokenAmount: self.displayInfo.stakeAmount.toDouble() ?? 0,
                    stakeToken: self.earnToken.symbol,
                    platform: self.platformName
                )
                let pendingTx = PendingStakingTxInfo(
                    token: self.token,
                    platform: self.platform,
                    selectedDestToken: self.earnToken,
                    sourceAmount: self.displayInfo.stakeAmount + " " + self.displayInfo.stakeToken.symbol,
                    destAmount: self.displayInfo.receiveAmount,
                    legacyTx: txResult.legacyTx,
                    eip1559Tx: txResult.eip1559Tx,
                    chain: self.currentChain,
                    date: Date(),
                    hash: txResult.hash,
                    earningType: self.earningType,
                    trackingExtraData: trackingExtraData
                )
                TransactionManager.txProcessor.savePendingTx(txInfo: pendingTx)
                self.onSuccess(pendingTx)
            case .failure(let error):
                self.onError(error.message)
            }
        }
    }
}
