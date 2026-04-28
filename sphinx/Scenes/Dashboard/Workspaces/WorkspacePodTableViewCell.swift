//
//  WorkspacePodTableViewCell.swift
//  sphinx
//
//  Created on 2025-03-25.
//  Copyright © 2025 sphinx. All rights reserved.
//

import UIKit
import SDWebImage

class WorkspacePodTableViewCell: UITableViewCell {

    static let reuseID = "WorkspacePodTableViewCell"

    // MARK: - UI Elements

    private let statusDot: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.layer.cornerRadius = 5
        v.clipsToBounds = true
        return v
    }()

    private let creatorAvatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 12
        iv.isHidden = true
        return iv
    }()

    private let podNameLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = UIFont(name: "Roboto-Medium", size: 15) ?? UIFont.systemFont(ofSize: 15, weight: .medium)
        l.textColor = .Sphinx.Text
        l.numberOfLines = 1
        return l
    }()

    private lazy var nameStackView: UIStackView = {
        let sv = UIStackView(arrangedSubviews: [creatorAvatarImageView, podNameLabel])
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.axis = .horizontal
        sv.spacing = 6
        sv.alignment = .center
        return sv
    }()

    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = UIFont(name: "Roboto-Regular", size: 13) ?? UIFont.systemFont(ofSize: 13)
        l.textColor = .Sphinx.SecondaryText
        l.numberOfLines = 1
        return l
    }()

    // CPU row
    private let cpuTitleLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = UIFont(name: "Roboto-Regular", size: 12) ?? UIFont.systemFont(ofSize: 12)
        l.textColor = .Sphinx.SecondaryText
        l.text = "CPU"
        return l
    }()

    private let cpuProgressView: UIProgressView = {
        let p = UIProgressView(progressViewStyle: .default)
        p.translatesAutoresizingMaskIntoConstraints = false
        p.layer.cornerRadius = 3
        p.clipsToBounds = true
        return p
    }()

    private let cpuPercentLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = UIFont(name: "Roboto-Regular", size: 12) ?? UIFont.systemFont(ofSize: 12)
        l.textColor = .Sphinx.SecondaryText
        l.textAlignment = .right
        l.setContentHuggingPriority(.required, for: .horizontal)
        return l
    }()

    // Memory row
    private let memTitleLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = UIFont(name: "Roboto-Regular", size: 12) ?? UIFont.systemFont(ofSize: 12)
        l.textColor = .Sphinx.SecondaryText
        l.text = "Memory"
        return l
    }()

    private let memProgressView: UIProgressView = {
        let p = UIProgressView(progressViewStyle: .default)
        p.translatesAutoresizingMaskIntoConstraints = false
        p.layer.cornerRadius = 3
        p.clipsToBounds = true
        return p
    }()

    private let memPercentLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = UIFont(name: "Roboto-Regular", size: 12) ?? UIFont.systemFont(ofSize: 12)
        l.textColor = .Sphinx.SecondaryText
        l.textAlignment = .right
        l.setContentHuggingPriority(.required, for: .horizontal)
        return l
    }()

    // Action buttons
    private let copyPasswordButton: UIButton = {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setTitle("Copy Password", for: .normal)
        b.titleLabel?.font = UIFont(name: "Roboto-Medium", size: 13) ?? UIFont.systemFont(ofSize: 13, weight: .medium)
        b.setTitleColor(.Sphinx.PrimaryBlue, for: .normal)
        b.layer.borderColor = UIColor.Sphinx.PrimaryBlue.cgColor
        b.layer.borderWidth = 1
        b.layer.cornerRadius = 6
        b.contentEdgeInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        return b
    }()

    private let openIDEButton: UIButton = {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setTitle("Open IDE", for: .normal)
        b.titleLabel?.font = UIFont(name: "Roboto-Medium", size: 13) ?? UIFont.systemFont(ofSize: 13, weight: .medium)
        b.setTitleColor(.white, for: .normal)
        b.backgroundColor = .Sphinx.PrimaryBlue
        b.layer.cornerRadius = 6
        b.contentEdgeInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        return b
    }()

    private var currentPod: WorkspacePod?

    // MARK: - Toggling Constraints
    private var subtitleHeightConstraint: NSLayoutConstraint!
    private var cpuTopToSubtitle: NSLayoutConstraint!
    private var cpuTopToPodName: NSLayoutConstraint!

    // MARK: - Init

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
        setupConstraints()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupViews() {
        backgroundColor = .Sphinx.Body
        selectionStyle = .none

        contentView.addSubview(statusDot)
        contentView.addSubview(nameStackView)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(cpuTitleLabel)
        contentView.addSubview(cpuProgressView)
        contentView.addSubview(cpuPercentLabel)
        contentView.addSubview(memTitleLabel)
        contentView.addSubview(memProgressView)
        contentView.addSubview(memPercentLabel)
        contentView.addSubview(copyPasswordButton)
        contentView.addSubview(openIDEButton)

        copyPasswordButton.addTarget(self, action: #selector(copyPasswordTapped), for: .touchUpInside)
        openIDEButton.addTarget(self, action: #selector(openIDETapped), for: .touchUpInside)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Status dot — top-left
            statusDot.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            statusDot.topAnchor.constraint(equalTo: nameStackView.topAnchor, constant: 3),
            statusDot.widthAnchor.constraint(equalToConstant: 10),
            statusDot.heightAnchor.constraint(equalToConstant: 10),

            // Name stack (avatar + pod name label) — next to dot
            nameStackView.leadingAnchor.constraint(equalTo: statusDot.trailingAnchor, constant: 8),
            nameStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            nameStackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),

            // Avatar size
            creatorAvatarImageView.widthAnchor.constraint(equalToConstant: 24),
            creatorAvatarImageView.heightAnchor.constraint(equalToConstant: 24),

            // Subtitle label — below name stack
            subtitleLabel.leadingAnchor.constraint(equalTo: nameStackView.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: nameStackView.trailingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: nameStackView.bottomAnchor, constant: 2),

            // CPU row — title
            cpuTitleLabel.leadingAnchor.constraint(equalTo: nameStackView.leadingAnchor),
            cpuTitleLabel.widthAnchor.constraint(equalToConstant: 52),

            // CPU percent label
            cpuPercentLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            cpuPercentLabel.centerYAnchor.constraint(equalTo: cpuTitleLabel.centerYAnchor),
            cpuPercentLabel.widthAnchor.constraint(equalToConstant: 48),

            // CPU progress view
            cpuProgressView.leadingAnchor.constraint(equalTo: cpuTitleLabel.trailingAnchor, constant: 6),
            cpuProgressView.trailingAnchor.constraint(equalTo: cpuPercentLabel.leadingAnchor, constant: -4),
            cpuProgressView.centerYAnchor.constraint(equalTo: cpuTitleLabel.centerYAnchor),
            cpuProgressView.heightAnchor.constraint(equalToConstant: 6),

            // Memory row — title
            memTitleLabel.leadingAnchor.constraint(equalTo: nameStackView.leadingAnchor),
            memTitleLabel.topAnchor.constraint(equalTo: cpuTitleLabel.bottomAnchor, constant: 8),
            memTitleLabel.widthAnchor.constraint(equalToConstant: 52),

            // Memory percent label
            memPercentLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            memPercentLabel.centerYAnchor.constraint(equalTo: memTitleLabel.centerYAnchor),
            memPercentLabel.widthAnchor.constraint(equalToConstant: 48),

            // Memory progress view
            memProgressView.leadingAnchor.constraint(equalTo: memTitleLabel.trailingAnchor, constant: 6),
            memProgressView.trailingAnchor.constraint(equalTo: memPercentLabel.leadingAnchor, constant: -4),
            memProgressView.centerYAnchor.constraint(equalTo: memTitleLabel.centerYAnchor),
            memProgressView.heightAnchor.constraint(equalToConstant: 6),

            // Action buttons row
            copyPasswordButton.leadingAnchor.constraint(equalTo: nameStackView.leadingAnchor),
            copyPasswordButton.topAnchor.constraint(equalTo: memTitleLabel.bottomAnchor, constant: 10),
            copyPasswordButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),

            openIDEButton.leadingAnchor.constraint(equalTo: copyPasswordButton.trailingAnchor, constant: 8),
            openIDEButton.centerYAnchor.constraint(equalTo: copyPasswordButton.centerYAnchor),
        ])

        subtitleHeightConstraint = subtitleLabel.heightAnchor.constraint(equalToConstant: 0)
        cpuTopToSubtitle = cpuTitleLabel.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 8)
        cpuTopToPodName  = cpuTitleLabel.topAnchor.constraint(equalTo: nameStackView.bottomAnchor, constant: 8)
        // Default state: no subtitle
        subtitleHeightConstraint.isActive = true
        cpuTopToPodName.isActive = true
    }

    // MARK: - Reuse

    override func prepareForReuse() {
        super.prepareForReuse()
        creatorAvatarImageView.sd_cancelCurrentImageLoad()
        creatorAvatarImageView.image = UIImage(named: "profileImageIcon")
        creatorAvatarImageView.isHidden = true
    }

    // MARK: - Configure

    func configure(with pod: WorkspacePod) {
        currentPod = pod

        statusDot.backgroundColor = pod.statusDotColor

        if let taskTitle = pod.assignedTaskTitle {
            podNameLabel.text = taskTitle
            creatorAvatarImageView.isHidden = false
            if let urlString = pod.assignedTaskCreatorImageUrl, let url = URL(string: urlString) {
                creatorAvatarImageView.sd_setImage(
                    with: url,
                    placeholderImage: UIImage(named: "profileImageIcon")
                )
            } else {
                creatorAvatarImageView.image = UIImage(named: "profileImageIcon")
            }
        } else {
            podNameLabel.text = pod.subdomain
            creatorAvatarImageView.isHidden = true
            creatorAvatarImageView.sd_cancelCurrentImageLoad()
        }

        if let sub = pod.subtitle {
            subtitleLabel.text = sub
            subtitleHeightConstraint.isActive = false
            cpuTopToPodName.isActive = false
            cpuTopToSubtitle.isActive = true
        } else {
            subtitleLabel.text = nil
            cpuTopToSubtitle.isActive = false
            cpuTopToPodName.isActive = true
            subtitleHeightConstraint.isActive = true
        }

        // CPU
        let cpuPct = pod.cpuPercentage
        cpuProgressView.setProgress(Float(cpuPct / 100), animated: false)
        cpuProgressView.progressTintColor = cpuPct > 70 ? .systemOrange : .Sphinx.PrimaryGreen
        cpuPercentLabel.text = String(format: "%.1f%%", cpuPct)

        // Memory
        let memPct = pod.memoryPercentage
        memProgressView.setProgress(Float(memPct / 100), animated: false)
        memProgressView.progressTintColor = memPct > 70 ? .systemOrange : .Sphinx.PrimaryGreen
        memPercentLabel.text = String(format: "%.1f%%", memPct)

        // Buttons
        copyPasswordButton.isHidden = pod.password == nil
        openIDEButton.isHidden = pod.url == nil
    }

    // MARK: - Actions

    @objc private func copyPasswordTapped() {
        guard let password = currentPod?.password else { return }
        ClipboardHelper.copyToClipboard(text: password, message: "Password copied")
    }

    @objc private func openIDETapped() {
        guard let urlString = currentPod?.url, let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
}
