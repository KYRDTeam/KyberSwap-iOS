//
//  Signer.swift
//  KrystalWalletManager
//
//  Created by Tung Nguyen on 09/06/2022.
//

import Foundation

public enum SigningError: Error {
  case addressNotFound
  case cannotSignMessage
}


public protocol KSignerProtocol {
  func signMessage(address: KAddress, data: Data, addPrefix: Bool) throws -> Data
}