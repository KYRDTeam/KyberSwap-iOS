//
//  TransactionViewControllerTests.swift
//  KrystalUnitTests
//
//  Created by Tung Nguyen on 30/05/2022.
//

@testable import Krystal
import Foundation
import Quick
import Nimble
import UIKit
import BigInt

class TransactionDetailViewControllerSpec: QuickSpec {
  
  override func spec() {
    describe("TransactionDetailPresenter") {
      var sut: TransactionDetailViewController!
      var presenter: MockTransactionDetailPresenter!
      
      beforeEach {
        presenter = MockTransactionDetailPresenter()
        sut = TransactionDetailViewController.instantiateFromNib()
        sut.presenter = presenter
        _ = sut.view
        
        let tx = ExtraBridgeTransaction(address: "0xabcdef", token: "anyUSDT", amount: BigInt("12000000000000000000"), chainId: "56", chainName: "BNB", tx: "0x010101", txStatus: "success", decimals: 18)
        
        presenter.items = [
          .common(type: .bridge, timestamp: 123456789, hideStatus: true, status: .success),
          .bridgeSubTx(from: true, tx: tx),
          .stepSeparator,
          .bridgeFee(fee: "0.0001234 BNB"),
          .estimatedBridgeTime(time: "3-30 mins")
        ]
      }
      
      describe("tableView numberOfRowsInSection") {
        it("should returns 5") {
          expect(sut.tableView(sut.tableView, numberOfRowsInSection: 0)).to(equal(5))
        }
      }
      
      describe("tableView cellForRow") {
        it("should be correct to item row type") {
          let cell0 = sut.tableView(sut.tableView, cellForRowAt: .init(row: 0, section: 0)) as? TransactionTypeInfoCell
          expect(cell0).toNot(beNil())
          
          let cell1 = sut.tableView(sut.tableView, cellForRowAt: .init(row: 1, section: 0)) as? BridgeSubTransactionCell
          expect(cell1).toNot(beNil())
          expect(cell1?.addressLabel.text).to(equal("0xabcdef...cdef"))
          expect(cell1?.addressTitle.text).to(equal("Sender"))
          expect(cell1?.amountLabel.text).to(equal("- 12 anyUSDT"))
          
          let cell2 = sut.tableView(sut.tableView, cellForRowAt: .init(row: 2, section: 0)) as? TransactionStepSeparatorCell
          expect(cell2).toNot(beNil())
          
          let cell3 = sut.tableView(sut.tableView, cellForRowAt: .init(row: 3, section: 0)) as? TxInfoCell
          expect(cell3).toNot(beNil())
          expect(cell3?.valueLabel.text).to(equal("0.0001234 BNB"))
          
          let cell4 = sut.tableView(sut.tableView, cellForRowAt: .init(row: 4, section: 0)) as? TxInfoCell
          expect(cell4).toNot(beNil())
          expect(cell4?.valueLabel.text).to(equal("3-30 mins"))
        }
      }
      
      describe(":BridgeSubTransactionCellDelegate") {
        it("should call correct function") {
          let cell = sut.tableView(sut.tableView, cellForRowAt: .init(row: 1, section: 0)) as! BridgeSubTransactionCell
          sut.openTxDetail(cell: cell, hash: "0xabcdef", chainID: "56")
          expect(presenter.isOnOpenTxScanCall).to(equal(true))
          
          sut.copyTxAddress(cell: cell, address: "0xCopiedAddress")
          expect(UIPasteboard.general.string).to(equal("0xCopiedAddress"))
        }
      }
      
    }
  }
}
