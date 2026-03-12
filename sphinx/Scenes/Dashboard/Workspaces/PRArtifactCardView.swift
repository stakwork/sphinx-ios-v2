//
//  PRArtifactCardView.swift
//  sphinx
//
//  Card view rendered inside a chat bubble for PULL_REQUEST artifacts.
//
//  Layout (top → bottom):
//  ┌──────────────────────────────────────────┐
//  │  ● MERGED/OPEN   #123                    │  ← status badge + PR number
//  │  feat: Add authentication                │  ← PR title (bold)
//  │  stakwork/hive                           │  ← repo name
//  │  ─────────────────────────────────────   │  ← divider
//  │  +125  -45  📄 8 files   ✓ 5/5 passed   │  ← stats row
//  │                          [ Open PR ↗ ]  │  ← link button
//  └──────────────────────────────────────────┘

import UIKit

class PRArtifactCardView: UIView {

    // MARK: - Subviews

    private let statusBadge: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = UIFont(name: "Roboto-Medium", size: 11) ?? UIFont.boldSystemFont(ofSize: 11)
        l.textColor = .white
        l.layer.cornerRadius = 8
        l.clipsToBounds = true
        l.textAlignment = .center
        return l
    }()

    private let prNumberLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = UIFont(name: "Roboto-Regular", size: 12) ?? UIFont.systemFont(ofSize: 12)
        l.textColor = UIColor.Sphinx.SecondaryText
        return l
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = UIFont(name: "Roboto-Medium", size: 14) ?? UIFont.boldSystemFont(ofSize: 14)
        l.textColor = UIColor.Sphinx.Text
        l.numberOfLines = 2
        return l
    }()

    private let repoLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = UIFont(name: "Roboto-Regular", size: 12) ?? UIFont.systemFont(ofSize: 12)
        l.textColor = UIColor.Sphinx.SecondaryText
        return l
    }()

    private let divider: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = UIColor.Sphinx.LightDivider
        return v
    }()

    private let additionsLabel: UILabel = makeStatLabel()
    private let deletionsLabel: UILabel = makeStatLabel()
    private let filesLabel: UILabel     = makeStatLabel()
    private let ciLabel: UILabel        = makeStatLabel()

    private let statsStack: UIStackView = {
        let sv = UIStackView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.axis = .horizontal
        sv.spacing = 10
        sv.alignment = .center
        return sv
    }()

    private let openButton: UIButton = {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setTitle("Open PR  ↗", for: .normal)
        b.titleLabel?.font = UIFont(name: "Roboto-Medium", size: 12) ?? UIFont.boldSystemFont(ofSize: 12)
        b.setTitleColor(.white, for: .normal)
        b.backgroundColor = UIColor.Sphinx.PrimaryBlue
        b.layer.cornerRadius = 12
        b.contentEdgeInsets = UIEdgeInsets(top: 5, left: 12, bottom: 5, right: 12)
        return b
    }()

    private var prURL: URL?

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = UIColor.Sphinx.Body
        layer.cornerRadius = 12
        layer.borderWidth = 1
        layer.borderColor = UIColor.Sphinx.LightDivider.cgColor
        clipsToBounds = true

        let topRow = UIStackView(arrangedSubviews: [statusBadge, prNumberLabel, UIView()])
        topRow.translatesAutoresizingMaskIntoConstraints = false
        topRow.axis = .horizontal
        topRow.spacing = 6
        topRow.alignment = .center

        statsStack.addArrangedSubview(additionsLabel)
        statsStack.addArrangedSubview(deletionsLabel)
        statsStack.addArrangedSubview(filesLabel)
        statsStack.addArrangedSubview(ciLabel)
        statsStack.addArrangedSubview(UIView()) // spacer

        statsStack.isHidden = true

        let bottomRow = UIStackView(arrangedSubviews: [statsStack, openButton])
        bottomRow.translatesAutoresizingMaskIntoConstraints = false
        bottomRow.axis = .horizontal
        bottomRow.spacing = 8
        bottomRow.alignment = .center

        [topRow, titleLabel, repoLabel, divider, bottomRow].forEach { addSubview($0) }

        NSLayoutConstraint.activate([
            topRow.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            topRow.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            topRow.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),

            titleLabel.topAnchor.constraint(equalTo: topRow.bottomAnchor, constant: 6),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),

            repoLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),
            repoLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            repoLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),

            divider.topAnchor.constraint(equalTo: repoLabel.bottomAnchor, constant: 10),
            divider.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            divider.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            divider.heightAnchor.constraint(equalToConstant: 1),

            bottomRow.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 10),
            bottomRow.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            bottomRow.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            bottomRow.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),

            statusBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 55),
            statusBadge.heightAnchor.constraint(equalToConstant: 18),
        ])

        openButton.addTarget(self, action: #selector(openPRTapped), for: .touchUpInside)
    }

    // MARK: - Configure

    func configure(with pr: PRContent) {
        // Status badge
        let status = pr.status?.uppercased() ?? "OPEN"
        statusBadge.text = "  \(status)  "
        switch status {
        case "DONE", "MERGED":
            statusBadge.backgroundColor = UIColor.Sphinx.PrimaryGreen
        case "CLOSED":
            statusBadge.backgroundColor = UIColor.Sphinx.PrimaryRed
        default: // OPEN, IN_PROGRESS, etc.
            statusBadge.backgroundColor = UIColor.Sphinx.PrimaryBlue
        }

        if let num = pr.number { prNumberLabel.text = "#\(num)" }
        titleLabel.text = pr.title ?? "Pull Request"
        repoLabel.text = pr.repo

        // Stats
        if let add = pr.additions {
            additionsLabel.text = "+\(add)"
            additionsLabel.textColor = UIColor.Sphinx.PrimaryGreen
        }
        if let del = pr.deletions {
            deletionsLabel.text = "-\(del)"
            deletionsLabel.textColor = UIColor.Sphinx.PrimaryRed
        }
        if let files = pr.changedFiles {
            filesLabel.text = "📄 \(files) \(files == 1 ? "file" : "files")"
            filesLabel.textColor = UIColor.Sphinx.SecondaryText
        }
        if let ci = pr.progress?.ciSummary, !ci.isEmpty {
            let passed = pr.progress?.ciStatus == "success"
            ciLabel.text = "\(passed ? "✓" : "✗") \(ci)"
            ciLabel.textColor = passed ? UIColor.Sphinx.PrimaryGreen : UIColor.Sphinx.PrimaryRed
        } else {
            ciLabel.isHidden = true
        }

        // Link button
        if let urlStr = pr.url, let url = URL(string: urlStr) {
            prURL = url
            openButton.isHidden = false
            let isMerged = status == "MERGED" || status == "DONE"
            openButton.setTitle(isMerged ? "Merged  ↗" : "Open PR  ↗", for: .normal)
            openButton.backgroundColor = isMerged
                ? UIColor(hex: "#8B5CF6")
                : UIColor.Sphinx.PrimaryBlue
        } else {
            openButton.isHidden = true
        }
    }

    @objc private func openPRTapped() {
        guard let url = prURL else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Helpers

    private static func makeStatLabel() -> UILabel {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = UIFont(name: "Roboto-Medium", size: 12) ?? UIFont.boldSystemFont(ofSize: 12)
        l.textColor = UIColor.Sphinx.SecondaryText
        return l
    }
}
