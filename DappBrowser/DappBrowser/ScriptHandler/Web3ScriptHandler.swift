//
//  Web3ScriptHandler.swift
//  DappBrowser
//
//  Created by Tung Nguyen on 14/12/2022.
//

import Foundation
import WebKit
import WalletCore
import TrustWeb3Provider
import KrystalWallets
import BaseWallet
import AppState
import CryptoSwift

class Web3ScriptHandler: NSObject, WKScriptMessageHandler {
    
    var viewController: UIViewController?
    var webview: WKWebView!
    
    var wallet: KWallet?
    var current: TrustWeb3Provider = TrustWeb3Provider(config: .init(ethereum: ethereumConfigs[0]))
    var cosmosChains = ["osmosis-1", "cosmoshub", "cosmoshub-4", "kava_2222-10", "evmos_9001-2"]
    var currentCosmosChain = "osmosis-1"
    
    var cosmosCoin: CoinType {
        switch currentCosmosChain {
        case "osmosis-1":
            return .osmosis
        case "cosmoshub", "cosmoshub-4":
            return .cosmos
        case "kava_2222-10":
            return .kava
        case "evmos_9001-2":
            return .nativeEvmos
        default:
            fatalError("no coin found for the current config")
        }
    }
    
    var providers: [Int: TrustWeb3Provider] = {
        var result = [Int: TrustWeb3Provider]()
        ethereumConfigs.forEach {
            result[$0.chainId] = TrustWeb3Provider(config: .init(ethereum: $0))
        }
        return result
    }()

    static var ethereumConfigs = ChainType.allCases.map { chain in
        return TrustWeb3Provider.Config.EthereumConfig(
            address: chain.customRPC().proxyAddress,
            chainId: chain.getChainId(),
            rpcUrl: chain.customRPC().endpoint
        )
    }
    
    override init() {
        super.init()
        reloadWallet()
    }
    
    func reloadWallet() {
        wallet = WalletManager.shared.getWallet(id: AppState.shared.currentAddress.walletID)
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        let json = message.json
        print(json)
        guard
            let method = extractMethod(json: json),
            let id = json["id"] as? Int64,
            let network = extractNetwork(json: json)
        else {
            return
        }
        switch method {
        case .requestAccounts:
            if network == .cosmos {
                if let chainId = extractCosmosChainId(json: json), currentCosmosChain != chainId {
                    currentCosmosChain = chainId
                }
            }

            handleRequestAccounts(network: network, id: id)
        case .signTransaction:
            switch network {
            case .cosmos:
                let input: CosmosSigningInput
                if let params = json["object"] as? [String: Any] {
                    input = self.cosmosSigningInputAmino(params: params)!
                } else {
                    fatalError("data is missing")
                }
                handleSignTransaction(network: network, id: id) { [weak webview] in
                    let output: CosmosSigningOutput = AnySigner.sign(input: input, coin: self.cosmosCoin)
                    guard let signature = self.cosmosSignature(from: input, output) else { return }
                    webview?.tw.send(network: network, result: signature, to: id)
                }
//            case .aptos:
//                if var params = extractAptosParams(json: json) {
//                    aptosSigningInput(params: params) { [weak self, webview] input in
//                        switch input {
//                        case .failure(let error):
//                            print(error.localizedDescription)
//                        case .success(let input):
//                            self?.handleSignTransaction(network: network, id: id) { [weak webview] in
//                                let output: AptosSigningOutput = AnySigner.sign(input: input, coin: .aptos)
//                                let signature = try! JSONSerialization.jsonObject(with: output.json.data(using: .utf8)!) as! [String: Any]
//                                params["signature"] = signature
//
//                                if #available(iOS 13.0, *) {
//                                    let data = try! JSONSerialization.data(withJSONObject: params, options: [.withoutEscapingSlashes])
//                                    webview?.tw.send(network: network, result: data.hexString, to: id)
//                                } else {
//                                    let data = try! JSONSerialization.data(withJSONObject: params, options: [.fragmentsAllowed])
//                                    webview?.tw.send(network: network, result: data.hexString, to: id)
//                                }
//
//                            }
//                        }
//                    }
//                }
            default: break
            }


        case .signRawTransaction:
            switch network {
            case .solana:
                guard let raw = extractRaw(json: json) else {
                    print("raw json is missing")
                    return
                }

                handleSignSolanaRawTransaction(id: id, raw: raw)
//            case .cosmos:
//                let input: CosmosSigningInput
//                if let params = json["object"] as? [String: Any] {
//                    input = self.cosmosSigningInputDirect(params: params)!
//                } else {
//                    fatalError("data is missing")
//                }
//
//                handleSignTransaction(network: network, id: id) { [weak webview] in
//                    let output: CosmosSigningOutput = AnySigner.sign(input: input, coin: self.cosmosCoin)
//                    guard let signature = self.cosmosSignature(from: input, output) else { return }
//                    webview?.tw.send(network: .cosmos, result: signature, to: id)
//                }
            default:
                print("\(network.rawValue) doesn't support signRawTransaction")
                break
            }
        case .signMessage:
            guard let data = extractMessage(json: json) else {
                print("data is missing")
                return
            }
            switch network {
            case .ethereum:
                handleSignMessage(id: id, data: data, addPrefix: true)
            case .solana, .aptos:
                handleSignMessage(id: id, network: network, data: data)
            case .cosmos:
                handleCosmosSignMessage(id: id, data: data)
            }
        case .signPersonalMessage:
            guard let data = extractMessage(json: json) else {
                print("data is missing")
                return
            }
            handleSignMessage(id: id, data: data, addPrefix: true)
        case .signTypedMessage:
            guard
                let data = extractMessage(json: json),
                let raw = extractRaw(json: json)
            else {
                print("data or raw json is missing")
                return
            }
            handleSignTypedMessage(id: id, data: data, raw: raw)
        case .sendTransaction:
            switch network {
            case .cosmos:
                guard
                    let mode = extractMode(json: json),
                    let raw = extractRaw(json: json)
                else {
                    print("mode or raw json is missing")
                    return
                }
                handleCosmosSendTransaction(id, mode, raw)
            case .aptos:
                guard let object = json["object"] as? [String: Any], let tx = object["tx"] as? [String: Any] else {
                    return
                }
                handleAptosSendTransaction(tx, id: id)
            default:
                break
            }

        case .ecRecover:
            guard let tuple = extractSignature(json: json) else {
                print("signature or message is missing")
                return
            }
            let recovered = ecRecover(signature: tuple.signature, message: tuple.message) ?? ""
            print(recovered)
            DispatchQueue.main.async {
                self.webview.tw.send(network: .ethereum, result: recovered, to: id)
            }
        case .addEthereumChain:
            guard let (chainId, name, rpcUrls) = extractChainInfo(json: json) else {
                print("extract chain info error")
                return
            }
            if providers[chainId] != nil {
                handleSwitchEthereumChain(id: id, chainId: chainId)
            } else {
                handleAddChain(id: id, name: name, chainId: chainId, rpcUrls: rpcUrls)
            }
        case .switchChain, .switchEthereumChain:
            switch network {
            case .ethereum:
                guard
                    let chainId = extractEthereumChainId(json: json)
                else {
                    print("chain id is invalid")
                    return
                }
                handleSwitchEthereumChain(id: id, chainId: chainId)
            case .solana, .aptos:
                fatalError()
            case .cosmos:
                guard
                    let chainId = extractCosmosChainId(json: json)
                else {
                    print("chain id is invalid")
                    return
                }
                handleSwitchCosmosChain(id: id, chainId: chainId)
            }
        default:
            break
        }
    }
    
    func connectSolanaWallet(network: ProviderNetwork, id: Int64) {
        guard let wallet = wallet else {
            return
        }
        guard let address = WalletManager.shared.address(wallet: wallet, forCoin: .solana) else {
            return
        }
        webview?.tw.set(network: network.rawValue, address: address)
        webview?.tw.send(network: network, results: [address], to: id)
    }

    func handleRequestAccounts(network: ProviderNetwork, id: Int64) {
        guard let wallet = wallet else {
            return
        }
//        let alert = UIAlertController(
//            title: webview.title,
//            message: "\(webview.url?.host! ?? "Website") would like to connect your account",
//            preferredStyle: .alert
//        )
//        alert.addAction(UIAlertAction(title: "Cancel", style: .destructive, handler: { [weak webview] _ in
//            webview?.tw.send(network: network, error: "Canceled", to: id)
//        }))
//        alert.addAction(UIAlertAction(title: "Connect", style: .default, handler: { [weak webview] _ in
            switch network {
            case .ethereum:
                switch AppState.shared.currentChain {
                case .solana:
                    self.connectSolanaWallet(network: network, id: id)
                default:
                    guard let address = WalletManager.shared.address(wallet: wallet, forCoin: .ethereum) else {
                        return
                    }
                    webview?.tw.set(network: network.rawValue, address: address)
                    webview?.tw.send(network: network, results: [address], to: id)
                }
                
            case .solana:
                self.connectSolanaWallet(network: network, id: id)
            case .cosmos:
                guard let wallet = self.wallet else {
                    return
                }
                guard let privateKey = WalletManager.shared.privateKey(wallet: wallet, forCoin: self.cosmosCoin) else {
                    return
                }
                let pubKey = privateKey.getPublicKeySecp256k1(compressed: true).description
                let address = WalletManager.shared.address(wallet: wallet, forCoin: self.cosmosCoin)
                let json = try! JSONSerialization.data(
                    withJSONObject: ["pubKey": pubKey, "address": address]
                )
                let jsonString = String(data: json, encoding: .utf8)!
                webview?.tw.send(network: network, result: jsonString, to: id)
            case .aptos:
                return
//            case .aptos:
//                guard let wallet = self.wallet else {
//                    return
//                }
//                guard let privateKey = WalletManager.shared.privateKey(wallet: wallet, forCoin: .aptos) else {
//                    return
//                }
//                let pubKey = privateKey.getPublicKeySecp256k1(compressed: true).description
//                let address = WalletManager.shared.address(wallet: wallet, forCoin: .aptos)
//                let json = try! JSONSerialization.data(
//                    withJSONObject: ["publicKey": pubKey, "address": address]
//                )
//                let jsonString = String(data: json, encoding: .utf8)!
//                webview?.tw.send(network: network, result: jsonString, to: id)
            }

//        }))
//        viewController?.present(alert, animated: true, completion: nil)
    }

    func handleSignMessage(id: Int64, data: Data, addPrefix: Bool) {
//        let alert = UIAlertController(
//            title: "Sign Ethereum Message",
//            message: addPrefix ? String(data: data, encoding: .utf8) ?? "" : data.hexString,
//            preferredStyle: .alert
//        )
//        alert.addAction(UIAlertAction(title: "Cancel", style: .destructive, handler: { [weak webview] _ in
//            webview?.tw.send(network: .ethereum, error: "Canceled", to: id)
//        }))
//        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak webview] _ in
//            let signed = self.signMessage(data: data, addPrefix: addPrefix)
//            webview?.tw.send(network: .ethereum, result: signed.hexString, to: id)
//        }))
//        viewController?.present(alert, animated: true, completion: nil)
//
        guard let viewController = viewController else { return }
        guard let wallet = wallet, let address = WalletManager.shared.address(walletID: wallet.id, addressType: .evm) else { return }
        guard let webView = webview else { return }
        let pageInfo = WebPageInfo(name: webView.title, url: webView.url?.absoluteString)
        SignMessagePopup.show(on: viewController, address: address, message: data, pageInfo: pageInfo) { signature in
            self.webview?.tw.send(network: .ethereum, result: signature.hexString, to: id)
        } onCancelled: {
            self.webview?.tw.send(network: .ethereum, error: "Canceled", to: id)
        }

    }

    func handleSignTypedMessage(id: Int64, data: Data, raw: String) {
        let alert = UIAlertController(
            title: "Sign Typed Message",
            message: raw,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .destructive, handler: { [weak webview] _ in
            webview?.tw.send(network: .ethereum, error: "Canceled", to: id)
        }))
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak webview] _ in
            let signed = self.signMessage(data: data, addPrefix: false)
            webview?.tw.send(network: .ethereum, result: "0x" + signed.hexString, to: id)
        }))
        viewController?.present(alert, animated: true, completion: nil)
    }

    func handleSignMessage(id: Int64, network: ProviderNetwork, data: Data) {
        let alert = UIAlertController(
            title: "Sign Solana Message",
            message: String(data: data, encoding: .utf8) ?? data.hexString,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .destructive, handler: { [weak webview] _ in
            webview?.tw.send(network: .solana, error: "Canceled", to: id)
        }))
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak webview] _ in
//            let coin: CoinType = network == .solana ? .solana : .aptos
            if let wallet = self.wallet, let privateKey = WalletManager.shared.privateKey(wallet: wallet, forCoin: .solana) {
                let signed = privateKey.sign(digest: data, curve: .ed25519)!
                webview?.tw.send(network: network, result: "0x" + signed.hexString, to: id)
            }
        }))
        viewController?.present(alert, animated: true, completion: nil)
    }

    func handleCosmosSignMessage(id: Int64, data: Data) {
        let alert = UIAlertController(
            title: "Sign Cosmos Message",
            message: String(data: data, encoding: .utf8) ?? data.hexString,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .destructive, handler: { [weak webview] _ in
            webview?.tw.send(network: .solana, error: "Canceled", to: id)
        }))
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak webview] _ in
            guard let input: CosmosSigningInput = self.cosmosSigningInputMessage(data: data) else { return }
            let output: CosmosSigningOutput = AnySigner.sign(input: input, coin: self.cosmosCoin)
            guard let signature = self.cosmosSignature(from: input, output) else { return }
            webview?.tw.send(network: .cosmos, result: signature, to: id)
        }))
        viewController?.present(alert, animated: true, completion: nil)
    }

    func handleSignTransaction(network: ProviderNetwork, id: Int64, onSign: @escaping (() -> Void)) {
        let alert = UIAlertController(
            title: "Sign Transaction",
            message: "Smart contract call",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .destructive, handler: { [weak webview] _ in
            webview?.tw.send(network: network, error: "Canceled", to: id)
        }))
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
            onSign()
        }))
        viewController?.present(alert, animated: true, completion: nil)
    }

    func handleSignSolanaRawTransaction(id: Int64, raw: String) {
        let alert = UIAlertController(
            title: "Sign Transaction",
            message: raw,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .destructive, handler: { [weak webview] _ in
            webview?.tw.send(network: .solana, error: "Canceled", to: id)
        }))
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak webview] _ in
            guard let decoded = Base58.decodeNoCheck(string: raw) else { return }
            guard let wallet = self.wallet, let privateKey = WalletManager.shared.privateKey(wallet: wallet, forCoin: .solana) else {
                return
            }
            guard let signature = privateKey.sign(digest: decoded, curve: .ed25519) else { return }
            let signatureEncoded = Base58.encodeNoCheck(data: signature)
            webview?.tw.send(network: .solana, result: signatureEncoded, to: id)
        }))
        viewController?.present(alert, animated: true, completion: nil)
    }

    func handleAddChain(id: Int64, name: String, chainId: Int, rpcUrls: [String]) {
        let alert = UIAlertController(
            title: "Add: " + name,
            message: "ChainId: \(chainId)\nRPC: \(rpcUrls.joined(separator: "\n"))",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .destructive, handler: { [weak webview] _ in
            webview?.tw.send(network: .ethereum, error: "Canceled", to: id)
        }))
        alert.addAction(UIAlertAction(title: "Add", style: .default, handler: { [weak self] _ in
            guard let `self` = self else { return }
            self.providers[chainId] = TrustWeb3Provider.createEthereum(address: self.current.config.ethereum.address, chainId: chainId, rpcUrl: rpcUrls[0])
            print("\(name) added")
            self.webview.tw.sendNull(network: .ethereum, id: id)
        }))
        viewController?.present(alert, animated: true, completion: nil)
    }

    func handleSwitchEthereumChain(id: Int64, chainId: Int) {
        guard let provider = providers[chainId] else {
            alert(title: "Error", message: "Unknown chain id: \(chainId)")
            webview.tw.send(network: .ethereum, error: "Unknown chain id", to: id)
            return
        }

        let currentConfig = current.config.ethereum
        let switchToConfig = provider.config.ethereum

        if chainId == currentConfig.chainId {
            webview.tw.sendNull(network: .ethereum, id: id)
        } else {
            let alert = UIAlertController(
                title: "Switch Chain",
                message: "ChainId: \(chainId)\nRPC: \(switchToConfig.rpcUrl)",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Cancel", style: .destructive, handler: { [weak webview] _ in
                webview?.tw.send(network: .ethereum, error: "Canceled", to: id)
            }))
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak self] _ in
                guard let `self` = self else { return }
                self.current = provider
                let provider = TrustWeb3Provider.createEthereum(
                    address: switchToConfig.address,
                    chainId: switchToConfig.chainId,
                    rpcUrl: switchToConfig.rpcUrl
                )
                self.webview.tw.set(config: provider.config)
                self.webview.tw.emitChange(chainId: chainId)
                self.webview.tw.sendNull(network: .ethereum, id: id)
            }))
            viewController?.present(alert, animated: true, completion: nil)
        }
    }

    func handleSwitchCosmosChain(id: Int64, chainId: String) {
        if !cosmosChains.contains(chainId) {
            alert(title: "Error", message: "Unknown chain id: \(chainId)")
            webview.tw.send(network: .ethereum, error: "Unknown chain id", to: id)
            return
        }

        if currentCosmosChain == chainId {
            print("No need to switch, already on chain \(chainId)")
            webview.tw.sendNull(network: .cosmos, id: id)
        } else {
            let alert = UIAlertController(
                title: "Switch Chain",
                message: "ChainId: \(chainId)",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Cancel", style: .destructive, handler: { [weak webview] _ in
                webview?.tw.send(network: .ethereum, error: "Canceled", to: id)
            }))
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak self] _ in
                guard let `self` = self else { return }
                self.currentCosmosChain = chainId
                self.webview.tw.sendNull(network: .cosmos, id: id)
            }))
            viewController?.present(alert, animated: true, completion: nil)
        }
    }

    func handleAptosSendTransaction(_ tx: [String: Any], id: Int64) {
        let url = URL(string: "https://fullnode.devnet.aptoslabs.com/v1/transactions")!
        tx.postRequest(to: url) { (result: Result<[String: Any], Error>) -> Void in
            switch result {
            case .failure(let error):
                self.webview.tw.send(network: .aptos, error: error.localizedDescription, to: id)
            case .success(let json):
                if let _ = json["error_code"] as? String, let message = json["message"] as? String {
                    self.webview.tw.send(network: .aptos, error: message, to: id)
                    return
                }
                let hash = json["hash"] as! String
                self.webview.tw.send(network: .aptos, result: hash, to: id)
            }
        }
    }

    func handleCosmosSendTransaction(_ id: Int64,_ mode: String,_ raw: String) {
        let url = URL(string: "https://lcd-osmosis.keplr.app/cosmos/tx/v1beta1/txs")!
        ["mode": mode, "tx_bytes": raw].postRequest(to: url) { (result: Result<[String: Any], Error>) -> Void in
            switch result {
            case .failure(let error):
                self.webview.tw.send(network: .cosmos, error: error.localizedDescription, to: id)
            case .success(let json):
                guard let response = json["tx_response"] as? [String: Any],
                      let txHash = response["txhash"] as? String else {
                    self.webview.tw.send(network: .cosmos, error: "error json parsing", to: id)
                    return
                }
                self.webview.tw.send(network: .cosmos, result: txHash, to: id)
            }
        }
    }

    func alert(title: String, message: String) {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(.init(title: "OK", style: .default, handler: nil))
        viewController?.present(alert, animated: true, completion: nil)
    }

    private func extractMethod(json: [String: Any]) -> DAppMethod? {
        guard
            let name = json["name"] as? String
        else {
            return nil
        }
        return DAppMethod(rawValue: name)
    }

    private func extractNetwork(json: [String: Any]) -> ProviderNetwork? {
        guard
            let network = json["network"] as? String
        else {
            return nil
        }
        return ProviderNetwork(rawValue: network)
    }

    private func extractMessage(json: [String: Any]) -> Data? {
        guard
            let params = json["object"] as? [String: Any],
            let string = params["data"] as? String,
            let data = Data(hexString: string)
        else {
            return nil
        }
        return data
    }

    private func extractSignature(json: [String: Any]) -> (signature: Data, message: Data)? {
        guard
            let params = json["object"] as? [String: Any],
            let signature = params["signature"] as? String,
            let message = params["message"] as? String
        else {
            return nil
        }
        return (Data(hexString: signature)!, Data(hexString: message)!)
    }

    private func extractChainInfo(json: [String: Any]) ->(chainId: Int, name: String, rpcUrls: [String])? {
        guard
            let params = json["object"] as? [String: Any],
            let string = params["chainId"] as? String,
            let chainId = Int(String(string.dropFirst(2)), radix: 16),
            let name = params["chainName"] as? String,
            let urls = params["rpcUrls"] as? [String]
        else {
            return nil
        }
        return (chainId: chainId, name: name, rpcUrls: urls)
    }

    private func extractCosmosChainId(json: [String: Any]) -> String? {
        guard
            let params = json["object"] as? [String: Any],
            let chainId = params["chainId"] as? String
        else {
            return nil
        }
        return chainId
    }

    private func extractEthereumChainId(json: [String: Any]) -> Int? {
        guard
            let params = json["object"] as? [String: Any],
            let string = params["chainId"] as? String,
            let chainId = Int(String(string.dropFirst(2)), radix: 16),
            chainId > 0
        else {
            return nil
        }
        return chainId
    }

    private func extractRaw(json: [String: Any]) -> String? {
        guard
            let params = json["object"] as? [String: Any],
            let raw = params["raw"] as? String
        else {
            return nil
        }
        return raw
    }

    private func extractMode(json: [String: Any]) -> String? {
        guard
            let params = json["object"] as? [String: Any],
            let mode = params["mode"] as? String
        else {
            return nil
        }

        switch mode {
          case "async":
            return "BROADCAST_MODE_ASYNC"
          case "block":
            return "BROADCAST_MODE_BLOCK"
          case "sync":
            return "BROADCAST_MODE_SYNC"
          default:
            return "BROADCAST_MODE_UNSPECIFIED"
        }
    }

//    private func extractAptosParams(json: [String: Any]) -> [String: Any]? {
//        guard let object = json["object"] as? [String: Any], let payload = object["data"] as? [String: Any] else {
//            return nil
//        }
//
//        guard let wallet = wallet else {
//            return nil
//        }
//
//        guard let address = WalletManager.shared.address(wallet: wallet, forCoin: .aptos) else {
//            return nil
//        }
//
//        return [
//            "expiration_timestamp_secs": "3664390082",
//            "gas_unit_price": "100",
//            "max_gas_amount": "3296766",
//            "payload": payload,
//            "sender": address,
//            "sequence_number": "34"
//        ]
//    }

    private func signMessage(data: Data, addPrefix: Bool = true) -> Data {
        guard let wallet = wallet else { return Data() }
        guard let privateKey = WalletManager.shared.privateKey(wallet: wallet, forCoin: .ethereum) else {
            return Data()
        }
        
        let message = (addPrefix ? ethereumMessage(for: data) : data).sha3(.keccak256)
        var signed =  privateKey.sign(digest: message, curve: .secp256k1)!
        signed[64] += 27
        return signed
    }

    private func ecRecover(signature: Data, message: Data) -> String? {
        let data = ethereumMessage(for: message)
        let hash = Hash.keccak256(data: data)
        guard let publicKey = PublicKey.recover(signature: signature, message: hash),
              PublicKey.isValid(data: publicKey.data, type: publicKey.keyType) else {
            return nil
        }
        return CoinType.ethereum.deriveAddressFromPublicKey(publicKey: publicKey).lowercased()
    }

    private func ethereumMessage(for data: Data) -> Data {
        let prefix = "\u{19}Ethereum Signed Message:\n\(data.count)".data(using: .utf8)!
        return prefix + data
    }

//    private func aptosSigningInput(params: [String: Any], completion: @escaping ((Result<AptosSigningInput, Error>) -> Void)) {
//        guard let wallet = wallet else {
//            return
//        }
//
//        guard let privateKey = WalletManager.shared.privateKey(wallet: wallet, forCoin: .aptos) else {
//            return
//        }
//
//        params.postRequest(to: URL(string: "https://fullnode.devnet.aptoslabs.com/v1/transactions/encode_submission")!) { (result: Result<Data, Error>) -> Void in
//            switch result {
//            case .failure(let error):
//                completion(.failure(error))
//            case .success(let data):
//                let input = AptosSigningInput.with {
//                    $0.anyEncoded = String(data: data, encoding: .utf8)!.replacingOccurrences(of: "\"", with: "")
//                    $0.privateKey = privateKey.data
//                }
//                completion(.success(input))
//            }
//        }
//    }

//    private func cosmosSigningInputDirect(params: [String: Any]) -> CosmosSigningInput? {
//        guard let wallet = wallet else { return nil }
//        guard let privateKey = WalletManager.shared.privateKey(wallet: wallet, forCoin: cosmosCoin) else { return nil }
//        guard let accountNumberStr = params["account_number"] as? String, let accountNumber = UInt64(accountNumberStr) else { return nil }
//        guard let chainID = params["chain_id"] as? String else { return nil }
//        guard let authInfoBytesHex = params["auth_info_bytes"] as? String else { return nil }
//        guard let authInfoBytes = Data(hexString: authInfoBytesHex) else { return nil }
//        guard let bodyBytesHex = params["body_bytes"] as? String else { return nil }
//        guard let bodyBytes = Data(hexString: bodyBytesHex) else { return nil }
//
//        return CosmosSigningInput.with {
//            $0.accountNumber = accountNumber
//            $0.chainID = chainID
//            $0.messages = [
//                CosmosMessage.with {
//                    $0.signDirectMessage = CosmosMessage.SignDirect.with {
//                        $0.authInfoBytes = authInfoBytes
//                        $0.bodyBytes = bodyBytes
//                    }
//                }
//            ]
//            $0.signingMode = .protobuf
//            $0.privateKey = privateKey.data
//        }
//    }

    private func cosmosSigningInputAmino(params: [String: Any]) -> CosmosSigningInput? {
        guard let wallet = wallet else { return nil }
        guard let privateKey = WalletManager.shared.privateKey(wallet: wallet, forCoin: cosmosCoin) else { return nil }
        guard let accountNumberStr = params["account_number"] as? String, let accountNumber = UInt64(accountNumberStr) else { return nil }
        guard let chainID = params["chain_id"] as? String else { return nil }
        guard let fee = params["fee"] as? [String: Any] else { return nil }
        guard let gasStr = fee["gas"] as? String, let gas = UInt64(gasStr) else { return nil }
        guard let memo = params["memo"] as? String else { return nil }
        guard let sequenceStr = params["sequence"] as? String, let sequence = UInt64(sequenceStr) else { return nil }
        guard let msgs = params["msgs"] as? [[String: Any]] else { return nil }

        guard let feeAmounts = fee["amount"] as? [[String: Any]] else {
            return nil
        }

        return CosmosSigningInput.with {
            $0.signingMode = .json
            $0.accountNumber = accountNumber
            $0.chainID = chainID
            $0.memo = memo
            $0.sequence = sequence
            $0.messages = parseCosmosMessages(msgs)
            $0.fee = CosmosFee.with {
                $0.gas = gas
                $0.amounts = parseCosmosAmounts(feeAmounts)
            }
            $0.privateKey = privateKey.data
        }
    }

    private func cosmosSigningInputMessage(data: Data) -> CosmosSigningInput? {
        guard let wallet = wallet else { return nil }
        guard let privateKey = WalletManager.shared.privateKey(wallet: wallet, forCoin: cosmosCoin) else { return nil }

        let valueMap = [
            "signer": WalletManager.shared.address(wallet: wallet, forCoin: cosmosCoin),
            "value": data.base64EncodedString()
        ]
        guard let valueEncoded = try? JSONSerialization.data(withJSONObject: valueMap) else { return nil }
        guard let value = String(data: valueEncoded, encoding: .utf8) else { return nil }

        return CosmosSigningInput.with {
            $0.accountNumber = UInt64(0)
            $0.chainID = ""
            $0.memo = ""
            $0.sequence = UInt64(0)
            $0.messages = [
                CosmosMessage.with {
                    $0.rawJsonMessage = CosmosMessage.RawJSON.with {
                        $0.type = "sign/MsgSignData"
                        $0.value = value
                    }
                }
            ]
            $0.fee = CosmosFee.with {
                $0.gas = UInt64(0)
                $0.amounts = []
            }
            $0.privateKey =  privateKey.data
        }
    }

    private func parseCosmosAmounts(_ amounts: [[String: Any]]) -> [CosmosAmount] {
        return amounts.compactMap { feeAmount -> CosmosAmount? in
            guard
                let amount = feeAmount["amount"] as? String,
                let denom = feeAmount["denom"] as? String
            else {
                return nil
            }
            return CosmosAmount.with {
                $0.amount = amount
                $0.denom = denom
            }
        }
    }

    private func parseCosmosMessages(_ messages: [[String: Any]]) -> [CosmosMessage] {
        messages.compactMap { params -> CosmosMessage? in
            guard let type = params["type"] as? String else { return nil }
            guard let value = params["value"] as? [String: Any] else { return nil }
            guard
                let data = try? JSONSerialization.data(withJSONObject: value, options: []),
                let jsonString = String(data: data, encoding: .utf8)
            else {
                return nil
            }

            return CosmosMessage.with {
                $0.rawJsonMessage = CosmosMessage.RawJSON.with {
                    $0.type = type
                    $0.value = jsonString
                }
            }
        }
    }

    private func cosmosSignature(from input: CosmosSigningInput, _ output: CosmosSigningOutput) -> String? {
        let pubkey = PrivateKey(data: input.privateKey)!.getPublicKeySecp256k1(compressed: true)
        let signature: [String: Any] = [
            "pub_key": [
                "type": self.cosmosCoin == .nativeEvmos ? "ethermint/PubKeyEthSecp256k1" : "tendermint/PubKeySecp256k1", // Evmos might be different
                "value": pubkey.data.base64EncodedString()
            ],
            "signature": output.signature.base64EncodedString()
        ]
        guard let signatureEncoded = try? JSONSerialization.data(withJSONObject: signature) else { return nil }
        guard let signatureResult = String(data: signatureEncoded, encoding: .utf8) else { return nil }

        return signatureResult
    }
    
}


extension Dictionary where Key == String {
    func postRequest<T: Any>(to rpc: URL, completion: @escaping (Result<T, Error>) -> Void) {
        do {
            let data = try JSONSerialization.data(withJSONObject: self, options: [])
            data.postRequest(to: rpc, completion: completion)
        } catch(let error) {
            print("error is \(error.localizedDescription)")
            completion(.failure(error))
        }
    }
}

extension Data {
    func postRequest<T: Any>(to rpc: URL, contentType: String = "application/json", completion: @escaping (Result<T, Error>) -> Void) {
        var request = URLRequest(url: rpc)
        request.httpMethod = "POST"
        request.httpBody = self
        request.addValue(contentType, forHTTPHeaderField: "Content-Type")

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("error is \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            guard
                let data = data,
                let result = (try? JSONSerialization.jsonObject(with: data) as? T) ?? data as? T
            else {
                return
            }
            DispatchQueue.main.async {
                completion(.success(result))
            }
        }
        task.resume()
    }

}
