//
//  WorkspaceTableViewCell.swift
//  sphinx
//
//  Created on 2025-02-18.
//  Copyright © 2025 sphinx. All rights reserved.
//

import UIKit
import SDWebImage

class WorkspaceTableViewCell: UITableViewCell {

    static let reuseID = "WorkspaceTableViewCell"

    static var nib: UINib {
        return UINib(nibName: "WorkspaceTableViewCell", bundle: nil)
    }

    @IBOutlet weak var workspaceNameLabel: UILabel!
    @IBOutlet weak var roleLabel: UILabel!
    @IBOutlet weak var membersLabel: UILabel!
    @IBOutlet weak var separatorView: UIView!

    private var logoImageView: UIImageView!
    private var logoUrl: String?

    private let logoSize: CGFloat = 40
    private let logoCornerRadius: CGFloat = 3

    override func awakeFromNib() {
        super.awakeFromNib()
        setupLogoImageView()
        setupCell()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        logoImageView.sd_cancelCurrentImageLoad()
        logoImageView.image = Self.placeholderImage
        logoUrl = nil
        workspaceSlug = nil
    }

    private static var placeholderImage: UIImage? = {
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)
        return UIImage(systemName: "square.grid.2x2", withConfiguration: config)?
            .withTintColor(.Sphinx.SecondaryText, renderingMode: .alwaysOriginal)
    }()

    private func setupLogoImageView() {
        logoImageView = UIImageView()
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        logoImageView.contentMode = .scaleAspectFill
        logoImageView.clipsToBounds = true
        logoImageView.layer.cornerRadius = logoCornerRadius
        logoImageView.backgroundColor = .Sphinx.HeaderBG
        logoImageView.image = Self.placeholderImage
        contentView.addSubview(logoImageView)

        NSLayoutConstraint.activate([
            logoImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            logoImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            logoImageView.widthAnchor.constraint(equalToConstant: logoSize),
            logoImageView.heightAnchor.constraint(equalToConstant: logoSize)
        ])
    }

    private func setupCell() {
        backgroundColor = .Sphinx.DashboardHeader
        contentView.backgroundColor = .Sphinx.DashboardHeader
        selectionStyle = .none

        workspaceNameLabel.textColor = .Sphinx.Text
        workspaceNameLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)

        roleLabel.textColor = .Sphinx.SecondaryText
        roleLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)

        membersLabel.textColor = .Sphinx.SecondaryText
        membersLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)

        separatorView.backgroundColor = .Sphinx.Divider
    }

    private var workspaceSlug: String?

    func configure(with workspace: Workspace, isLastRow: Bool) {
        workspaceNameLabel.text = workspace.name
        roleLabel.text = workspace.formattedRole
        membersLabel.text = workspace.membersText
        separatorView.isHidden = isLastRow

        workspaceSlug = workspace.slug
        loadLogo(forSlug: workspace.slug)
    }

    private func loadLogo(forSlug slug: String?) {
        guard let slug = slug else {
            logoImageView.image = Self.placeholderImage
            logoUrl = nil
            return
        }

        // Check if we already have a cached URL for this slug
        if let cachedUrl = WorkspaceImageCache.shared.getImageUrl(forSlug: slug) {
            loadImage(from: cachedUrl)
            return
        }

        // Fetch the presigned URL from the API
        API.sharedInstance.fetchWorkspaceImageWithAuth(
            slug: slug,
            callback: { [weak self] imageUrl in
                DispatchQueue.main.async {
                    guard let self = self, self.workspaceSlug == slug else { return }

                    if let imageUrl = imageUrl {
                        self.loadImage(from: imageUrl)
                    } else {
                        self.logoImageView.image = Self.placeholderImage
                    }
                }
            },
            errorCallback: { [weak self] in
                DispatchQueue.main.async {
                    guard let self = self, self.workspaceSlug == slug else { return }
                    self.logoImageView.image = Self.placeholderImage
                }
            }
        )
    }

    private func loadImage(from urlString: String) {
        guard let url = URL(string: urlString) else {
            logoImageView.image = Self.placeholderImage
            logoUrl = nil
            return
        }

        if logoUrl == urlString {
            return
        }

        let requestedUrl = urlString
        logoUrl = requestedUrl

        logoImageView.sd_cancelCurrentImageLoad()
        logoImageView.sd_setImage(
            with: url,
            placeholderImage: Self.placeholderImage,
            options: [.scaleDownLargeImages],
            completed: { [weak self] (image, error, _, _) in
                guard let self = self, self.logoUrl == requestedUrl else { return }

                if error != nil {
                    self.logoImageView.image = Self.placeholderImage
                }
            }
        )
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        if selected {
            contentView.backgroundColor = .Sphinx.DashboardHeader.withAlphaComponent(0.8)
        } else {
            contentView.backgroundColor = .Sphinx.DashboardHeader
        }
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)

        if highlighted {
            contentView.backgroundColor = .Sphinx.DashboardHeader.withAlphaComponent(0.8)
        } else {
            contentView.backgroundColor = .Sphinx.DashboardHeader
        }
    }
}
