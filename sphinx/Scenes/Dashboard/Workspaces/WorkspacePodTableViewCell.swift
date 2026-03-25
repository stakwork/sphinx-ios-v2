//
//  WorkspacePodTableViewCell.swift
//  sphinx
//
//  Created on 2025-03-25.
//  Copyright © 2025 sphinx. All rights reserved.
//

import UIKit

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

    private let podNameLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = UIFont(name: "Roboto-Medium", size: 15) ?? UIFont.systemFont(ofSize: 15, weight: .medium)
        l.textColor = .Sphinx.Text
        l.numberOfLines = 1
        return l
    }()

    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = UIFont(name: "Roboto-Regular", size: 13) ?? UIFont.systemFont(ofSize: 13)
        l.textColor = .Sphinx.SecondaryText
        l.numberOfLines = 1
        return l
    }()

    private let userLabel: UILabel = {
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
        contentView.addSubview(podNameLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(userLabel)
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
            statusDot.topAnchor.constraint(equalTo: podNameLabel.topAnchor, constant: 3),
            statusDot.widthAnchor.constraint(equalToConstant: 10),
            statusDot.heightAnchor.constraint(equalToConstant: 10),

            // Pod name label — next to dot
            podNameLabel.leadingAnchor.constraint(equalTo: statusDot.trailingAnchor, constant: 8),
            podNameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            podNameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),

            // Subtitle label — below pod name
            subtitleLabel.leadingAnchor.constraint(equalTo: podNameLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: podNameLabel.trailingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: podNameLabel.bottomAnchor, constant: 2),

            // User label — below subtitle
            userLabel.leadingAnchor.constraint(equalTo: podNameLabel.leadingAnchor),
            userLabel.trailingAnchor.constraint(equalTo: podNameLabel.trailingAnchor),
            userLabel.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 2),

            // CPU row — title
            cpuTitleLabel.leadingAnchor.constraint(equalTo: podNameLabel.leadingAnchor),
            cpuTitleLabel.topAnchor.constraint(equalTo: userLabel.bottomAnchor, constant: 8),
            cpuTitleLabel.widthAnchor.constraint(equalToConstant: 52),

            // CPU percent label
            cpuPercentLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            cpuPercentLabel.centerYAnchor.constraint(equalTo: cpuTitleLabel.centerYAnchor),
            cpuPercentLabel.widthAnchor.constraint(equalToConstant: 44),

            // CPU progress view
            cpuProgressView.leadingAnchor.constraint(equalTo: cpuTitleLabel.trailingAnchor, constant: 6),
            cpuProgressView.trailingAnchor.constraint(equalTo: cpuPercentLabel.leadingAnchor, constant: -6),
            cpuProgressView.centerYAnchor.constraint(equalTo: cpuTitleLabel.centerYAnchor),
            cpuProgressView.heightAnchor.constraint(equalToConstant: 6),

            // Memory row — title
            memTitleLabel.leadingAnchor.constraint(equalTo: podNameLabel.leadingAnchor),
            memTitleLabel.topAnchor.constraint(equalTo: cpuTitleLabel.bottomAnchor, constant: 8),
            memTitleLabel.widthAnchor.constraint(equalToConstant: 52),

            // Memory percent label
            memPercentLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            memPercentLabel.centerYAnchor.constraint(equalTo: memTitleLabel.centerYAnchor),
            memPercentLabel.widthAnchor.constraint(equalToConstant: 44),

            // Memory progress view
            memProgressView.leadingAnchor.constraint(equalTo: memTitleLabel.trailingAnchor, constant: 6),
            memProgressView.trailingAnchor.constraint(equalTo: memPercentLabel.leadingAnchor, constant: -6),
            memProgressView.centerYAnchor.constraint(equalTo: memTitleLabel.centerYAnchor),
            memProgressView.heightAnchor.constraint(equalToConstant: 6),

            // Action buttons row
            copyPasswordButton.leadingAnchor.constraint(equalTo: podNameLabel.leadingAnchor),
            copyPasswordButton.topAnchor.constraint(equalTo: memTitleLabel.bottomAnchor, constant: 10),
            copyPasswordButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),

            openIDEButton.leadingAnchor.constraint(equalTo: copyPasswordButton.trailingAnchor, constant: 8),
            openIDEButton.centerYAnchor.constraint(equalTo: copyPasswordButton.centerYAnchor),
        ])
    }

    // MARK: - Configure

    func configure(with pod: WorkspacePod) {
        currentPod = pod

        statusDot.backgroundColor = pod.statusDotColor
        podNameLabel.text = pod.subdomain

        if let sub = pod.subtitle {
            subtitleLabel.text = sub
            subtitleLabel.isHidden = false
        } else {
            subtitleLabel.isHidden = true
        }

        if let user = pod.userInfo {
            userLabel.text = user
            userLabel.isHidden = false
        } else {
            userLabel.isHidden = true
        }

        // CPU
        let cpuPct = pod.cpuPercentage
        cpuProgressView.setProgress(Float(cpuPct / 100), animated: false)
        cpuProgressView.progressTintColor = cpuPct > 70 ? .systemOrange : .Sphinx.PrimaryGreen
        cpuPercentLabel.text = String(format: "%d%%", Int(cpuPct))

        // Memory
        let memPct = pod.memoryPercentage
        memProgressView.setProgress(Float(memPct / 100), animated: false)
        memProgressView.progressTintColor = memPct > 70 ? .systemOrange : .Sphinx.PrimaryGreen
        memPercentLabel.text = String(format: "%d%%", Int(memPct))

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
