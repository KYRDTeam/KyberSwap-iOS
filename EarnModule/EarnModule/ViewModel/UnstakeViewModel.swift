//
//  UnstakeViewModel.swift
//  EarnModule
//
//  Created by Com1 on 14/11/2022.
//

import UIKit
import Services
import BigInt
import Utilities
import TransactionModule
import AppState
import Dependencies

protocol UnstakeViewModelDelegate: class {
    func didGetDataSuccess()
    func didGetDataNeedApproveToken()
    func didGetDataFail(errMsg: String)
}

class UnstakeViewModel {
    let displayDepositedValue: String
    let ratio: BigInt
    let stakingTokenSymbol: String
    let toTokenSymbol: String
    let balance: BigInt
    let platform: Platform
    var unstakeValue: BigInt = BigInt(0) {
        didSet {
            self.requestBuildUnstakeTx()
            self.configAllowance()
        }
    }
    let chain: ChainType
    var setting: TxSettingObject = .default
    let stakingTokenAddress: String
    let stakingTokenLogo: String
    let toTokenLogo: String
    let toUnderlyingTokenAddress: String
    var stakingTokenAllowance: BigInt = BigInt(0)
    var contractAddress: String?
    var minUnstakeAmount: BigInt = BigInt(0)
    var showRevertedRate: Bool = false
    weak var delegate: UnstakeViewModelDelegate?
    
    let apiService = EarnServices()
    var buildTxRequestParams: JSONDictionary {
        var earningType: String = platform.type
        if toTokenSymbol.lowercased() == "MATIC".lowercased() {
            earningType = "stakingMATIC"
        }
        var params: JSONDictionary = [
            "tokenAmount": unstakeValue.description,
            "chainID": chain.getChainId(),
            "earningType": earningType,
            "platform": platform.name,
            "userAddress": AppState.shared.currentAddress.addressString,
            "tokenAddress": toUnderlyingTokenAddress
        ]
        if platform.name.lowercased() == "ankr" {
            var useC = false
            if stakingTokenSymbol.suffix(1).description.lowercased() == "c" {
                useC = true
            }
            
            params["extraData"] = ["ankr": ["useTokenC": useC]]
        }
        return params
    }
    var txObject: TxObject?
    var onGasSettingUpdated: (() -> ())?

    init(earningBalance: EarningBalance) {
        self.displayDepositedValue = (BigInt(earningBalance.stakingToken.balance)?.shortString(decimals: earningBalance.stakingToken.decimals) ?? "---") + " " + earningBalance.stakingToken.symbol
        self.ratio = BigInt(earningBalance.ratio)
        self.stakingTokenSymbol = earningBalance.stakingToken.symbol
        self.toTokenSymbol = earningBalance.toUnderlyingToken.symbol
        self.balance = BigInt(earningBalance.stakingToken.balance) ?? BigInt(0)
        self.platform = earningBalance.platform
        self.chain = ChainType.make(chainID: earningBalance.chainID) ?? AppState.shared.currentChain
        self.toUnderlyingTokenAddress = earningBalance.toUnderlyingToken.address
        self.stakingTokenAddress = earningBalance.stakingToken.address
        self.stakingTokenLogo = earningBalance.stakingToken.logo
        self.toTokenLogo = earningBalance.toUnderlyingToken.logo
    }
    
    func unstakeValueString() -> String {
        NumberFormatUtils.balanceFormat(value: unstakeValue, decimals: 18)
    }
    
    func receivedValue() -> BigInt {
        return unstakeValue * self.ratio / BigInt(10).power(18)
    }
    
    func receivedValueString() -> String {
        return NumberFormatUtils.balanceFormat(value: receivedValue(), decimals: 18)
    }
    
    func receivedInfoString() -> String {
        return receivedValueString() + " " + toTokenSymbol
    }
    
    func receivedValueMaxString() -> String {
        let maxValue = balance * self.ratio / BigInt(10).power(18)
        return NumberFormatUtils.balanceFormat(value: maxValue, decimals: 18)
    }
    
    func showRateInfo() -> String {
        if showRevertedRate {
            let ratioString = NumberFormatUtils.balanceFormat(value: BigInt(10).power(36) / ratio, decimals: 18)
            return "1 \(toTokenSymbol) = \(ratioString) \(stakingTokenSymbol)"
        } else {
            let ratioString = NumberFormatUtils.balanceFormat(value: ratio, decimals: 18)
            return "1 \(stakingTokenSymbol) = \(ratioString) \(toTokenSymbol)"
        }
    }

    func timeForUnstakeString() -> String {
        let isAnkr = platform.name.lowercased() == "ANKR".lowercased()
        let isLido = platform.name.lowercased() == "LIDO".lowercased()
        
        var time = ""
        if toTokenSymbol.lowercased() == "AVAX".lowercased() && isAnkr {
            time = Strings.avaxUnstakeTime
        } else if toTokenSymbol.lowercased() == "BNB".lowercased() && isAnkr {
            time = Strings.bnbUnstakeTime
        } else if toTokenSymbol.lowercased() == "FTM".lowercased() && isAnkr {
            time = Strings.ftmUnstakeTime
        } else if toTokenSymbol.lowercased() == "MATIC".lowercased() && isAnkr {
            time = Strings.maticUnstakeTime
        } else if toTokenSymbol.lowercased() == "SOL".lowercased() && isLido {
            time =  Strings.solUnstakeTime
        }
        return String(format: Strings.youWillReceiveYourIn, toTokenSymbol, time)
    }

    func transactionFeeString() -> String {
        return NumberFormatUtils.gasFee(value: setting.transactionFee(chain: chain)) + " " + AppState.shared.currentChain.quoteToken()
    }
    
    func fetchData(completion: @escaping () -> ()) {
        apiService.getStakingOptionDetail(platform: platform.name, earningType: platform.type, chainID: "\(chain.getChainId())", tokenAddress: toUnderlyingTokenAddress) { result in
            switch result {
            case .success(let detail):
                if let earningToken = detail.earningTokens.first(where: { $0.address.lowercased() == self.stakingTokenAddress.lowercased() }) {
                    self.contractAddress = detail.poolAddress
                    let minAmount = detail.validation?.minUnstakeAmount ?? 0
                    self.minUnstakeAmount = BigInt(minAmount * pow(10.0, 18.0)) ?? BigInt(0)
                    self.checkNeedApprove(earningToken: earningToken, completion: completion)
                } else {
                    completion()
                    self.delegate?.didGetDataSuccess()
                }
            case .failure(let error):
                completion()
                self.delegate?.didGetDataFail(errMsg: error.localizedDescription)
            }
        }
    }
    
    func checkNeedApprove(earningToken: EarningToken, completion: @escaping () -> ()) {
        guard let contractAddress = contractAddress else { return }
        let service = EthereumNodeService(chain: chain)
        if earningToken.requireApprove {
            service.getAllowance(for: AppState.shared.currentAddress.addressString, networkAddress: contractAddress, tokenAddress: earningToken.address) { result in
                completion()
                switch result {
                case .success(let number):
                    self.stakingTokenAllowance = number
                    self.configAllowance()
                case .failure(let error):
                    self.delegate?.didGetDataFail(errMsg: error.localizedDescription)
                }
            }
        } else {
            completion()
            self.stakingTokenAllowance = TransactionConstants.maxTokenAmount
            self.delegate?.didGetDataSuccess()
        }
    }
    
    func requestBuildUnstakeTx(showLoading: Bool = false, completion: @escaping ((Error?) -> Void) = {_ in }) {
        apiService.buildUnstakeTx(param: buildTxRequestParams) { [weak self] result in
            switch result {
            case .success(let tx):
                self?.txObject = tx
                if let gasLimit = BigInt(tx.gasLimit.drop0x, radix: 16), gasLimit > 0 {
                    self?.didGetTxGasLimit(gasLimit: gasLimit)
                }
                completion(nil)
            case .failure(let error):
                completion(error)
            }
        }
    }
    
    func configAllowance() {
        if stakingTokenAllowance < unstakeValue {
            //need approve more
            self.delegate?.didGetDataNeedApproveToken()
        } else {
            // can make transaction
            self.delegate?.didGetDataSuccess()
        }
    }
    
    func didGetTxGasLimit(gasLimit: BigInt) {
        if setting.advanced != nil {
            return
        }
        setting.basic?.gasLimit = gasLimit
        onGasSettingUpdated?()
    }
}