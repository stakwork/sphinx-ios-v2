import UIKit

@MainActor protocol WorkspaceFeatureTableViewCellDelegate: AnyObject {
    func cell(_ cell: WorkspaceFeatureTableViewCell, didTapStatusFor featureId: String)
    func cell(_ cell: WorkspaceFeatureTableViewCell, didTapPriorityFor featureId: String)
}

class WorkspaceFeatureTableViewCell: UITableViewCell {

    weak var delegate: WorkspaceFeatureTableViewCellDelegate?
    private var featureId: String?
    
    static let reuseID = "WorkspaceFeatureTableViewCell"
    static var nib: UINib {
        return UINib(nibName: "WorkspaceFeatureTableViewCell", bundle: nil)
    }

    /// Minimum row height that fits all visible elements without overlap:
    /// top(12) + title-2lines(36) + createdBy-fixed-at(81) + createdBy(16) + gap(12) + separator(1) = 110pt
    static let cellHeight: CGFloat = 110
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var statusBadge: UILabel!
    @IBOutlet weak var priorityBadge: UILabel!
    @IBOutlet weak var createdByLabel: UILabel!
    @IBOutlet weak var updatedAtLabel: UILabel!
    @IBOutlet weak var separatorView: UIView!
    @IBOutlet weak var ownerImageView: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()

        MainActor.assumeIsolated {
            backgroundColor = .Sphinx.Body
            contentView.backgroundColor = .Sphinx.Body

            // Enforce minimum cell height so all elements are always visible without overlap
            contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: WorkspaceFeatureTableViewCell.cellHeight).isActive = true

            titleLabel.textColor = .Sphinx.Text
            titleLabel.font = UIFont.systemFont(ofSize: 15, weight: .medium)
            titleLabel.numberOfLines = 2
            // Fix to exactly 2-line height so the row never collapses for short titles
            titleLabel.heightAnchor.constraint(equalToConstant: 36).isActive = true

            createdByLabel.textColor = .Sphinx.SecondaryText
            createdByLabel.font = UIFont(name: "Roboto-Regular", size: 13)

            updatedAtLabel.textColor = .Sphinx.SecondaryText
            updatedAtLabel.font = UIFont(name: "Roboto-Regular", size: 13)

            [statusBadge, priorityBadge].forEach {
                $0?.layer.cornerRadius = 10
                $0?.clipsToBounds = true
                $0?.textColor = .white
                $0?.font = UIFont(name: "Roboto-Medium", size: 10) ?? UIFont.systemFont(ofSize: 10, weight: .medium)
                $0?.textAlignment = .center
                $0?.isUserInteractionEnabled = true
            }

            let statusTap = UITapGestureRecognizer(target: self, action: #selector(statusBadgeTapped))
            statusBadge.addGestureRecognizer(statusTap)

            let priorityTap = UITapGestureRecognizer(target: self, action: #selector(priorityBadgeTapped))
            priorityBadge.addGestureRecognizer(priorityTap)

            separatorView.backgroundColor = .Sphinx.LightDivider

            ownerImageView.layer.cornerRadius = 9
            ownerImageView.clipsToBounds = true
            ownerImageView.contentMode = .scaleAspectFill
            ownerImageView.isHidden = true
        }
    }
    
    func configure(with feature: HiveFeature, isLastRow: Bool) {
        featureId = feature.id
        titleLabel.text = feature.title
        
        // Created by
        if let name = feature.createdBy?.name, !name.isEmpty {
            createdByLabel.text = "Created by \(name)"
        } else {
            createdByLabel.text = nil
        }
        
        // Owner avatar
        if let imageUrl = feature.createdBy?.image, let url = URL(string: imageUrl) {
            ownerImageView.isHidden = false
            ownerImageView.sd_setImage(with: url, placeholderImage: UIImage(named: "profile_avatar"))
        } else {
            ownerImageView.isHidden = true
            ownerImageView.image = nil
        }
        
        // Updated at
        updatedAtLabel.text = formatDate(feature.updatedAt)
        
        // Status badge
        if let status = feature.status, !status.isEmpty {
            statusBadge.isHidden = false
            let displayStatus = status
                .replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(of: "-", with: " ")
                .uppercased()
            statusBadge.text = "  \(displayStatus)  "
            statusBadge.backgroundColor = statusColor(for: status)
        } else {
            statusBadge.isHidden = true
        }
        
        // Priority badge
        if let priority = feature.priority, !priority.isEmpty {
            priorityBadge.isHidden = false
            priorityBadge.text = "  \(priority.uppercased())  "
            priorityBadge.backgroundColor = priorityColor(for: priority)
        } else {
            priorityBadge.isHidden = true
        }
        
        separatorView.isHidden = isLastRow
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        ownerImageView.sd_cancelCurrentImageLoad()
        ownerImageView.image = nil
        ownerImageView.isHidden = true
        delegate = nil
        featureId = nil
    }

    @objc private func statusBadgeTapped() {
        guard let featureId = featureId else { return }
        delegate?.cell(self, didTapStatusFor: featureId)
    }

    @objc private func priorityBadgeTapped() {
        guard let featureId = featureId else { return }
        delegate?.cell(self, didTapPriorityFor: featureId)
    }
    
    private func formatDate(_ dateString: String?) -> String {
        guard let dateString = dateString else { return "" }
        
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = isoFormatter.date(from: dateString)
        
        if date == nil {
            isoFormatter.formatOptions = [.withInternetDateTime]
            date = isoFormatter.date(from: dateString)
        }
        
        guard let date = date else { return dateString }
        
        let now = Date()
        let seconds = now.timeIntervalSince(date)
        let minutes = seconds / 60
        let hours = seconds / 3600
        let days = seconds / 86400
        
        if seconds < 60 {
            return "Just now"
        } else if minutes < 60 {
            let m = Int(minutes)
            return "\(m) \(m == 1 ? "min" : "mins") ago"
        } else if hours < 24 {
            let h = Int(hours)
            return "\(h) \(h == 1 ? "hr" : "hrs") ago"
        } else if days < 2 {
            return "Yesterday"
        } else {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "MMM d, yyyy"
            return displayFormatter.string(from: date)
        }
    }

    private func statusColor(for status: String) -> UIColor {
        switch status.uppercased() {
        case "COMPLETED", "DONE":
            return .Sphinx.GreenBorder
        case "IN_PROGRESS":
            return .Sphinx.PrimaryBlue
        case "BLOCKED":
            return .Sphinx.PrimaryRed
        default:
            return .systemGray
        }
    }

    private func priorityColor(for priority: String) -> UIColor {
        switch priority.uppercased() {
        case "CRITICAL":
            return .Sphinx.PrimaryRed
        case "HIGH":
            return .Sphinx.SphinxOrange
        case "MEDIUM":
            return .Sphinx.PrimaryBlue
        default:
            return .systemGray
        }
    }
}
