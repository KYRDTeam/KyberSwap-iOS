//
//  KNActionSheetAlertViewController.swift
//  KyberNetwork
//
//  Created by Com1 on 20/09/2021.
//

import UIKit

// height or info view + padding for view = 42 + 24
let rowHeight = 66
let headerHeight = 46
typealias AlertHandler = @convention(block) (UIAlertAction) -> Void

class KNActionSheetAlertViewController: KNBaseViewController {
    /// Array contain actions which will be displayed
    let actions: [UIAlertAction]
    let maintitle: String
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var tableViewHeightConstraint: NSLayoutConstraint!

    init(title: String, actions: [UIAlertAction]) {
        self.maintitle = title
        self.actions = actions
        super.init(nibName: KNActionSheetAlertViewController.className, bundle: nil)
        self.modalPresentationStyle = .custom
//        self.transitioningDelegate = transitor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configUI()
        // Do any additional setup after loading the view.
    }

    func configUI() {
        self.tableView.rounded(radius: 16)
        tableView.isScrollEnabled = false
        self.tableViewHeightConstraint.constant = CGFloat(self.actions.count * rowHeight + headerHeight * 2)
    }
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}

extension KNActionSheetAlertViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let action = actions[indexPath.row]
        return actionInfoCell(action: action)
    }

    func actionInfoCell(action: UIAlertAction) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "actionInfoCell")
        let containViewWidth = UIScreen.main.bounds.size.width - 37*2
        let containWiew = UIView(frame: CGRect(x: 37, y: 12, width: containViewWidth, height: 42))
        containWiew.backgroundColor = UIColor.Kyber.charcoalGrey
        containWiew.rounded(radius: 16)
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: containViewWidth, height: 42))
        label.textColor = UIColor.white
        label.textAlignment = .center
        label.text = action.title
        containWiew.addSubview(label)
        cell.addSubview(containWiew)
        cell.backgroundColor = UIColor.Kyber.elivation3
        cell.selectionStyle = .none
        return cell
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return actions.count
    }
}

extension KNActionSheetAlertViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return CGFloat(rowHeight)
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return CGFloat(headerHeight)
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.size.width, height: CGFloat(headerHeight)))
        view.backgroundColor = UIColor.Kyber.elivation3
        return view
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let action = actions[indexPath.row]
        self.dismiss(animated: true) {
            guard let block = action.value(forKey: "handler") else { return }
            let handler = unsafeBitCast(block as AnyObject, to: AlertHandler.self)
            handler(action)
        }
    }
}
