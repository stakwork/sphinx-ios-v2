//
//  ParticipantBoxView.swift
//  sphinx
//
//  Created for the live call participants strip feature.
//  Copyright © 2024 sphinx. All rights reserved.
//

import UIKit
import SDWebImage

class ParticipantBoxView: UIView {
    
    private let avatarSize: CGFloat = 24
    private let spacing: CGFloat = 4
    
    private let avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let initialsLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        label.textColor = .white
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 9, weight: .regular)
        label.textColor = UIColor.Sphinx.Text
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let stackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.alignment = .center
        sv.spacing = 4
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        backgroundColor = UIColor.Sphinx.Body.withAlphaComponent(0.08)
        layer.cornerRadius = 8
        clipsToBounds = true
        
        // Avatar container (image + initials stacked)
        let avatarContainer = UIView()
        avatarContainer.translatesAutoresizingMaskIntoConstraints = false
        avatarContainer.clipsToBounds = true
        avatarContainer.layer.cornerRadius = avatarSize / 2
        
        avatarContainer.addSubview(initialsLabel)
        avatarContainer.addSubview(avatarImageView)
        
        NSLayoutConstraint.activate([
            avatarContainer.widthAnchor.constraint(equalToConstant: avatarSize),
            avatarContainer.heightAnchor.constraint(equalToConstant: avatarSize),
            
            initialsLabel.leadingAnchor.constraint(equalTo: avatarContainer.leadingAnchor),
            initialsLabel.trailingAnchor.constraint(equalTo: avatarContainer.trailingAnchor),
            initialsLabel.topAnchor.constraint(equalTo: avatarContainer.topAnchor),
            initialsLabel.bottomAnchor.constraint(equalTo: avatarContainer.bottomAnchor),
            
            avatarImageView.leadingAnchor.constraint(equalTo: avatarContainer.leadingAnchor),
            avatarImageView.trailingAnchor.constraint(equalTo: avatarContainer.trailingAnchor),
            avatarImageView.topAnchor.constraint(equalTo: avatarContainer.topAnchor),
            avatarImageView.bottomAnchor.constraint(equalTo: avatarContainer.bottomAnchor),
        ])
        
        stackView.addArrangedSubview(avatarContainer)
        stackView.addArrangedSubview(nameLabel)
        
        addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -6),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }
    
    func configure(with participant: BubbleMessageLayoutState.CallParticipantInfo) {
        nameLabel.text = participant.name.isEmpty ? participant.identity : participant.name
        
        // Show initials placeholder by default
        let displayName = participant.name.isEmpty ? participant.identity : participant.name
        initialsLabel.text = displayName.getInitialsFromName()
        initialsLabel.backgroundColor = UIColor.random()
        avatarImageView.image = nil
        avatarImageView.isHidden = true
        
        // Load profile picture if available
        if let urlString = participant.profilePictureUrl,
           !urlString.isEmpty,
           let url = URL(string: urlString) {
            avatarImageView.sd_setImage(
                with: url,
                placeholderImage: nil,
                options: [.highPriority],
                completed: { [weak self] image, error, _, _ in
                    guard let self = self, let image = image, error == nil else { return }
                    self.avatarImageView.image = image
                    self.avatarImageView.isHidden = false
                }
            )
        }
        
        // Dim for participants who have left
        alpha = participant.isActive ? 1.0 : 0.5
    }
}
