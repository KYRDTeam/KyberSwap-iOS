//
//  AllChains.swift
//  BaseWallet
//
//  Created by Tung Nguyen on 13/10/2022.
//

import Foundation

public struct AllChains {
  public static let ethMainnetPRC = CustomRPC(
    chainID: 1,
    type: "ERC20",
    name: "Ethereum",
    symbol: "Mainnet",
    endpoint: "https://eth-mainnet.nodereal.io/v1/1659dfb40aa24bbb8153a677b98064d7",
    endpointKyber: "https://ethereum.kyber.network/v1/mainnet/geth?appId=prod-krystal-ios",
    endpointAlchemy: "https://rpc.ankr.com/eth",
    etherScanEndpoint: "https://etherscan.io/",
    webScanName: "Etherscan",
    ensAddress: "0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e",
    wrappedAddress: "0x6172afc8c00c46e0d07ce3af203828198194620a",
    apiEtherscanEndpoint: "https://api.etherscan.io/",
    proxyAddress: "0x70270C228c5B4279d1578799926873aa72446CcD",
    quoteTokenAddress: "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
    chainIcon: "chain_eth_icon",
    quoteToken: "ETH",
    apiChainPath: "ethereum"
  )

  public static let ethRoptenPRC = CustomRPC(
    chainID: 3,
    type: "ERC20",
    name: "Ethereum-Ropsten",
    symbol: "Ropsten",
    endpoint: "https://ropsten.infura.io/v3/" + NodeConfig.infuraKey,
    endpointKyber: "https://ropsten.infura.io/v3/" + NodeConfig.infuraKey,
    endpointAlchemy: "https://eth-ropsten.alchemyapi.io/v2/" + NodeConfig.alchemyRopstenKey,
    etherScanEndpoint: "https://ropsten.etherscan.io/",
    webScanName: "Etherscan",
    ensAddress: "0x112234455c3a32fd11230c42e7bccd4a84e02010",
    wrappedAddress: "0x665d34f192f4940da4e859ff7768c0a80ed3ae10",
    apiEtherscanEndpoint: "https://api-ropsten.etherscan.io/",
    proxyAddress: "0xf351Dd5EC89e5ac6c9125262853c74E714C1d56a",
    quoteTokenAddress: "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
    chainIcon: "chain_eth_icon",
    quoteToken: "ETH",
    apiChainPath: "ropsten"
  )

  public static let ethStaggingPRC = CustomRPC(
    chainID: 1,
    type: "ERC20",
    name: "Ethereum",
    symbol: "Mainnet",
    endpoint: "https://eth-mainnet.nodereal.io/v1/1659dfb40aa24bbb8153a677b98064d7",
    endpointKyber: "https://ethereum.kyber.network/v1/mainnet/geth?appId=prod-krystal-ios",
    endpointAlchemy: "https://rpc.ankr.com/eth",
    etherScanEndpoint: "https://etherscan.io/",
    webScanName: "Etherscan",
    ensAddress: "0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e",
    wrappedAddress: "0x6172afc8c00c46e0d07ce3af203828198194620a",
    apiEtherscanEndpoint: "https://api.etherscan.io/",
    proxyAddress: "0x70270C228c5B4279d1578799926873aa72446CcD",
    quoteTokenAddress: "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
    chainIcon: "chain_eth_icon",
    quoteToken: "ETH",
    apiChainPath: "ethereum"
  )
  
  public static let bscMainnetPRC = CustomRPC(
    chainID: 56,
    type: "BEP20",
    name: "BNB Smart Chain",
    symbol: "MainnetBSC",
    endpoint: "https://bsc-dataseed.binance.org/",
    endpointKyber: "https://bsc-dataseed2.defibit.io/",
    endpointAlchemy: "https://bsc-dataseed1.binance.org/",
    etherScanEndpoint: "https://bscscan.com/",
    webScanName: "BSCscan",
    ensAddress: "",
    wrappedAddress: "0x465661625B3B96b102a49e07E2Eb31cC9F5cE58B",
    apiEtherscanEndpoint: "https://api.bscscan.com/",
    proxyAddress: "0x051DC16b2ECB366984d1074dCC07c342a9463999",
    quoteTokenAddress: "0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
    chainIcon: "chain_bsc_icon",
    quoteToken: "BNB",
    apiChainPath: "bsc"
  )

  public static let bscRoptenPRC = CustomRPC(
    chainID: 97,
    type: "BEP20",
    name: "BSC-ropsten",
    symbol: "RopstenBSC",
    endpoint: "https://data-seed-prebsc-1-s1.binance.org:8545/",
    endpointKyber: "https://data-seed-prebsc-2-s1.binance.org:8545/",
    endpointAlchemy: "https://data-seed-prebsc-1-s1.binance.org:8545/",
    etherScanEndpoint: "https://testnet.bscscan.com/",
    webScanName: "BSCscan",
    ensAddress: "",
    wrappedAddress: "0x813718C50df497BC136d5d6dfc0E0aDA8AB0C93e",
    apiEtherscanEndpoint: "https://api-testnet.bscscan.com/",
    proxyAddress: "0xA58573970cfFAd93309071cE9aff46b8A35eC62B",
    quoteTokenAddress: "0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
    chainIcon: "chain_bsc_icon",
    quoteToken: "BNB",
    apiChainPath: "bsctestnet"
  )

  public static let polygonMainnetPRC = CustomRPC(
    chainID: 137,
    type: "ERC20",
    name: "Polygon",
    symbol: "MaticMainnet",
    endpoint: "https://rpc.ankr.com/polygon/",
    endpointKyber: "https://matic-mainnet.chainstacklabs.com/",
    endpointAlchemy: "https://rpc-mainnet.maticvigil.com/",
    etherScanEndpoint: "https://polygonscan.com/",
    webScanName: "Polygonscan",
    ensAddress: "",
    wrappedAddress: "0xf351Dd5EC89e5ac6c9125262853c74E714C1d56a",
    apiEtherscanEndpoint: "https://api.polygonscan.com/",
    proxyAddress: "0x70270c228c5b4279d1578799926873aa72446ccd",
    quoteTokenAddress: "0xcccccccccccccccccccccccccccccccccccccccc",
    chainIcon: "chain_polygon_big_icon",
    quoteToken: "MATIC",
    apiChainPath: "polygon"
  )

  public static let polygonRoptenPRC = CustomRPC(
    chainID: 80001,
    type: "ERC20",
    name: "Polygon-Testnet",
    symbol: "MaticRopsten",
    endpoint: "https://rpc-mumbai.maticvigil.com/",
    endpointKyber: "https://rpc-mumbai.maticvigil.com/",
    endpointAlchemy: "https://rpc-mumbai.maticvigil.com/",
    etherScanEndpoint: "https://mumbai.polygonscan.com/",
    webScanName: "Polygonscan",
    ensAddress: "",
    wrappedAddress: "0xB8C6Ed80688a2674623D89A0AaBD3a87507B1868",
    apiEtherscanEndpoint: "https://api.polygonscan.com",
    proxyAddress: "0x6deaAe9d76991db2943064Bca84e00f63c46C0A3",
    quoteTokenAddress: "0xcccccccccccccccccccccccccccccccccccccccc",
    chainIcon: "chain_polygon_big_icon",
    quoteToken: "MATIC",
    apiChainPath: "mumbai"
  )

  public static let avalancheRoptenPRC = CustomRPC(
    chainID: 43113,
    type: "ARC20",
    name: "Avalanche-Testnet",
    symbol: "AVAX",
    endpoint: "https://api.avax-test.network/ext/bc/C/rpc",
    endpointKyber: "https://api.avax-test.network/ext/bc/C/rpc",
    endpointAlchemy: "https://api.avax-test.network/ext/bc/C/rpc",
    etherScanEndpoint: "https://cchain.explorer.avax-test.network/",
    webScanName: "CCscan",
    ensAddress: "",
    wrappedAddress: "",
    apiEtherscanEndpoint: "",
    proxyAddress: "0xAE0505c0C30Dc0EA077cDB4Ed1B2BB894D9c6B65",
    quoteTokenAddress: "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    chainIcon: "chain_avax_icon",
    quoteToken: "AVAX",
    apiChainPath: "fuji"
  )

  public static let avalancheMainnetPRC = CustomRPC(
    chainID: 43114,
    type: "ARC20",
    name: "Avalanche",
    symbol: "AVAX",
    endpoint: "https://api.avax.network/ext/bc/C/rpc",
    endpointKyber: "https://rpc.ankr.com/avalanche",
    endpointAlchemy: "https://api.avax.network/ext/bc/C/rpc",
    etherScanEndpoint: "https://cchain.explorer.avax.network/",
    webScanName: "CCscan",
    ensAddress: "",
    wrappedAddress: "",
    apiEtherscanEndpoint: "",
    proxyAddress: "0x8C27aBf05DE1d4847c3924566C3cBAFec6eFb42A",
    quoteTokenAddress: "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    chainIcon: "chain_avax_icon",
    quoteToken: "AVAX",
    apiChainPath: "avalanche"
  )

  public static let cronosMainnetRPC = CustomRPC (
    chainID: 25,
    type: "CRC20",
    name: "Cronos",
    symbol: "CRO",
    endpoint: "https://evm-cronos.crypto.org/",
    endpointKyber: "https://evm-cronos.crypto.org/",
    endpointAlchemy: "https://evm-cronos.crypto.org/",
    etherScanEndpoint: "https://cronoscan.com/",
    webScanName: "Cronoscan",
    ensAddress: "",
    wrappedAddress: "",
    apiEtherscanEndpoint: "",
    proxyAddress: "0xf351Dd5EC89e5ac6c9125262853c74E714C1d56a",
    quoteTokenAddress: "0xffffffffffffffffffffffffffffffffffffffff",
    chainIcon: "chain_cronos_icon",
    quoteToken: "CRO",
    apiChainPath: "cronos"
  )

  public static let fantomMainnetRPC = CustomRPC (
    chainID: 250,
    type: "ERC20",
    name: "Fantom",
    symbol: "FTM",
    endpoint: "https://rpc.ftm.tools/",
    endpointKyber: "https://rpc.ftm.tools/",
    endpointAlchemy: "https://rpc.ftm.tools/",
    etherScanEndpoint: "https://ftmscan.com/",
    webScanName: "FTMscan",
    ensAddress: "",
    wrappedAddress: "",
    apiEtherscanEndpoint: "",
    proxyAddress: "0xf351Dd5EC89e5ac6c9125262853c74E714C1d56a",
    quoteTokenAddress: "0xdddddddddddddddddddddddddddddddddddddddd",
    chainIcon: "chain_fantom_icon",
    quoteToken: "FTM",
    apiChainPath: "fantom"
  )

  public static let arbitrumMainnetRPC = CustomRPC (
    chainID: 42161,
    type: "ERC20",
    name: "Arbitrum",
    symbol: "ETH",
    endpoint: "https://rpc.ankr.com/arbitrum",
    endpointKyber: "https://arb1.arbitrum.io/rpc",
    endpointAlchemy: "https://arb1.arbitrum.io/rpc",
    etherScanEndpoint: "https://arbiscan.io/",
    webScanName: "Arbiscan",
    ensAddress: "",
    wrappedAddress: "",
    apiEtherscanEndpoint: "",
    proxyAddress: "0x864F01c5E46b0712643B956BcA607bF883e0dbC5",
    quoteTokenAddress: "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
    chainIcon: "chain_arbitrum_icon",
    quoteToken: "ETH",
    apiChainPath: "arbitrum"
  )
  
  public static let auroraMainnetRPC = CustomRPC (
    chainID: 1313161554,
    type: "ERC20",
    name: "Aurora",
    symbol: "ETH",
    endpoint: "https://mainnet.aurora.dev",
    endpointKyber: "https://mainnet.aurora.dev/",
    endpointAlchemy: "https://mainnet.aurora.dev",
    etherScanEndpoint: "https://aurorascan.dev/",
    webScanName: "Aurorascan",
    ensAddress: "",
    wrappedAddress: "",
    apiEtherscanEndpoint: "",
    proxyAddress: "0x864F01c5E46b0712643B956BcA607bF883e0dbC5",
    quoteTokenAddress: "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
    chainIcon: "chain_aurora_icon",
    quoteToken: "ETH",
    apiChainPath: "aurora"
  )

  public static let solana = CustomRPC (
    chainID: 101,
    type: "SPL",
    name: "Solana",
    symbol: "SOL",
    endpoint: "",
    endpointKyber: "https://solana.knstats.com/v1/mainnet/geth?appId=\(NodeConfig.solanaAppID!)-krystal-ios",
    endpointAlchemy: "",
    etherScanEndpoint: "https://solscan.io/",
    webScanName: "Solscan",
    ensAddress: "",
    wrappedAddress: "",
    apiEtherscanEndpoint: "",
    proxyAddress: "0x864F01c5E46b0712643B956BcA607bF883e0dbC5", //NOTE: fix later , add to avoid crash
    quoteTokenAddress: "So11111111111111111111111111111111111111112",
    chainIcon: "chain_solana_icon",
    quoteToken: "SOL",
    apiChainPath: "solana"
  )
  
  public static let klaytnMainnetRPC = CustomRPC (
    chainID: 8217,
    type: "KIP-7",
    name: "Klaytn",
    symbol: "KLAY",
    endpoint: "https://public-node-api.klaytnapi.com/v1/cypress",
    endpointKyber: "https://public-node-api.klaytnapi.com/v1/cypress",
    endpointAlchemy: "https://public-node-api.klaytnapi.com/v1/cypress",
    etherScanEndpoint: "https://scope.klaytn.com/",
    webScanName: "KlaytnScope",
    ensAddress: "",
    wrappedAddress: "",
    apiEtherscanEndpoint: "",
    proxyAddress: "0x864F01c5E46b0712643B956BcA607bF883e0dbC5",
    quoteTokenAddress: "0x1111111111111111111111111111111111111111",
    chainIcon: "chain_klaytn_icon",
    quoteToken: "KLAY",
    apiChainPath: "klaytn"
  )
}