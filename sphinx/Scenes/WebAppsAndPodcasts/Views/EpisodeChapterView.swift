//
//  EpisodeChapterView.swift
//  sphinx
//
//  Created by Tomas Timinskas on 11/03/2025.
//  Copyright © 2025 sphinx. All rights reserved.
//

import UIKit

protocol ChapterViewDelegate : class {
    func shouldPlayChapterWith(index: Int)
}

class EpisodeChapterView: UIView {
    
    weak var delegate: ChapterViewDelegate?

    @IBOutlet var contentView: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var adLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    
    var index: Int! = nil
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }

    private func setup() {
        Bundle.main.loadNibNamed("EpisodeChapterView", owner: self, options: nil)
        addSubview(contentView)
        contentView.frame = self.bounds
        contentView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
    }
    
    func configureWith(
        chapter: Chapter,
        delegate: ChapterViewDelegate?,
        index: Int,
        episodeRow: Bool
    ) {
        self.delegate = delegate
        self.index = index
        
        adLabel.isHidden = !chapter.isAd
        
        titleLabel.text = chapter.name
        timeLabel.text = chapter.timestamp
        
        titleLabel.textColor = episodeRow ? UIColor.Sphinx.Text : UIColor.Sphinx.MainBottomIcons
    }

    @IBAction func chapterButtonTouched() {
        delegate?.shouldPlayChapterWith(index: index)
    }
}
