import UIKit

class WorkspaceFeatureTableViewCell: UITableViewCell {
    
    static let reuseID = "WorkspaceFeatureTableViewCell"
    static var nib: UINib {
        return UINib(nibName: "WorkspaceFeatureTableViewCell", bundle: nil)
    }
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var statusBadge: UILabel!
    @IBOutlet weak var priorityBadge: UILabel!
    @IBOutlet weak var createdByLabel: UILabel!
    @IBOutlet weak var updatedAtLabel: UILabel!
    @IBOutlet weak var separatorView: UIView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        selectionStyle = .none
        backgroundColor = .Sphinx.HeaderBG
        contentView.backgroundColor = .Sphinx.HeaderBG
        
        titleLabel.textColor = .Sphinx.Text
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        titleLabel.numberOfLines = 2
        
        createdByLabel.textColor = .Sphinx.SecondaryText
        createdByLabel.font = UIFont(name: "Roboto-Regular", size: 13)
        
        updatedAtLabel.textColor = .Sphinx.SecondaryText
        updatedAtLabel.font = UIFont(name: "Roboto-Regular", size: 13)
        
        [statusBadge, priorityBadge].forEach {
            $0?.layer.cornerRadius = 10
            $0?.clipsToBounds = true
            $0?.textColor = .white
            $0?.font = UIFont(name: "Roboto-Medium", size: 11)
            $0?.textAlignment = .center
        }
        
        separatorView.backgroundColor = .Sphinx.Divider
    }
    
    func configure(with feature: HiveFeature, isLastRow: Bool) {
        titleLabel.text = feature.title
        
        // Created by
        if let name = feature.createdBy?.name, !name.isEmpty {
            createdByLabel.text = name
        } else {
            createdByLabel.text = nil
        }
        
        // Updated at
        updatedAtLabel.text = formatDate(feature.updatedAt)
        
        // Status badge
        if let status = feature.status, !status.isEmpty {
            statusBadge.isHidden = false
            statusBadge.text = "  \(status.uppercased())  "
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
    
    private func formatDate(_ dateString: String?) -> String {
        guard let dateString = dateString else { return "" }
        
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = isoFormatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "MMM dd, yyyy"
            return displayFormatter.string(from: date)
        }
        
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "MMM dd, yyyy"
            return displayFormatter.string(from: date)
        }
        
        return dateString
    }

    private func statusColor(for status: String) -> UIColor {
        switch status.uppercased() {
        case "COMPLETED", "DONE":
            return .Sphinx.PrimaryGreen
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
