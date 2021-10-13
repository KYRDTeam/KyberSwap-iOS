// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import BigInt
import TrustKeystore
import TrustCore

struct UnconfirmedTransaction {
  let transferType: TransferType
  let value: BigInt
  let to: Address?
  let data: Data?
  
  let gasLimit: BigInt?
  let gasPrice: BigInt?
  let nonce: BigInt?
  
  let maxInclusionFeePerGas: String?
  let maxGasFee: String?
  
  func toEIP1559Transaction(nonceInt: Int, data: Data?, fromAddress: String) -> EIP1559Transaction? {
    func valueToSend(_ transaction: UnconfirmedTransaction) -> BigInt {
      return transaction.transferType.isETHTransfer() ? transaction.value : BigInt(0)
    }

    func addressToSend(_ transaction: UnconfirmedTransaction) -> Address? {
      let address: Address? = {
        switch transaction.transferType {
        case .ether: return transaction.to
        case .token(let token):
          return token.addressObj
        }
      }()
      return address
    }
    guard let priorityFeeString = self.maxInclusionFeePerGas,
            let maxGasFeeString = self.maxGasFee else {
      return nil
    }
    let priorityFeeBigInt = priorityFeeString.shortBigInt(units: UnitConfiguration.gasPriceUnit) ?? BigInt(0)
    let maxGasFeeBigInt = maxGasFeeString.shortBigInt(units: UnitConfiguration.gasPriceUnit) ?? BigInt(0)
    let chainID = BigInt(KNGeneralProvider.shared.customRPC.chainID).hexEncoded
    let nonceBigInt = BigInt(nonceInt).hexEncoded

    return EIP1559Transaction(
      chainID: chainID.hexSigned2Complement,
      nonce: nonceBigInt.hexSigned2Complement,
      gasLimit: self.gasLimit?.hexEncoded.hexSigned2Complement ?? "",
      maxInclusionFeePerGas: priorityFeeBigInt.hexEncoded.hexSigned2Complement,
      maxGasFee: maxGasFeeBigInt.hexEncoded.hexSigned2Complement,
      toAddress: addressToSend(self)?.description ?? "",
      fromAddress: fromAddress,
      data: data?.hexString ?? "",
      value: valueToSend(self).hexEncoded.hexSigned2Complement
    )
  }
}


