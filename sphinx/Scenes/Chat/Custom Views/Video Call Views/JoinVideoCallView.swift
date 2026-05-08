//
//  JoinVideoCallView.swift
//  sphinx
//
//  Created by Tomas Timinskas on 19/03/2020.
//  Copyright © 2020 Sphinx. All rights reserved.
//

import UIKit

@MainActor protocol JoinCallViewDelegate: class {
    func didTapCopyLink()
    func didTapAudioButton()
    func didTapVideoButton()
}

class JoinVideoCallView: UIView {
    
    static let kParticipantsRowHeight: CGFloat = 52
    
    weak var delegate: JoinCallViewDelegate?
    
    @IBOutlet private var contentView: UIView!
    @IBOutlet weak var audioButtonContainer: UIView!
    @IBOutlet weak var videoButtonContainer: UIView!
    
    private lazy var participantsScrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsHorizontalScrollIndicator = false
        sv.showsVerticalScrollIndicator = false
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()
    
    private lazy var participantsStackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.alignment = .center
        sv.distribution = .fill
        sv.spacing = 6
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()
    
    private var participantsScrollViewHeightConstraint: NSLayoutConstraint?
    
    public enum CallButton: Int {
        case Audio
        case Video
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
        Bundle.main.loadNibNamed("JoinVideoCallView", owner: self, options: nil)
        addSubview(contentView)
        contentView.frame = self.bounds
        contentView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        
        audioButtonContainer.layer.cornerRadius = 8
        audioButtonContainer.addShadow(location: VerticalLocation.bottom, color: UIColor.Sphinx.PrimaryBlueBorder, opacity: 1, radius: 0.5, bottomhHeight: 1.5)
        
        videoButtonContainer.layer.cornerRadius = 8
        videoButtonContainer.addShadow(location: VerticalLocation.bottom, color: UIColor.Sphinx.GreenBorder, opacity: 1, radius: 0.5, bottomhHeight: 1.5)
        
        setupParticipantsStrip()
    }
    
    private func setupParticipantsStrip() {
        participantsScrollView.addSubview(participantsStackView)
        contentView.addSubview(participantsScrollView)
        
        let heightConstraint = participantsScrollView.heightAnchor.constraint(equalToConstant: 0)
        participantsScrollViewHeightConstraint = heightConstraint
        
        NSLayoutConstraint.activate([
            participantsScrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            participantsScrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            participantsScrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            heightConstraint,
            
            participantsStackView.leadingAnchor.constraint(equalTo: participantsScrollView.leadingAnchor),
            participantsStackView.trailingAnchor.constraint(equalTo: participantsScrollView.trailingAnchor),
            participantsStackView.topAnchor.constraint(equalTo: participantsScrollView.topAnchor),
            participantsStackView.bottomAnchor.constraint(equalTo: participantsScrollView.bottomAnchor),
            participantsStackView.heightAnchor.constraint(equalTo: participantsScrollView.heightAnchor),
        ])
    }
    
    func configureWith(participantsData: MessageTableCellState.ParticipantsData?) {
        // Clear existing participant views
        participantsStackView.arrangedSubviews.forEach {
            participantsStackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        
        guard let participantsData = participantsData, !participantsData.participants.isEmpty else {
            participantsScrollViewHeightConstraint?.constant = 0
            participantsScrollView.isHidden = true
            return
        }
        
        for participant in participantsData.participants {
            let boxView = ParticipantBoxView()
            boxView.configure(with: participant)
            boxView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                boxView.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),
                boxView.widthAnchor.constraint(lessThanOrEqualToConstant: 120),
                boxView.heightAnchor.constraint(equalToConstant: JoinVideoCallView.kParticipantsRowHeight - 8),
            ])
            participantsStackView.addArrangedSubview(boxView)
        }
        
        participantsScrollViewHeightConstraint?.constant = JoinVideoCallView.kParticipantsRowHeight
        participantsScrollView.isHidden = false
    }
    
    func configureWith(
        callLink: BubbleMessageLayoutState.CallLink,
        and delegate: JoinCallViewDelegate
    ) {
        self.delegate = delegate
        
        videoButtonContainer.isHidden = callLink.callMode == .Audio
    }
    
    func configure(delegate: JoinCallViewDelegate, link: String) {
        self.delegate = delegate
        
        configureWith(link: link)
    }
    
    func configureWith(link: String) {
        let mode = VideoCallHelper.getCallMode(link: link)
        
        audioButtonContainer.isHidden = false
        videoButtonContainer.isHidden = false
        
        switch (mode) {
        case .Audio:
            videoButtonContainer.isHidden = true
            break
        default:
            break
        }
    }
    
    @IBAction func callButtonTouched(_ sender: Any) {
        callButtonDeselected(sender)
        
        guard let sender = sender as? UIButton else {
            return
        }
        
        switch(sender.tag) {
        case CallButton.Audio.rawValue:
            delegate?.didTapAudioButton()
            break
        case CallButton.Video.rawValue:
            delegate?.didTapVideoButton()
            break
        default:
            break
        }
    }
    
    @IBAction func callButtonSelected(_ sender: Any) {
        guard let sender = sender as? UIButton else {
            return
        }
        
        switch(sender.tag) {
        case CallButton.Audio.rawValue:
            audioButtonContainer.backgroundColor = UIColor.Sphinx.PrimaryBlueBorder
            break
        case CallButton.Video.rawValue:
            videoButtonContainer.backgroundColor = UIColor.Sphinx.GreenBorder
            break
        default:
            break
        }
    }
    
    @IBAction func callButtonDeselected(_ sender: Any) {
        guard let sender = sender as? UIButton else {
            return
        }
        
        switch(sender.tag) {
        case CallButton.Audio.rawValue:
            audioButtonContainer.backgroundColor = UIColor.Sphinx.PrimaryBlue
            break
        case CallButton.Video.rawValue:
            videoButtonContainer.backgroundColor = UIColor.Sphinx.PrimaryGreen
            break
        default:
            break
        }
    }
    
    @IBAction func copyLinkButtonTouched() {
        delegate?.didTapCopyLink()
    }
}
