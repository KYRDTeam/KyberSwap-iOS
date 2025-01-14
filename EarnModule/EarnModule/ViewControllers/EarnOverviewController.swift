//
//  EarnOverviewController.swift
//  EarnModule
//
//  Created by Com1 on 25/10/2022.
//

import UIKit
import BaseModule
import Dependencies
import AppState
import DesignSystem
import Services
import BigInt
import TransactionModule
import Utilities

class EarnOverviewController: InAppBrowsingViewController {
  @IBOutlet weak var segmentedControl: SegmentedControl!
  @IBOutlet weak var pageContainer: UIView!
  @IBOutlet weak var dotView: UIView!
    
  var selectedPageIndex = 0
  let pageViewController: UIPageViewController = {
    let pageVC = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal)
    return pageVC
  }()
  
  var childListViewControllers: [InAppBrowsingViewController] = []
  var viewModel: EarnOverViewModel!
    
    var tabCount: Int {
        return AppDependencies.featureFlag.isFeatureEnabled(key: FeatureFlagKeys.extraReward) ? 3 : 2
    }
    
    let appear = Once()

  override var supportAllChainOption: Bool {
    return true
  }
  var currentSelectedChain: ChainType = AppState.shared.isSelectedAllChain ? .all : AppState.shared.currentChain

  override func viewDidLoad() {
    super.viewDidLoad()
      
      initChildViewControllers()
      
    navigationController?.setNavigationBarHidden(true, animated: true)
  }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        appear.run {
            setupUI()
            setupPageViewController()
        }
        
        AppDependencies.tracker.track(
            "earn_v2_open",
            properties: ["screenid": "earn_v2"]
        )
    }

  override func onAppSelectAllChain() {
    currentSelectedChain = .all
    reloadAllNetworksChain()
  }

  override func handleChainButtonTapped() {
    AppDependencies.router.openChainList(currentSelectedChain, allowAllChainOption: supportAllChainOption, showSolanaOption: supportSolana) { [weak self] chain in
      self?.onChainSelected(chain: chain)
    }
  }

  @objc override func onAppSwitchChain() {
    super.onAppSwitchChain()
    currentSelectedChain = AppState.shared.currentChain
    reloadWallet()
  }

  func initChildViewControllers() {
      let earnPoolVC = EarnListViewController.instantiateFromNib()
      earnPoolVC.delegate = self
      let portfolioVC = StakingPortfolioViewController.instantiateFromNib()
      portfolioVC.delegate = self
      earnPoolVC.isSupportEarnv2.observeAndFire(on: self) { value in
          portfolioVC.updateSupportedEarnv2(value)
      }
      let pendingRewardVC = PendingRewardViewController.instantiateFromNib()
      let vcs = [earnPoolVC, portfolioVC, pendingRewardVC]
      childListViewControllers = vcs
  }

  func setupUI() {
    if currentSelectedChain == . all {
      reloadAllNetworksChain()
    }
    segmentedControl.highlightSelectedSegment(width: 100)
    let width = UIScreen.main.bounds.size.width - 36
    segmentedControl.frame = CGRect(x: self.segmentedControl.frame.minX, y: self.segmentedControl.frame.minY, width: width, height: 30)
      if tabCount == 2 {
          segmentedControl.setWidth(width / 2, forSegmentAt: 0)
          segmentedControl.setWidth(width / 2, forSegmentAt: 1)
          segmentedControl.removeSegment(at: 2, animated: false)
      } else if tabCount == 3 {
          segmentedControl.setWidth(width / 3, forSegmentAt: 0)
          segmentedControl.setWidth(width / 3, forSegmentAt: 1)
          segmentedControl.setWidth(width / 3, forSegmentAt: 2)
      }
      segmentedControl.underlineCenterPosition()
  }

  func setupPageViewController() {
    pageViewController.view.frame = self.pageContainer.bounds
    pageViewController.setViewControllers([childListViewControllers[selectedPageIndex]], direction: .forward, animated: true)
    pageViewController.dataSource = self
    pageViewController.delegate = self
    pageContainer.addSubview(pageViewController.view)
    addChild(pageViewController)
    pageViewController.didMove(toParent: self)
  }
    
    func jumpToPage(index: Int) {
        let pageIndex = min(tabCount, index)
        segmentedControl.selectedSegmentIndex = pageIndex
        segmentedControl.underlineCenterPosition()
        if pageIndex != selectedPageIndex {
            selectPage(index: pageIndex)
        }
    }

  @IBAction func segmentedControlValueChanged(_ sender: UISegmentedControl) {
    segmentedControl.underlineCenterPosition()
    if sender.selectedSegmentIndex != selectedPageIndex {
        selectPage(index: sender.selectedSegmentIndex)
    }
  }

  @IBAction func historyButtonWasTapped(_ sender: Any) {
    viewModel.didTapHistoryButton()
  }
    
    func selectPage(index: Int) {
        let direction: UIPageViewController.NavigationDirection = index < selectedPageIndex ? .reverse : .forward
        selectedPageIndex = index
        pageViewController.setViewControllers([childListViewControllers[index]], direction: direction, animated: true)
        AppDependencies.tracker.track( index == 0 ? "mob_earn_earn" : "mob_earn_portfolio", properties: ["screenid": "earn"])
    }
}

extension EarnOverviewController: UIPageViewControllerDataSource {
  func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
    if let vc = viewController as? InAppBrowsingViewController, let index = childListViewControllers.index(of: vc) {
      if index + 1 < childListViewControllers.count && index + 1 < tabCount {
        return childListViewControllers[index + 1]
      }
    }
    return nil
  }

  func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
    if let vc = viewController as? InAppBrowsingViewController, let index = childListViewControllers.index(of: vc) {
      if index - 1 >= 0 {
        return childListViewControllers[index - 1]
      }
    }
    return nil
  }
}

extension EarnOverviewController: UIPageViewControllerDelegate {
  func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
    var newIndex = 0
    if pageViewController.viewControllers?.first is StakingPortfolioViewController {
      newIndex = 1
    } else if pageViewController.viewControllers?.first is PendingRewardViewController {
      newIndex = 2
    }
    segmentedControl.selectedSegmentIndex = newIndex
    selectedPageIndex = newIndex
    segmentedControl.underlineCenterPosition()
  }
}

extension EarnOverviewController: EarnListViewControllerDelegate {
    
    func didSelectPlatform(platform: EarnPlatform, pool: EarnPoolModel) {
        guard let chain = ChainType.make(chainID: pool.chainID) else { return }
        if chain != AppState.shared.currentChain {
            AppState.shared.updateChain(chain: chain)
        }
        let vc = StakingViewController.instantiateFromNib()
        vc.viewModel = StakingViewModel(token: pool.token, platform: platform, chainId: pool.chainID)
        vc.onSelectViewPool = { [weak self] in
            self?.openPortfolio()
        }
        navigationController?.pushViewController(vc, animated: true)
    }
    
    func openPortfolio() {
        segmentedControl.selectedSegmentIndex = 1
        segmentedControl.underlineCenterPosition()
        selectPage(index: 1)
    }
}

extension EarnOverviewController: StakingPortfolioViewControllerDelegate {
    func didSelectPlatform(token: Token, platform: EarnPlatform, chainId: Int) {
        guard let chain = ChainType.make(chainID: chainId) else { return }
        if chain != AppState.shared.currentChain {
            AppState.shared.updateChain(chain: chain)
        }
        let vc = StakingViewController.instantiateFromNib()
        vc.viewModel = StakingViewModel(token: token, platform: platform, chainId: chainId)
        vc.onSelectViewPool = { [weak self] in
            self?.openPortfolio()
        }
        navigationController?.pushViewController(vc, animated: true)
    }
}
