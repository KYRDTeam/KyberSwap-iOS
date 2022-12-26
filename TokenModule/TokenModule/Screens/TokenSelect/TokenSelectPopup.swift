//
//  TokenSelectViewController.swift
//  TokenModule
//
//  Created by Tung Nguyen on 23/12/2022.
//

import UIKit
import Services

public class TokenSelectPopup: UIViewController, UIGestureRecognizerDelegate {
    
    @IBOutlet weak var emptyView: UIView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var bottomView: UIView!
    
    public var viewModel: TokenSelectViewModel!
    public var onBackgroundTapped: (() -> ())?
    public var onSelectToken: ((AdvancedSearchToken) -> ())?
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        setupView()
        setupTableView()
        bindViewModel()
    }
    
    func setupView() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tapBackground))
        tapGesture.delegate = self
        bottomView.isUserInteractionEnabled = true
        bottomView.addGestureRecognizer(tapGesture)
    }
    
    @objc func tapBackground() {
        onBackgroundTapped?()
    }
    
    func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.registerCellNib(TokenSelectCell.self)
        tableView.tableHeaderView = .init(frame: .init(x: 0, y: 0, width: 0, height: CGFloat.leastNonzeroMagnitude))
    }
    
    func bindViewModel() {
        viewModel.onTokensUpdated = { [weak self] in
            DispatchQueue.main.async {
                self?.tableView.reloadData()
                self?.emptyView.isHidden = self?.viewModel.tokens.isEmpty == false
            }
        }
    }
    
    public func updateQuery(text: String) {
        viewModel.query = text
    }

    private func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if touch.view?.isDescendant(of: view) == true {
            return false
        }
        return true
    }
    
}

extension TokenSelectPopup: UITableViewDataSource, UITableViewDelegate {
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.tokens.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(TokenSelectCell.self, indexPath: indexPath)!
        cell.configure(token: viewModel.tokens[indexPath.row])
        cell.selectionStyle = .none
        return cell
    }
    
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 56
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        onSelectToken?(viewModel.tokens[indexPath.row])
    }
    
}