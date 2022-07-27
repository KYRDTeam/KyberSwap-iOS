//
//  Web3BridgeModule.swift
//  KrystalWeb3Bridge
//
//  Created by Tung Nguyen on 24/06/2022.
//

import Foundation
import KrystalJSBridge

class Web3BridgeModule: BaseBridgeModule {
  
  override func getModuleName() -> String {
    return "SolanaModule"
  }
  
  required override init(eventEmitter: EventEmitter) {
    super.init(eventEmitter: eventEmitter)
    addCommand(command: ConnectCommand(eventEmitter: eventEmitter))
    addCommand(command: GetPrivateKeyCommand(eventEmitter: eventEmitter))
  }
}
