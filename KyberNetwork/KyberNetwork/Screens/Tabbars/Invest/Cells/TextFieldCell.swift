//
//  TextFieldCell.swift
//  KyberNetwork
//
//  Created by Com1 on 22/05/2022.
//

import UIKit

class TextFieldCell: UITableViewCell {
  @IBOutlet weak var textField: UITextField!
  override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
}
