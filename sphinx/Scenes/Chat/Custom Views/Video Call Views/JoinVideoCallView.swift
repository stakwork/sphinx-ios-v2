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

    static let kParticipantsRowHeight: CGFloat = 54

    weak var delegate: JoinCallViewDelegate?

    @IBOutlet private var contentView: UIView!
    @IBOutlet weak var audioButtonContainer: UIView!
    @IBOutlet weak var videoButtonContainer: UIView!
    @IBOutlet weak var participantsStackView: UIStackView!

    private let participantsCountLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 11)
        label.textColor = UIColor.Sphinx.Text
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

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

        participantsStackView.isHidden = true
    }

    func configureWith(participantsData: MessageTableCellState.ParticipantsData?) {
        participantsStackView.arrangedSubviews.forEach {
            participantsStackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        guard let participantsData = participantsData, !participantsData.participants.isEmpty else {
            participantsStackView.isHidden = true
            return
        }

        let displayedParticipants = participantsData.participants.prefix(5)
        for participant in displayedParticipants {
            let boxView = ParticipantBoxView()
            boxView.configure(with: participant)
            boxView.translatesAutoresizingMaskIntoConstraints = false
            
            NSLayoutConstraint.activate([
                boxView.widthAnchor.constraint(greaterThanOrEqualToConstant: 30),
                boxView.widthAnchor.constraint(lessThanOrEqualToConstant: 120),
                boxView.heightAnchor.constraint(equalToConstant: JoinVideoCallView.kParticipantsRowHeight - 8),
            ])
            participantsStackView.addArrangedSubview(boxView)
        }

        if participantsData.participants.count > 5 {
            participantsCountLabel.text = "+\(participantsData.participants.count - 5)"
            participantsStackView.addArrangedSubview(participantsCountLabel)
        }
        
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        participantsStackView.addArrangedSubview(spacer)

        participantsStackView.isHidden = false
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
