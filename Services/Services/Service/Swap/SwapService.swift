//
//  RateService.swift
//  Services
//
//  Created by Tung Nguyen on 12/10/2022.
//

import Foundation
import Moya
import BigInt
import Utilities
import Result

public class SwapService: BaseService {
    
    let provider = MoyaProvider<SwapEndpoint>(plugins: [NetworkLoggerPlugin(verbose: true)])

    public func getAllRates(chainPath: String, address: String, srcTokenContract: String, destTokenContract: String,
                            amount: BigInt, focusSrc: Bool, completion: @escaping ([Rate]) -> ()) {
        provider.request(.getAllRates(chainPath: chainPath, src: srcTokenContract.lowercased(), dst: destTokenContract.lowercased(),
                                      amount: amount.description, focusSrc: focusSrc, userAddress: address)) { result in
            switch result {
            case .success(let response):
                do {
                    let data = try JSONDecoder().decode(RateResponse.self, from: response.data)
                    completion(data.rates)
                } catch {
                    completion([])
                }
            case .failure:
                completion([])
            }
        }
    }
    
    public func buildTx(chainPath: String, request: SwapBuildTxRequest, completion: @escaping ((Result<TxObject, AnyError>) -> ())) {
        provider.request(.buildSwapTx(chainPath: chainPath, address: request.userAddress, src: request.src, dst: request.dest, srcAmount: request.srcQty, minDstAmount: request.minDesQty, gasPrice: request.gasPrice, nonce: request.nonce, hint: request.hint, useGasToken: request.useGasToken)) { result in
            switch result {
            case .success(let resp):
                let decoder = JSONDecoder()
                do {
                    let data = try decoder.decode(TransactionResponse.self, from: resp.data)
                    completion(.success(data.txObject))
                } catch {
                    completion(.failure(AnyError(error)))
                }
            case .failure(let error):
                completion(.failure(AnyError(error)))
            }
        }
    }
    
}
