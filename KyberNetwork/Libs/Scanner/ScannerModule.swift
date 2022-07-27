//
//  ScannerModule.swift
//  KyberNetwork
//
//  Created by Tung Nguyen on 20/07/2022.
//

import UIKit

class ScannerModule {
  
  static func start(navigationController: UINavigationController,
                    acceptedResultTypes: [ScanResultType] = ScanResultType.allCases,
                    defaultScanMode: ScanMode = .qr,
                    scanModes: [ScanMode] = [.qr, .text],
                    onComplete: @escaping (String, ScanResultType) -> Void) {
    let vc = KrystalScannerViewController.instantiateFromNib()
    vc.onScanSuccess = onComplete
    vc.acceptedResults = acceptedResultTypes
    vc.defaultScanMode = defaultScanMode
    vc.availableScanModes = scanModes
    vc.hidesBottomBarWhenPushed = true
    navigationController.pushViewController(vc, animated: true)
  }
  
}