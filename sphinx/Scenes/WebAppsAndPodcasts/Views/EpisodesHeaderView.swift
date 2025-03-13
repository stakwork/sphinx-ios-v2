//
//  EpisodesHeaderView.swift
//  sphinx
//
//  Created by Tomas Timinskas on 27/10/2020.
//  Copyright © 2020 Sphinx. All rights reserved.
//

import UIKit

class EpisodesHeaderView: UIView {
    
    @IBOutlet var contentView: UIView!
    @IBOutlet weak var episodesLabel: UILabel!
    @IBOutlet weak var episodesCountLabel: UILabel!
    @IBOutlet weak var skipAdsContainer: UIView!
    @IBOutlet weak var skipAdsLabel: UILabel!
    
    public var skipAds : Bool {
        get {
            if let skipAds = UserDefaults.Keys.skipAds.get(defaultValue: false) {
                return skipAds
            }
            return false
        }
        set {
            UserDefaults.Keys.skipAds.set(newValue)
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }

    private func setup() {
        Bundle.main.loadNibNamed("EpisodesHeaderView", owner: self, options: nil)
        addSubview(contentView)
        contentView.frame = self.bounds
        contentView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        
        skipAdsContainer.layer.cornerRadius = 15
        skipAdsContainer.layer.borderWidth = 1
    }
    
    func configureWith(count: Int) {
        episodesLabel.text = "episodes".localized.uppercased()
        episodesCountLabel.text = "\(count)"
        
        configureSkipAdsButton(enable: skipAds)
    }
    
    @IBAction func skipAdsButtonTouched() {
        let newValue = !skipAds
        skipAds = newValue
        configureSkipAdsButton(enable: newValue)
    }
    
    func configureSkipAdsButton(enable: Bool) {
        skipAdsContainer.backgroundColor = enable ? UIColor.Sphinx.PrimaryGreen : UIColor(hex: "#B0B7BC")
        skipAdsLabel.textColor = enable ? UIColor.white : UIColor(hex: "#6B7A8D")
    }
}
