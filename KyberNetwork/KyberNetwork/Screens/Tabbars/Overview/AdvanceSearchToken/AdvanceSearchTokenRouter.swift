//
//  AdvanceSearchTokenRouter.swift
//  KyberNetwork
//
//  Created Com1 on 13/06/2022.
//  Copyright © 2022 ___ORGANIZATIONNAME___. All rights reserved.
//
//  Template generated by Juanpe Catalán @JuanpeCMiOS
//

import UIKit
import Moya
import KrystalWallets
import Dependencies

class AdvanceSearchTokenRouter: AdvanceSearchTokenWireframeProtocol {
    
  weak var viewController: UIViewController?
  var coordinator: OverviewCoordinator?
  var pendingAction: (() -> Void)?
    
  func createModule(currencyMode: CurrencyMode, coordinator: OverviewCoordinator) -> UIViewController {
    // Change to get view from storyboard if not using progammatic UI
    let view = OverviewSearchTokenViewController()
    let interactor = AdvanceSearchTokenInteractor()
    let presenter = AdvanceSearchTokenPresenter(interface: view, interactor: interactor, router: self)
    presenter.currencyMode = currencyMode
    view.presenter = presenter
    interactor.presenter = presenter
    self.viewController = view
    self.coordinator = coordinator
    return view
  }
  
    func openChartTokenView(token: ResultToken, currencyMode: CurrencyMode) {
        guard let nav = viewController?.navigationController else { return }
        AppDependencies.router.openToken(navigationController: nav, address: token.id, chainID: token.chainId, tokenName: token.name)
    }
  
  func handleSwitchChain(_ controller: ChartViewController, completion: @escaping () -> Void) {
    self.pendingAction = nil
    var newChain = KNGeneralProvider.shared.currentChain
    if let chainType = ChainType.make(chainID: controller.viewModel.chainId) {
      newChain = chainType
    }
    let addresses = WalletManager.shared.getAllAddresses(addressType: newChain.addressType)
    if addresses.isEmpty {
      self.coordinator?.openAddChainWalletMenu(chain: newChain)
      self.pendingAction = completion
      return
    }
    let viewModel = SwitchChainWalletsListViewModel(selected: newChain)
    let secondPopup = SwitchChainWalletsListViewController(viewModel: viewModel)
    viewController?.present(secondPopup, animated: true, completion: nil)
    self.pendingAction = completion
  }
  
  func appCoordinatorDidUpdateNewSession() {
    if let pendingAction = pendingAction {
      pendingAction()
    }
  }
}
