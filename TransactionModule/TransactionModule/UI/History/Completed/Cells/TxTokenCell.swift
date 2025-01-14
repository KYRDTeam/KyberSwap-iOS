//
//  TxTokenCell.swift
//  TransactionModule
//
//  Created by Tung Nguyen on 21/12/2022.
//

import UIKit
import Utilities
import DesignSystem

class TxTokenCell: UITableViewCell {
    @IBOutlet weak var logoImageView: UIImageView!
    @IBOutlet weak var verifyImageView: UIImageView!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var usdValueLabel: UILabel!
    
    func configure(viewModel: TxHistoryTokenCellViewModel) {
        if viewModel.tokenIconUrl.isNilOrEmpty {
            logoImageView.image = .defaultToken
        } else {
            logoImageView.loadImage(viewModel.tokenIconUrl)
        }
        verifyImageView.image = viewModel.verifyIcon
        amountLabel.text = viewModel.amountString
        usdValueLabel.text = viewModel.usdValue
        amountLabel.textColor = viewModel.isTokenChangePositive ? AppTheme.current.positiveTextColor : AppTheme.current.primaryTextColor
    }
    
}
