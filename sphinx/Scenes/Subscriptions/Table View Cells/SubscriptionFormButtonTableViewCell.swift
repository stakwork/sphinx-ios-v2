//
//  SubscriptionFormButtonTableViewCell.swift
//  sphinx
//
//  Created by Tomas Timinskas on 12/11/2019.
//  Copyright © 2019 Sphinx. All rights reserved.
//

import UIKit

@MainActor protocol SubscriptionFormRowDelegate: class {
    func didTapSubscribeButton()
}

class SubscriptionFormButtonTableViewCell: UITableViewCell {
    
    weak var delegate: SubscriptionFormRowDelegate!

    @IBOutlet weak var shadowView: UIView!
    @IBOutlet weak var subscribeButton: UIButton!
    @IBOutlet weak var loadingWheel: UIActivityIndicatorView!
    
    var loading = false {
        didSet {
            LoadingWheelHelper.toggleLoadingWheel(loading: loading, loadingWheel: loadingWheel)
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()

        Task { @MainActor in
            self.loading = false
            self.contentView.clipsToBounds = true
            self.subscribeButton.setBackgroundColor(color: UIColor.Sphinx.PrimaryBlueBorder, forUIControlState: .highlighted)
            self.subscribeButton.setBackgroundColor(color: UIColor.Sphinx.PrimaryBlueBorder, forUIControlState: .selected)
            self.subscribeButton.layer.cornerRadius = self.subscribeButton.frame.size.height / 2
            self.subscribeButton.clipsToBounds = true
        }
    }
    
    func configureButton(editing: Bool) {
        subscribeButton.setTitle(editing ? "confirm.upper".localized : "subscribe.upper".localized, for: .normal)
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
    @IBAction func subscribeButtonTouched() {
        loading = true
        delegate?.didTapSubscribeButton()
    }
}
