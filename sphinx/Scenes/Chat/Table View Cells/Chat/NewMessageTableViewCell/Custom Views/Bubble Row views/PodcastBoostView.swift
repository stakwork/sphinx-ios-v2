//
//  PodcastBoostView.swift
//  sphinx
//
//  Created by Tomas Timinskas on 05/06/2023.
//  Copyright © 2023 sphinx. All rights reserved.
//

import UIKit

class PodcastBoostView: UIView {

    @IBOutlet private var contentView: UIView!
    
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var boostIconView: UIView!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }

    private func setup() {
        Bundle.main.loadNibNamed("PodcastBoostView", owner: self, options: nil)
        addSubview(contentView)
        contentView.frame = self.bounds
        contentView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        
        boostIconView.layer.cornerRadius = boostIconView.bounds.height / 2
    }
    
    func configureWith(
        podcastBoost: BubbleMessageLayoutState.PodcastBoost
    ) {
        amountLabel.text = podcastBoost.amount.formattedWithSeparator
    }
}
