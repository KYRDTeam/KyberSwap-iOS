//
//  TransactionSettingAdvancedTabViewModel.swift
//  TransactionModule
//
//  Created by Tung Nguyen on 28/10/2022.
//

import Foundation
import Dependencies
import BaseWallet
import AppState
import BigInt
import Utilities
import Services

class TransactionSettingAdvancedTabViewModel: BaseTransactionSettingTabViewModel {
    
    enum InputError {
      case high
      case low
      case empty
    }
    
    var currentNonce: Int {
        return AppDependencies.nonceStorage.currentNonce(chain: chain, address: AppState.shared.currentAddress.addressString)
    }
    
    var gasLimitText: String {
        return gasLimit.description
    }
    
    var priorityText: String {
        return priorityFee.string(units: UnitConfiguration.gasPriceUnit, minFractionDigits: 1, maxFractionDigits: 1)
    }
    
    var maxFeeText: String {
        return maxFee.string(units: UnitConfiguration.gasPriceUnit, minFractionDigits: 1, maxFractionDigits: 1)
    }
    
    var nonceText: String {
        if let advance = setting.advanced {
            return "\(advance.nonce)"
        }
        return "\(currentNonce)"
    }
    
    var displayEquivalentMaxETHFee: String {
        let value = maxFee * gasLimit
        return NumberFormatUtils.gasFee(value: value) + " \(chain.customRPC().quoteToken)"
    }
    
    var displayEquivalentPriorityETHFee: String {
        let value = gasLimit * priorityFee
        return NumberFormatUtils.gasFee(value: value) + " \(chain.customRPC().quoteToken)"
    }
    
    var gasLimitError: InputError? {
        guard let advancedGasLimit = setting.advanced?.gasLimit else {
            return nil
        }
        return advancedGasLimit < BigInt(21000) ? .low : nil
    }
    
    var priorityError: InputError? {
        guard let advancedPriority = setting.advanced?.maxPriorityFee else {
            return nil
        }
        let lowerLimit = gasConfig.lowPriorityFee ?? .zero
        let upperLimit = (gasConfig.fastPriorityFee ?? .zero) * BigInt(2)

        if advancedPriority < lowerLimit {
          return .low
        } else if advancedPriority > (BigInt(2) * upperLimit) {
          return .high
        } else {
          return nil
        }
    }
    
    var maxFeeError: InputError? {
        guard let advancedMaxFee = setting.advanced?.maxFee else {
            return nil
        }
        let lowerLimit = gasConfig.lowGas
        let upperLimit = gasConfig.superFastGas
        
        if advancedMaxFee < lowerLimit {
            return .low
        } else if advancedMaxFee > upperLimit {
            return .high
        }
        return nil
    }
    
    var nonceError: InputError? {
        guard let advancedNonce = setting.advanced?.nonce else {
            return nil
        }
        if advancedNonce < self.currentNonce {
            return .low
        }
        if advancedNonce > self.currentNonce + 1 {
            return .high
        }
        return nil
    }
    
    var web3Client: EthereumWeb3Service
    
    override init(settings: TxSettingObject, gasConfig: GasConfig, chain: ChainType) {
        web3Client = EthereumWeb3Service(chain: chain)
        super.init(settings: settings, gasConfig: gasConfig, chain: chain)
    }
    
    func updateGasLimit(value: BigInt) {
        if setting.advanced != nil {
            setting.advanced?.gasLimit = value
        } else {
            let basic = setting.basic
            setting.advanced = .init(
                gasLimit: value,
                maxFee: self.getGasPrice(gasType: basic?.gasType ?? .regular),
                maxPriorityFee: self.getPriority(gasType: basic?.gasType ?? .regular) ?? .zero,
                nonce: currentNonce
            )
            setting.basic = nil
        }
    }
    
    func updateMaxPriorityFee(value: BigInt) {
        if setting.advanced != nil {
            setting.advanced?.maxPriorityFee = value
        } else {
            let basic = setting.basic
            setting.advanced = .init(
                gasLimit: remoteGasLimit,
                maxFee: self.getGasPrice(gasType: basic?.gasType ?? .regular),
                maxPriorityFee: value,
                nonce: currentNonce
            )
            setting.basic = nil
        }
    }
    
    func updateMaxFee(value: BigInt) {
        if setting.advanced != nil {
            setting.advanced?.maxFee = value
        } else {
            let basic = setting.basic
            setting.advanced = .init(
                gasLimit: remoteGasLimit,
                maxFee: value,
                maxPriorityFee: self.getPriority(gasType: basic?.gasType ?? .regular) ?? .zero,
                nonce: currentNonce
            )
            setting.basic = nil
        }
    }
    
    func updateNonce(value: Int) {
        if setting.advanced != nil {
            setting.advanced?.nonce = value
        } else {
            let basic = setting.basic
            setting.advanced = .init(
                gasLimit: remoteGasLimit,
                maxFee: self.getGasPrice(gasType: basic?.gasType ?? .regular),
                maxPriorityFee: self.getPriority(gasType: basic?.gasType ?? .regular) ?? .zero,
                nonce: value
            )
            setting.basic = nil
        }
    }
    
    func getLatestNonce(completion: @escaping (Int?) -> ()) {
        let address = AppState.shared.currentAddress.addressString
        web3Client.getTransactionCount(for: address) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let nonce):
                AppDependencies.nonceStorage.updateNonce(chain: self.chain, address: address, value: nonce)
                completion(nonce)
            default:
                completion(nil)
            }
        }
    }
    
    
}