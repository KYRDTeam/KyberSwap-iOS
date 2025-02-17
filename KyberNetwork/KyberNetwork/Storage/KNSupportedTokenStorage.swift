// Copyright SIX DAY LLC. All rights reserved.

import RealmSwift
import TrustKeystore
import TrustCore
import BigInt

class KNSupportedTokenStorage {
  var supportedToken: [Token]
  private var favedTokens: [FavedToken]
  private var disableTokens: [Token]
  private var deletedTokens: [Token]
  var chainDisableTokens: [ChainType : [Token]]
  private var chainDeletedTokens: [ChainType : [Token]]

  var allActiveTokens: [Token] {
    return self.getActiveSupportedToken()
  }

  var allFullToken: [Token] {
    return self.supportedToken
  }
  /// Tokens used for manage screen, only deactive listed tokens and all custom tokens.
  var manageToken: [Token] {
    let disableListedTokens = self.supportedToken.filter { token in
        // Only get deactive tokens
        return !self.getTokenActiveStatus(token)
    }
    return disableListedTokens.sorted(by: { $0.getBalanceBigInt() > $1.getBalanceBigInt()})
  }

  static let shared = KNSupportedTokenStorage()

  init() {
    self.supportedToken = Storage.retrieve(KNEnvironment.default.envPrefix + Constants.tokenStoreFileName, as: [Token].self) ?? []
    self.favedTokens = Storage.retrieve(KNEnvironment.default.envPrefix + Constants.favedTokenStoreFileName, as: [FavedToken].self) ?? []
    self.disableTokens = Storage.retrieve(KNEnvironment.default.envPrefix + Constants.disableTokenStoreFileName, as: [Token].self) ?? []
    self.deletedTokens = Storage.retrieve(KNEnvironment.default.envPrefix + Constants.deleteTokenStoreFileName, as: [Token].self) ?? []
    
    var chainDisableTokensDic: [ChainType : [Token]] = [:]
    var chainDeletedTokensDic: [ChainType : [Token]] = [:]
    
    ChainType.getAllChain().forEach { chain in
      chainDisableTokensDic[chain] = KNSupportedTokenStorage.retrieveDisableTokensFromHardDisk(chainType: chain)
      chainDeletedTokensDic[chain] = KNSupportedTokenStorage.retrieveDeleteTokensFromHardDisk(chainType: chain)
    }
    self.chainDisableTokens = chainDisableTokensDic
    self.chainDeletedTokens = chainDeletedTokensDic
  }

  //TODO: temp wrap method delete later
  var supportedTokens: [TokenObject] {
    return self.getAllTokenObject()
  }
  
  var marketTokens: [Token] {
    return self.getActiveSupportedToken()
  }

  var ethToken: TokenObject {
    let token = self.supportedToken.first { (token) -> Bool in
      return token.symbol == "ETH"
    } ?? Token(name: "Ethereum", symbol: "ETH", address: "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee", decimals: 18, logo: "eth")
    return token.toObject()
  }

  var wethToken: TokenObject? {
    let token = self.supportedToken.first { (token) -> Bool in
      return token.symbol == "WETH"
    } ?? Token(name: "Wrapped Ether", symbol: "WETH", address: "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2", decimals: 18, logo: "weth")
    return token.toObject()
  }

  var kncToken: TokenObject {
    let token = self.supportedToken.first { (token) -> Bool in
      return token.symbol == "KNC"
    } ?? Token(name: "KyberNetwork", symbol: "KNC", address: "0xdefa4e8a7bcba345f687a2f1456f5edd9ce97202", decimals: 18, logo: "knc")
    return token.toObject()
  }
  
  var bnbToken: TokenObject {
    let token = self.supportedToken.first { (token) -> Bool in
      return token.symbol == "BNB"
    } ?? Token(name: "BNB", symbol: "BNB", address: AllChains.bscMainnetPRC.quoteTokenAddress, decimals: 18, logo: "bnb")
    return token.toObject()
  }

  var busdToken: TokenObject {
    let token = self.supportedToken.first { (token) -> Bool in
      return token.symbol == "BUSD"
    } ?? Token(name: "BUSD", symbol: "BUSD", address: "0xe9e7cea3dedca5984780bafc599bd69add087d56", decimals: 18, logo: "")
    return token.toObject()
  }

  var maticToken: TokenObject {
    let token = self.supportedToken.first { (token) -> Bool in
      return token.symbol == "MATIC"
    } ?? Token(name: "MATIC", symbol: "MATIC", address: AllChains.polygonMainnetPRC.quoteTokenAddress, decimals: 18, logo: "bnb")
    return token.toObject()
  }

  var avaxToken: TokenObject {
    let token = self.supportedToken.first { (token) -> Bool in
      return token.symbol == "AVAX"
    } ?? Token(name: "AVAX", symbol: "AVAX", address: AllChains.avalancheMainnetPRC.quoteTokenAddress, decimals: 18, logo: "avax")
    return token.toObject()
  }
  
  var cronosToken: TokenObject {
    let token = self.supportedToken.first { (token) -> Bool in
      return token.symbol == "CRO"
    } ?? Token(name: "CRO", symbol: "CRO", address: AllChains.cronosMainnetRPC.quoteTokenAddress, decimals: 18, logo: "cro")
    return token.toObject()
  }
  
  var fantomToken: TokenObject {
    let token = self.supportedToken.first { (token) -> Bool in
      return token.symbol == "FTM"
    } ?? Token(name: "FTM", symbol: "FTM", address: AllChains.fantomMainnetRPC.quoteTokenAddress, decimals: 18, logo: "ftm")
    return token.toObject()
  }
  
  var usdcToken: TokenObject {
    let token = self.supportedToken.first { (token) -> Bool in
      return token.symbol == "USDC"
    } ?? Token(name: "USDC", symbol: "USDC", address: "0x2791bca1f2de4661ed88a30c99a7a9449aa84174", decimals: 6, logo: "")
    return token.toObject()
  }

  var usdceToken: TokenObject {
    let token = self.supportedToken.first { (token) -> Bool in
      return token.symbol == "USDC.e"
    } ?? Token(name: "USDC.e", symbol: "USDC.e", address: "0xa7d7079b0fead91f3e65f86e8915cb59c1a4c664", decimals: 6, logo: "")
    return token.toObject()
  }

  func get(forPrimaryKey key: String) -> TokenObject? {
    let token = self.getTokenWith(address: key)
    return token?.toObject()
  }
  //MARK:-new data type implemetation
  func reloadData() {
    self.supportedToken = Storage.retrieve(KNEnvironment.default.envPrefix + Constants.tokenStoreFileName, as: [Token].self) ?? []
    self.favedTokens = Storage.retrieve(KNEnvironment.default.envPrefix + Constants.favedTokenStoreFileName, as: [FavedToken].self) ?? []
    self.disableTokens = Storage.retrieve(KNEnvironment.default.envPrefix + Constants.disableTokenStoreFileName, as: [Token].self) ?? []
    self.deletedTokens = Storage.retrieve(KNEnvironment.default.envPrefix + Constants.deleteTokenStoreFileName, as: [Token].self) ?? []
  }

  func getSupportedTokens() -> [Token] {
    return self.supportedToken
  }

  func updateSupportedTokens(_ tokens: [Token]) {
    guard !self.isEqualTokenArray(array1: tokens, array2: self.supportedToken) else {
      return
    }
    Storage.store(tokens, as: KNEnvironment.default.envPrefix + Constants.tokenStoreFileName)
    self.supportedToken = tokens
  }

  func getTokenWith(address: String) -> Token? {
    return self.allActiveTokens.first { (token) -> Bool in
      return token.address.lowercased() == address.lowercased()
    }
  }

  func getTokenWith(symbol: String) -> Token? {
    return self.allFullToken.first { (token) -> Bool in
      return token.symbol.lowercased() == symbol.lowercased()
    }
  }

  func getFavedTokenWithAddress(_ address: String) -> FavedToken? {
    let faved = self.favedTokens.first { (token) -> Bool in
      return token.address.lowercased() == address.lowercased()
    }
    return faved
  }

  func getFavedStatusWithAddress(_ address: String) -> Bool {
    let faved = self.getFavedTokenWithAddress(address)
    return faved?.status ?? false
  }

  func setFavedStatusWithAddress(_ address: String, status: Bool) {
    if let faved = self.getFavedTokenWithAddress(address) {
      faved.status = status
    } else {
      let newStatus = FavedToken(address: address, status: status)
      self.favedTokens.append(newStatus)
    }
    Storage.store(self.favedTokens, as: KNEnvironment.default.envPrefix + Constants.favedTokenStoreFileName)
  }

  func isTokenSaved(_ token: Token) -> Bool {
    let tokens = self.allActiveTokens
    let saved = tokens.first { (item) -> Bool in
      return item.address.lowercased() == token.address.lowercased()
    }

    return saved != nil
  }

  func getActiveSupportedToken() -> [Token] {
    return self.supportedToken.filter { token in
      return self.getTokenActiveStatus(token) && !self.getTokenDeleteStatus(token)
    }
  }

  func getTokenDeleteStatus(_ token: Token) -> Bool {
    return self.deletedTokens.contains(token)
  }

  func removeTokenFromDeleteList(_ token: Token) {
    if let index = self.deletedTokens.firstIndex(where: { item in
      return item == token
    }) {
      self.deletedTokens.remove(at: index)
    }
    Storage.store(self.deletedTokens, as: KNEnvironment.default.envPrefix + Constants.deleteTokenStoreFileName)
    self.setCacheDeletedToken(chain: KNGeneralProvider.shared.currentChain, tokens: self.deletedTokens)
  }

  func getTokenActiveStatus(_ token: Token) -> Bool {
    return !self.disableTokens.contains(token)
  }

  func setTokenActiveStatus(token: Token, status: Bool) {
    if status {
      if let index = self.disableTokens.firstIndex(where: { item in
        return item == token
      }) {
        self.disableTokens.remove(at: index)
        Storage.store(self.disableTokens, as: KNEnvironment.default.envPrefix + Constants.disableTokenStoreFileName)
      }
    } else {
      if !self.disableTokens.contains(token) {
        self.disableTokens.append(token)
        Storage.store(self.disableTokens, as: KNEnvironment.default.envPrefix + Constants.disableTokenStoreFileName)
      }
    }
    self.setCacheDisableToken(chain: KNGeneralProvider.shared.currentChain, tokens: self.disableTokens)
  }
  
  func setTokenActiveStatus(token: Token, status: Bool, chainType: ChainType) {
    var disableTokens = KNSupportedTokenStorage.retrieveDisableTokensFromHardDisk(chainType: chainType)
    if status {
      if let index = self.disableTokens.firstIndex(where: { item in
        return item == token
      }) {
        disableTokens.remove(at: index)
        KNSupportedTokenStorage.saveDisableTokensFromHardDisk(chainType: chainType, disableTokens: disableTokens)
      }
    } else {
      if !disableTokens.contains(token) {
        disableTokens.append(token)
        KNSupportedTokenStorage.saveDisableTokensFromHardDisk(chainType: chainType, disableTokens: disableTokens)
      }
    }
    self.setCacheDisableToken(chain: chainType, tokens: disableTokens)
  }
  
  private func setCacheDisableToken(chain: ChainType, tokens: [Token]) {
    self.chainDisableTokens[chain] = tokens
  }
  
  private func setCacheDeletedToken(chain: ChainType, tokens: [Token]) {
    self.chainDeletedTokens[chain] = tokens
  }

  func changeAllTokensActiveStatus(isActive: Bool) {
    // check if there is any disable token which is supported token
    let disabledSupportedTokens = self.disableTokens.filter { token in
      return self.supportedToken.contains(token)
    }
    self.disableTokens.removeAll()
    if !isActive {
      self.disableTokens.append(contentsOf: disabledSupportedTokens)
      self.disableTokens.append(contentsOf: manageToken)
    }
    Storage.store(self.disableTokens, as: KNEnvironment.default.envPrefix + Constants.disableTokenStoreFileName)
    self.setCacheDisableToken(chain: KNGeneralProvider.shared.currentChain, tokens: self.disableTokens)
  }

  func activeStatus() -> Bool {
    if disableTokens.isEmpty {
      // all tokens are active
      return true
    }

    if manageToken.count == disableTokens.count {
      // all tokens are deactive
      return false
    }

    if manageToken.count / 2 > disableTokens.count {
      // more than half of manage token are active
      return true
    }
    // more than half of manage token are deactive
    return false
  }

  func deleteCustomToken(_ token: Token) {
    guard !self.deletedTokens.contains(token) else {
      return
    }

    self.deletedTokens.append(token)
    Storage.store(self.deletedTokens, as: KNEnvironment.default.envPrefix + Constants.deleteTokenStoreFileName)
    self.setCacheDeletedToken(chain: KNGeneralProvider.shared.currentChain, tokens: self.deletedTokens)
  }

  func getAllTokenObject() -> [TokenObject] {
    return self.getListedTokenObject()
  }

  func getListedTokenObject() -> [TokenObject] {
    let activeTokens = self.supportedToken.filter { token in
        // Only get active tokens
        return self.getTokenActiveStatus(token)
    }
    return activeTokens.map { (token) -> TokenObject in
        return token.toObject()
    }
  }

  func getETH() -> Token {
    return self.supportedToken.first { (item) -> Bool in
      return item.symbol == "ETH"
    } ?? Token(name: "Ethereum", symbol: "ETH", address: "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee", decimals: 18, logo: "eth")
  }

  func getKNC() -> Token {
    return self.supportedToken.first { (item) -> Bool in
      return item.symbol == "KNC"
    } ?? Token(name: "KyberNetwork", symbol: "KNC", address: "0x7b2810576aa1cce68f2b118cef1f36467c648f92", decimals: 18, logo: "knc")
  }


  func getAssetTokens() -> [Token] {
    var result: [Token] = []
    let tokens = KNSupportedTokenStorage.shared.allActiveTokens
    let lendingBalances = BalanceStorage.shared.getAllLendingBalances(KNGeneralProvider.shared.currentChain)
    var lendingSymbols: [String] = []
    lendingBalances.forEach { (lendingPlatform) in
      lendingPlatform.balances.forEach { (balance) in
        lendingSymbols.append(balance.interestBearingTokenSymbol.lowercased())
      }
    }
    tokens.forEach { (token) in
      guard token.getBalanceBigInt() > BigInt(0), !lendingSymbols.contains(token.symbol.lowercased()) else {
        return
      }
      result.append(token)
    }
    return result
  }
  
  func getChainDBPath(chainType: ChainType) -> String {
    return chainType.getChainDBPath()
  }
  
  static func retrieveDisableTokensFromHardDisk(chainType: ChainType) -> [Token] {
    let disableTokens = Storage.retrieve(chainType.getChainDBPath() + Constants.disableTokenStoreFileName, as: [Token].self) ?? []
    return disableTokens
  }
  
  static func saveDisableTokensFromHardDisk(chainType: ChainType, disableTokens: [Token]) {
    Storage.store(disableTokens, as: chainType.getChainDBPath() + Constants.disableTokenStoreFileName)
  }
  
  static func retrieveDeleteTokensFromHardDisk(chainType: ChainType) -> [Token] {
    let deletedTokens = Storage.retrieve(chainType.getChainDBPath() + Constants.deleteTokenStoreFileName, as: [Token].self) ?? []
    return deletedTokens
  }
  
  private func getDisableTokensFor(chainType: ChainType) -> [Token] {
    return self.chainDisableTokens[chainType] ?? []
  }
  
  private func getDeletedTokensFor(chainType: ChainType) -> [Token] {
    self.chainDeletedTokens[chainType] ?? []
  }

  func getHideAndDeleteTokensBalanceUSD(_ currency: CurrencyMode, chainType: ChainType?) -> BigInt {
    var total = BigInt(0)
//    guard let chainType = chainType else {
//      return total
//    }
//    let disableTokens = self.getDisableTokensFor(chainType: chainType)
//    let deletedTokens = self.getDeletedTokensFor(chainType: chainType)
//    let tokens = disableTokens + deletedTokens
//
//    tokens.forEach { token in
//      let balance = token.getBalanceBigIntForChain(chainType: chainType)
//      let rateBigInt = BigInt(token.getTokenLastPrice(currency, chainType: chainType) * pow(10.0, 18.0))
//      let valueBigInt = balance * rateBigInt / BigInt(10).power(token.decimals)
//      total += valueBigInt
//    }
    return total
  }
  
  func getAllChainHideAndDeleteTokensBalanceUSD( _ currency: CurrencyMode) -> BigInt {
    var total = BigInt(0)
//    ChainType.getAllChain().forEach { chain in
//      total += self.getHideAndDeleteTokensBalanceUSD(currency, chainType: chain)
//    }
    return total
  }

  func findTokensWithAddresses(addresses: [String]) -> [Token] {
    return self.allActiveTokens.filter { (token) -> Bool in
      return addresses.contains(token.address.lowercased())
    }
  }

  func isEqualTokenArray(array1: [Token], array2: [Token]) -> Bool {
    if array1.isEmpty && array2.isEmpty {
      return true
    }

    if array1.count != array2.count {
      return false
    }

    var isEqual = true
    for index in 0 ..< array1.count {
      let firstToken = array1[index]
      let secondToken = array2[index]

      //just 1 param different then we will consider there are updates from api
      if firstToken.address != secondToken.address
          || firstToken.decimals != secondToken.decimals
          || firstToken.name.lowercased() != secondToken.name.lowercased()
          || firstToken.symbol.lowercased() != secondToken.symbol.lowercased()
          || firstToken.logo.lowercased() != secondToken.logo.lowercased()
          || firstToken.tag?.lowercased() != secondToken.tag?.lowercased() {
        isEqual = false
        break
      }
    }
    return isEqual
  }
}
