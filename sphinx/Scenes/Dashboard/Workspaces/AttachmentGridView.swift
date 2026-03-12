//
//  AttachmentGridView.swift
//  sphinx
//
//  Created on 2026-03-12.
//  Copyright © 2026 sphinx. All rights reserved.
//

import UIKit
import SDWebImage

// MARK: - AttachmentTileView

private class AttachmentTileView: UIView {

    var onTap: ((HiveChatMessageAttachment) -> Void)?
    private var attachment: HiveChatMessageAttachment?

    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 8
        iv.backgroundColor = .black
        return iv
    }()

    private let playIconView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.image = UIImage(systemName: "play.circle.fill")
        iv.tintColor = .white
        iv.contentMode = .scaleAspectFit
        iv.isHidden = true
        return iv
    }()

    private let fileLabel: UILabel = {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.font = UIFont.systemFont(ofSize: 11)
        lbl.textColor = .white
        lbl.textAlignment = .center
        lbl.numberOfLines = 2
        lbl.isHidden = true
        return lbl
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        clipsToBounds = true
        layer.cornerRadius = 8

        addSubview(imageView)
        addSubview(playIconView)
        addSubview(fileLabel)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),

            playIconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            playIconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            playIconView.widthAnchor.constraint(equalToConstant: 36),
            playIconView.heightAnchor.constraint(equalToConstant: 36),

            fileLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            fileLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            fileLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
        isUserInteractionEnabled = true
    }

    func configure(with attachment: HiveChatMessageAttachment) {
        self.attachment = attachment
        let mime = attachment.mimeType ?? ""

        playIconView.isHidden = true
        fileLabel.isHidden = true
        imageView.image = nil

        if mime.hasPrefix("image/") {
            imageView.backgroundColor = .darkGray
            if let s3Key = attachment.resolvedUrl {
                API.sharedInstance.fetchPresignedUrlWithAuth(s3Key: s3Key) { [weak self] presignedUrlStr in
                    DispatchQueue.main.async {
                        guard let self = self,
                              let urlStr = presignedUrlStr,
                              let url = URL(string: urlStr) else { return }
                        self.imageView.sd_setImage(with: url, placeholderImage: nil, options: .lowPriority)
                    }
                }
            }
        } else if mime.hasPrefix("video/") {
            imageView.image = nil
            imageView.backgroundColor = UIColor(white: 0.2, alpha: 1.0)
            playIconView.isHidden = false
        } else {
            imageView.backgroundColor = UIColor(white: 0.3, alpha: 1.0)
            imageView.image = UIImage(systemName: "doc")
            imageView.tintColor = .white
            imageView.contentMode = .center
            fileLabel.text = attachment.filename
            fileLabel.isHidden = (attachment.filename == nil)
        }
    }

    func cancelLoad() {
        imageView.sd_cancelCurrentImageLoad()
    }

    @objc private func handleTap() {
        guard let attachment = attachment else { return }
        onTap?(attachment)
    }
}

// MARK: - AttachmentGridView

class AttachmentGridView: UIView {

    var onTapAttachment: ((HiveChatMessageAttachment) -> Void)?

    private let outerStack: UIStackView = {
        let sv = UIStackView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.axis = .vertical
        sv.spacing = 4
        sv.distribution = .fill
        return sv
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        addSubview(outerStack)
        NSLayoutConstraint.activate([
            outerStack.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            outerStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            outerStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            outerStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
        ])
    }

    func configure(with attachments: [HiveChatMessageAttachment]) {
        // Remove existing rows
        outerStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let columns = 3
        var index = 0
        while index < attachments.count {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.spacing = 4
            rowStack.distribution = .fillEqually

            rowStack.translatesAutoresizingMaskIntoConstraints = false
            rowStack.heightAnchor.constraint(equalToConstant: 90).isActive = true

            let rowEnd = min(index + columns, attachments.count)
            for i in index..<rowEnd {
                let tile = AttachmentTileView()
                tile.configure(with: attachments[i])
                tile.onTap = { [weak self] attachment in
                    self?.onTapAttachment?(attachment)
                }
                rowStack.addArrangedSubview(tile)
            }

            // Fill remaining slots with invisible spacers for equal width
            let tilesInRow = rowEnd - index
            if tilesInRow < columns {
                for _ in tilesInRow..<columns {
                    let spacer = UIView()
                    spacer.isHidden = true
                    rowStack.addArrangedSubview(spacer)
                }
            }

            outerStack.addArrangedSubview(rowStack)
            index += columns
        }
    }

    func reset() {
        // Cancel any in-flight image loads before removing
        for rowStack in outerStack.arrangedSubviews.compactMap({ $0 as? UIStackView }) {
            for tile in rowStack.arrangedSubviews.compactMap({ $0 as? AttachmentTileView }) {
                tile.cancelLoad()
            }
        }
        outerStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        onTapAttachment = nil
    }
}
