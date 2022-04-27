// Copyright SIX DAY LLC. All rights reserved.

import UIKit
import SafariServices
import TrustKeystore
import TrustCore
import MessageUI

protocol KNLandingPageCoordinatorDelegate: class {
  func landingPageCoordinator(import wallet: Wallet)
  func landingPageCoordinator(remove wallet: Wallet)
  func landingPageCoordinatorDidSendRefCode(_ code: String)
}

/**
 Flow:
 1. Create Wallet:
  - Enter password
  - Backup 12 words seed for new wallet
  - Testing backup
  - Enter wallet name
  - Enter passcode (if it is the first wallet)
 2. Import Wallet:
  - JSON/Private Key/Seeds
  - Enter wallet name
  - Enter passcode (if it is the first wallet)
 */
class KNLandingPageCoordinator: NSObject, Coordinator {

  weak var delegate: KNLandingPageCoordinatorDelegate?
  let navigationController: UINavigationController
  var keystore: Keystore
  var coordinators: [Coordinator] = []

  fileprivate var newWallet: Wallet?
  fileprivate var isCreate: Bool = false

  lazy var rootViewController: KNLandingPageViewController = {
    let controller = KNLandingPageViewController()
    controller.loadViewIfNeeded()
    controller.delegate = self
    return controller
  }()

  lazy var createWalletCoordinator: KNCreateWalletCoordinator = {
    let coordinator = KNCreateWalletCoordinator(
      navigationController: self.navigationController,
      keystore: self.keystore,
      newWallet: self.newWallet,
      name: nil
    )
    coordinator.delegate = self
    return coordinator
  }()

  lazy var importWalletCoordinator: KNImportWalletCoordinator = {
    let coordinator = KNImportWalletCoordinator(
      navigationController: self.navigationController,
      keystore: self.keystore
    )
    coordinator.delegate = self
    return coordinator
  }()

  lazy var passcodeCoordinator: KNPasscodeCoordinator = {
    let coordinator = KNPasscodeCoordinator(
      navigationController: self.navigationController,
      type: .setPasscode(cancellable: false)
    )
    coordinator.delegate = self
    return coordinator
  }()
  
  lazy var termViewController: TermsAndConditionsViewController = {
    let controller = TermsAndConditionsViewController()
    return controller
  }()

  init(
    navigationController: UINavigationController = UINavigationController(),
    keystore: Keystore
    ) {
    self.navigationController = navigationController
    self.navigationController.setNavigationBarHidden(true, animated: false)
    self.keystore = keystore
  }

  func start() {
    if self.keystore.wallets.isEmpty && KNPasscodeUtil.shared.currentPasscode() != nil {
      // In case user delete the app, wallets are removed but passcode is still save in keychain
      self.navigationController.viewControllers = [self.rootViewController]
      KNPasscodeUtil.shared.deletePasscode()
    }
    if let wallet = self.newWallet {
      self.navigationController.viewControllers = [self.rootViewController]
      self.createWalletCoordinator.updateNewWallet(wallet, name: "Untitled")
      self.createWalletCoordinator.start()
      return
    }
    if let wallet = self.keystore.recentlyUsedWallet ?? self.keystore.wallets.first {
      if case .real(let account) = wallet.type {
         //In case backup with icloud/local backup there is no keychain so delete all keystore in keystore directory
         guard let _ =  keystore.getPassword(for: account) else {
            KNPasscodeUtil.shared.deletePasscode()
            let fileManager = FileManager.default
            do {
                let filePaths = try fileManager.contentsOfDirectory(atPath: keystore.keysDirectory.path)
                for filePath in filePaths {
                    let keyPath = URL(fileURLWithPath: keystore.keysDirectory.path).appendingPathComponent(filePath).absoluteURL
                    try fileManager.removeItem(at: keyPath)
                }
            } catch {
                print("Could not clear keystore folder: \(error)")
            }
            KNWalletStorage.shared.deleteAll()
            return
         }
        
      }
      if KNPasscodeUtil.shared.currentPasscode() == nil {
        self.navigationController.viewControllers = [self.rootViewController]
        // In case user imported a wallet and kill the app during settings passcode
        self.newWallet = wallet
        self.passcodeCoordinator.start()
      }
    } else {
      self.navigationController.viewControllers = [self.rootViewController]
    }
  }

  func updateNewWallet(wallet: Wallet) {
    self.newWallet = wallet
  }
  func update(keystore: Keystore) {
    self.keystore = keystore
  }

  fileprivate func addNewWallet(_ wallet: Wallet, isCreate: Bool, name: String?, addToContact: Bool = true, isBackUp: Bool, importType: ImportWalletChainType, importMethod: StorageType) {
    let walletObject = KNWalletObject(
      address: wallet.addressString,
      name: name ?? "Untitled",
      isBackedUp: isBackUp,
      chainType: importType,
      storageType: importMethod,
      evmAddress: wallet.evmAddressString
    )
    var wallets = [walletObject]
    if case .multiChain = importType, case .real(let account) = wallet.type {
      let result = self.keystore.exportMnemonics(account: account)
      if case .success(let seeds) = result {
        let publicKey = SolanaUtil.seedsToPublicKey(seeds)
        let solName = name ?? "Untitled"
        let solWalletObject = KNWalletObject(
          address: publicKey,
          name: solName + "-sol",
          isBackedUp: true,
          isWatchWallet: false,
          chainType: .solana,
          storageType: importMethod,
          evmAddress: wallet.evmAddressString,
          walletID: ""
        )
        wallets.append(solWalletObject)
      }
    }
    if case .solana = importType, case .solana(_ , let evmAddress, let walletID) = wallet.type {
      let walletName = name ?? "Untitled"
      let evmWalletObject = KNWalletObject(
        address: evmAddress,
        name: walletName + "-evm",
        isBackedUp: true,
        isWatchWallet: false,
        chainType: .evm,
        storageType: importMethod,
        evmAddress: "",
        walletID: walletID
      )
      wallets.append(evmWalletObject)
    }
    KNWalletStorage.shared.add(wallets: wallets)
    if addToContact {
      let contact = KNContact(
        address: wallet.addressString,
        name: name ?? "Untitled"
      )
      KNContactStorage.shared.update(contacts: [contact])
    }
    self.newWallet = wallet
    self.isCreate = isCreate
    self.keystore.recentlyUsedWallet = wallet
    let abc = self.keystore.recentlyUsedWallet
    
    KNGeneralProvider.shared.currentChain = .solana
    
    if self.keystore.wallets.count == 1 {
      KNPasscodeUtil.shared.deletePasscode()
      self.passcodeCoordinator.start()
    } else {
      self.delegate?.landingPageCoordinator(import: wallet)
    }
  }
}

extension KNLandingPageCoordinator: KNLandingPageViewControllerDelegate {
  func landinagePageViewController(_ controller: KNLandingPageViewController, run event: KNLandingPageViewEvent) {
    switch event {
    case .openCreateWallet:
      KNCrashlyticsUtil.logCustomEvent(withName: "intro_create_wallet", customAttributes: nil)
      if UserDefaults.standard.bool(forKey: Constants.acceptedTermKey) == false {
        self.termViewController.nextAction = {
          self.createWalletCoordinator.updateNewWallet(nil, name: nil)
          self.createWalletCoordinator.start()
        }
        self.navigationController.present(self.termViewController, animated: true, completion: nil)
        return
      }
      self.createWalletCoordinator.updateNewWallet(nil, name: nil)
      self.createWalletCoordinator.start()
    case .openImportWallet:
      KNCrashlyticsUtil.logCustomEvent(withName: "intro_import_wallet", customAttributes: nil)
      if UserDefaults.standard.bool(forKey: Constants.acceptedTermKey) == false {
        self.termViewController.nextAction = {
          self.importWalletCoordinator.start()
        }
        self.navigationController.present(self.termViewController, animated: true, completion: nil)
        return
      }
      self.importWalletCoordinator.start()
    case .openTermAndCondition:
      let url: String = "https://files.krystal.app/terms.pdf"
      self.navigationController.topViewController?.openSafari(with: url)
    case .openMigrationAlert:
      self.openMigrationAlert()
    }
  }

  fileprivate func openMigrationAlert() {
    let alert = KNPrettyAlertController(
      title: "Information".toBeLocalised(),
      message: "Have you installed the old KyberSwap iOS app? Read our guide on how to migrate your wallets from old app to this new app.".toBeLocalised(),
      secondButtonTitle: "OK".toBeLocalised(),
      firstButtonTitle: "No".toBeLocalised(),
      secondButtonAction: {
        self.navigationController.dismiss(animated: true) {
          let viewModel = KNMigrationTutorialViewModel()
          let tutorialVC = KNMigrationTutorialViewController(viewModel: viewModel)
          tutorialVC.delegate = self
          self.navigationController.present(tutorialVC, animated: true, completion: nil)
        }
      },
      firstButtonAction: {
      }
    )
    self.navigationController.present(alert, animated: true, completion: nil)
  }
}

extension KNLandingPageCoordinator: KNImportWalletCoordinatorDelegate {
  func importWalletCoordinatorDidSendRefCode(_ code: String) {
    self.delegate?.landingPageCoordinatorDidSendRefCode(code.uppercased())
  }
  
  func importWalletCoordinatorDidImport(wallet: Wallet, name: String?, importType: ImportWalletChainType, importMethod: StorageType) {
    self.addNewWallet(wallet, isCreate: false, name: name, isBackUp: true, importType: importType, importMethod: importMethod)
  }

  func importWalletCoordinatorDidClose() {
  }
}

extension KNLandingPageCoordinator: KNPasscodeCoordinatorDelegate {
  func passcodeCoordinatorDidCancel() {
    self.passcodeCoordinator.stop { }
  }

  func passcodeCoordinatorDidEvaluatePIN() {
    self.passcodeCoordinator.stop { }
  }

  func passcodeCoordinatorDidCreatePasscode() {
    guard let wallet = self.newWallet else { return }
    self.navigationController.topViewController?.displayLoading()
    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.25) {
      self.navigationController.topViewController?.hideLoading()
      self.delegate?.landingPageCoordinator(import: wallet)
    }
  }
}

extension KNLandingPageCoordinator: KNCreateWalletCoordinatorDelegate {
  func createWalletCoordinatorDidSendRefCode(_ code: String) {
    self.delegate?.landingPageCoordinatorDidSendRefCode(code.uppercased())
  }
  
  func createWalletCoordinatorDidClose() {
  }

  func createWalletCoordinatorCancelCreateWallet(_ wallet: Wallet) {
    self.navigationController.popViewController(animated: true) {
      self.delegate?.landingPageCoordinator(remove: wallet)
    }
  }

  func createWalletCoordinatorDidCreateWallet(_ wallet: Wallet?, name: String?, isBackUp: Bool) {
    guard let wallet = wallet else { return }
    self.addNewWallet(wallet, isCreate: true, name: name, isBackUp: isBackUp, importType: .multiChain, importMethod: .seeds)
  }
}

extension KNLandingPageCoordinator: KNMigrationTutorialViewControllerDelegate {
  func kMigrationTutorialViewControllerDidClickKyberSupportContact(_ controller: KNMigrationTutorialViewController) {
    if MFMailComposeViewController.canSendMail() {
      let emailVC = MFMailComposeViewController()
      emailVC.mailComposeDelegate = self
      emailVC.setToRecipients(["support@kyberswap.com"])
      self.navigationController.present(emailVC, animated: true, completion: nil)
    } else {
      let message = NSLocalizedString(
        "please.send.your.request.to.support",
        value: "Please send your request to support@kyberswap.com",
        comment: ""
      )
      self.navigationController.showWarningTopBannerMessage(with: "", message: message, time: 1.5)
    }
  }
}

extension KNLandingPageCoordinator: MFMailComposeViewControllerDelegate {
  func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
    controller.dismiss(animated: true, completion: nil)
  }
}
