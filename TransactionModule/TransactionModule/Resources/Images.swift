//
//  UIImage+.swift
//  TransactionModule
//
//  Created by Tung Nguyen on 22/12/2022.
//

import Foundation
import UIKit

extension UIImage {
    static let txApprove = UIImage(imageName: "tx_approve")
    static let txBridge = UIImage(imageName: "tx_bridge")
    static let txClaim = UIImage(imageName: "tx_claim")
    static let txContractInteract = UIImage(imageName: "tx_contract_interact")
    static let txEarn = UIImage(imageName: "tx_earn")
    static let txMint = UIImage(imageName: "tx_mint")
    static let txReceive = UIImage(imageName: "tx_receive")
    static let txSend = UIImage(imageName: "tx_send")
    static let txSwap = UIImage(imageName: "tx_swap")
    static let txMultisend = UIImage(imageName: "tx_multisend")
    static let verifyToken = UIImage(imageName: "blueTick_icon")
    static let promotedToken = UIImage(imageName: "green-checked-tag-icon")
    static let unverifiedToken = UIImage(imageName: "warning-tag-icon")
}


extension UIImage {
    convenience init?(imageName: String) {
        self.init(named: imageName, in: Bundle(for: Images.self), compatibleWith: nil)
    }
}