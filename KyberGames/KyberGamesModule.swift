//
//  KyberGamesModule.swift
//  KyberGames
//
//  Created by Nguyen Tung on 05/04/2022.
//

import Foundation
import UIKit

public enum KyberGamesEndpoint {
  case list
}

public class KyberGamesModule {
  
  static var isFontsRegistered: Bool = false
  
  public static func open(endpoint: KyberGamesEndpoint, navigationController: UINavigationController) {
    registerResourcesIfNeeded()
    switch endpoint {
    case .list:
      GameListCoordinator(navigationController: navigationController).start()
    }
  }
  
  private static func registerResourcesIfNeeded() {
    if !isFontsRegistered {
      UIFont.registerFonts()
      isFontsRegistered = true
    }
  }
  
}