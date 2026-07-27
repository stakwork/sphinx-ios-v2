//
//  PendingAttachmentsBarView.swift
//  sphinx
//
//  Horizontally-scrolling bar that shows selected-but-not-yet-sent image thumbnails.
//  Height is managed externally via a constraint in TaskChatViewController.
//

import UIKit

class PendingAttachmentsBarView: UIScrollView {

    // Called when the user taps the × dismiss button on a cell.
    var onRemove: ((UUID) -> Void)?

    // MARK: - Private

    private let stackView: UIStackView = {
        let sv = UIStackView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.axis = .horizontal
        sv.spacing = 8
        sv.alignment = .center
        return sv
    }()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        alwaysBounceHorizontal = true
        backgroundColor = UIColor.Sphinx.HeaderBG

        addSubview(stackView)

        let contentGuide = contentLayoutGuide
        let frameGuide = frameLayoutGuide

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: contentGuide.topAnchor, constant: 8),
            stackView.leadingAnchor.constraint(equalTo: contentGuide.leadingAnchor, constant: 12),
            stackView.trailingAnchor.constraint(equalTo: contentGuide.trailingAnchor, constant: -12),
            stackView.bottomAnchor.constraint(equalTo: contentGuide.bottomAnchor, constant: -8),
            // Fix height to the scroll view's visible frame height so only horizontal scrolling occurs.
            stackView.heightAnchor.constraint(equalTo: frameGuide.heightAnchor, constant: -16)
        ])
    }

    // MARK: - Public API

    /// Rebuilds the stack from the given attachment list. Call on the main thread.
    func configure(with attachments: [PendingAttachment]) {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for attachment in attachments {
            let cell = ThumbnailCell(attachment: attachment) { [weak self] id in
                self?.onRemove?(id)
            }
            stackView.addArrangedSubview(cell)
        }
    }
}

// MARK: - ThumbnailCell

private class ThumbnailCell: UIView {

    private let attachment: PendingAttachment
    private let onRemove: (UUID) -> Void

    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 8
        return iv
    }()

    private let spinner: UIActivityIndicatorView = {
        let s = UIActivityIndicatorView(style: .medium)
        s.translatesAutoresizingMaskIntoConstraints = false
        s.hidesWhenStopped = true
        s.color = .white
        return s
    }()

    private let failureOverlay: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = UIColor.red.withAlphaComponent(0.55)
        v.layer.cornerRadius = 8
        v.isHidden = true
        return v
    }()

    private let failureIcon: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.image = UIImage(systemName: "exclamationmark.triangle")
        iv.tintColor = .white
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private let removeButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        let img = UIImage(systemName: "xmark.circle.fill")
        btn.setImage(img, for: .normal)
        btn.tintColor = UIColor.Sphinx.PrimaryRed
        return btn
    }()

    init(attachment: PendingAttachment, onRemove: @escaping (UUID) -> Void) {
        self.attachment = attachment
        self.onRemove = onRemove
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false

        // Fixed 72×72 cell
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 72),
            heightAnchor.constraint(equalToConstant: 72)
        ])

        addSubview(imageView)
        addSubview(failureOverlay)
        failureOverlay.addSubview(failureIcon)
        addSubview(spinner)
        addSubview(removeButton)

        NSLayoutConstraint.activate([
            // Image fills the cell
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),

            // Failure overlay also fills the cell
            failureOverlay.topAnchor.constraint(equalTo: topAnchor),
            failureOverlay.leadingAnchor.constraint(equalTo: leadingAnchor),
            failureOverlay.trailingAnchor.constraint(equalTo: trailingAnchor),
            failureOverlay.bottomAnchor.constraint(equalTo: bottomAnchor),

            // Failure icon centered in overlay
            failureIcon.centerXAnchor.constraint(equalTo: failureOverlay.centerXAnchor),
            failureIcon.centerYAnchor.constraint(equalTo: failureOverlay.centerYAnchor),
            failureIcon.widthAnchor.constraint(equalToConstant: 28),
            failureIcon.heightAnchor.constraint(equalToConstant: 28),

            // Spinner centered
            spinner.centerXAnchor.constraint(equalTo: centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: centerYAnchor),

            // × button — top-right corner, 20×20
            removeButton.topAnchor.constraint(equalTo: topAnchor, constant: -4),
            removeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 4),
            removeButton.widthAnchor.constraint(equalToConstant: 20),
            removeButton.heightAnchor.constraint(equalToConstant: 20)
        ])

        imageView.image = attachment.image

        switch attachment.state {
        case .uploading:
            spinner.startAnimating()
            failureOverlay.isHidden = true
        case .done:
            spinner.stopAnimating()
            failureOverlay.isHidden = true
        case .failed:
            spinner.stopAnimating()
            failureOverlay.isHidden = false
        }

        removeButton.addTarget(self, action: #selector(removeTapped), for: .touchUpInside)
    }

    @objc private func removeTapped() {
        onRemove(attachment.id)
    }
}
