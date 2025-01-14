//
//  AdvanceSearchTokenInteractor.swift
//  KyberNetwork
//
//  Created Com1 on 13/06/2022.
//  Copyright © 2022 ___ORGANIZATIONNAME___. All rights reserved.
//
//  Template generated by Juanpe Catalán @JuanpeCMiOS
//

import UIKit
import Moya
import Services

class AdvanceSearchTokenInteractor: AdvanceSearchTokenInteractorProtocol {
  weak var presenter: AdvanceSearchTokenPresenterProtocol?
  var currentProcess: Cancellable?
  
  func getSearchData(keyword: String) {
    let provider = MoyaProvider<KrytalService>(plugins: [NetworkLoggerPlugin(verbose: true)])
    
    if let currentProcess = currentProcess {
      currentProcess.cancel()
    }
    
    self.currentProcess = provider.requestWithFilter(.advancedSearch(query: keyword, limit: 50)) { result in
      switch result {
      case .failure(let error):
        self.presenter?.didGetSearchResult(result: nil, error: error)
      case .success(let data):
        if let json = try? data.mapJSON() as? JSONDictionary ?? [:], let jsonData = json["data"] as? JSONDictionary {
          let searchResult = SearchResult(json: jsonData)
          self.presenter?.didGetSearchResult(result: searchResult, error: nil)
        } else {
          self.presenter?.didGetSearchResult(result: nil, error: nil)
        }
      }
    } as? Cancellable
  }
}
