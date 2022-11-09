//
//  TxProcessorProtocol.swift
//  Dependencies
//
//  Created by Tung Nguyen on 09/11/2022.
//

import Foundation
import BaseWallet
import Result

public protocol TxProcessorProtocol {
    func sendTxToNode(data: Data, chain: ChainType, completion: @escaping (Result<String, AnyError>) -> Void)
}

