import UIKit

class WorkspaceFeatureTableViewCell: UITableViewCell {
    
    static let reuseID = "WorkspaceFeatureTableViewCell"
    static var nib: UINib {
        return UINib(nibName: "WorkspaceFeatureTableViewCell", bundle: nil)
    }
    
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var statusBadge: UILabel!
    @IBOutlet weak var separatorView: UIView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        selectionStyle = .none
        backgroundColor = .Sphinx.Body
        contentView.backgroundColor = .Sphinx.Body
        
        nameLabel.font = UIFont(name: "Roboto-Medium", size: 16)
        nameLabel.textColor = .Sphinx.Text
        
        statusBadge.font = UIFont(name: "Roboto-Medium", size: 11)
        statusBadge.textColor = .white
        statusBadge.layer.cornerRadius = 10
        statusBadge.layer.masksToBounds = true
        statusBadge.textAlignment = .center
        
        separatorView.backgroundColor = .Sphinx.LightDivider
    }
    
    func configure(with feature: HiveFeature, isLastRow: Bool) {
        nameLabel.text = feature.name
        
        // Map workflow status to badge
        if let status = feature.workflowStatus {
            statusBadge.isHidden = false
            statusBadge.text = "  \(status.uppercased())  "
            
            switch status.uppercased() {
            case "COMPLETED":
                statusBadge.backgroundColor = .Sphinx.PrimaryGreen
            case "IN_PROGRESS":
                statusBadge.backgroundColor = .Sphinx.PrimaryBlue
            default:
                statusBadge.backgroundColor = .systemGray
            }
        } else {
            statusBadge.isHidden = true
        }
        
        separatorView.isHidden = isLastRow
    }
}
