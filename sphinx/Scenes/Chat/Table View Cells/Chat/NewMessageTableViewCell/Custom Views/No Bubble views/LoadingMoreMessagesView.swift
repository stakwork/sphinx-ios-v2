//
//  LoadingMoreMessagesView.swift
//  sphinx
//
//  Created by Tomas Timinskas on 18/09/2025.
//  Copyright © 2025 sphinx. All rights reserved.
//

import UIKit

class LoadingMoreMessagesView: UIView {
    
    @IBOutlet private var contentView: UIView!
    @IBOutlet weak var loadingWheel: UIActivityIndicatorView!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }

    private func setup() {
        Bundle.main.loadNibNamed("LoadingMoreMessagesView", owner: self, options: nil)
        addSubview(contentView)
        contentView.frame = self.bounds
        contentView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        
        loadingWheel.color = UIColor.Sphinx.SecondaryText
        loadingWheel.startAnimating()
    }
    
    func configure() {
        loadingWheel.startAnimating()
    }
}
