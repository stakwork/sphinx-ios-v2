import Foundation
import UIKit

class BitTorrentSearchViewController : UIViewController {
    
    @IBOutlet weak var bitTorrentSearchTableView: UITableView!
    var bitTorrentSearchTableViewDataSource: BitTorrentSearchTableViewDataSource? = nil
    var selectedMagnetLink: String?
    var selectedMagnetDetails: MagnetDetailsResponse?
    
    @IBOutlet weak var bitTorrentDetailsModalView: UIView!
    @IBOutlet weak var bitTorrentAddTorrentButton: UIButton!
    @IBOutlet weak var bitTorrentModalTitle: UILabel!
    @IBOutlet weak var bitTorrentFilesTableView: UITableView!
    @IBOutlet weak var bitTorrentAddTorrentButtonContainerView: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        bitTorrentDetailsModalView.isHidden = true
        configureTableView()
    }
    
    static func instantiate() -> BitTorrentSearchViewController {
        let viewController = StoryboardScene
            .Dashboard
            .bitTorrentSearchViewController
            .instantiate()
        return viewController
    }
    
    func configureTableView() {
        bitTorrentSearchTableViewDataSource = BitTorrentSearchTableViewDataSource()
        
        bitTorrentSearchTableView.register(UINib(nibName: "BTSearchResultTableViewCell", bundle: nil), forCellReuseIdentifier: "BTSearchResultTableViewCell")
        bitTorrentSearchTableView.dataSource = bitTorrentSearchTableViewDataSource
        bitTorrentSearchTableView.delegate = bitTorrentSearchTableViewDataSource
        bitTorrentSearchTableViewDataSource?.linkedTableView = bitTorrentSearchTableView
        bitTorrentSearchTableViewDataSource?.searchBitTorrent()
        bitTorrentSearchTableViewDataSource?.getMagnetDetailsCallback = { [weak self] magnetLink, details in
            self?.showMagnetDetails(magnetLink: magnetLink, details: details)
        }
    }
    
    func showMagnetDetails(magnetLink: String, details: MagnetDetailsResponse?) {
        guard let magnetDetails = details else {
            AlertHelper.showAlert(title: "Unable to get magnet details", message: "")
            return
        }
        configureDetailsView(magnetLink: magnetLink, details: magnetDetails)
    }
    
    func configureDetailsView(magnetLink: String, details: MagnetDetailsResponse) {
        bitTorrentDetailsModalView.isHidden = false
        bitTorrentModalTitle.text = details.details?.name
        selectedMagnetLink = magnetLink
        selectedMagnetDetails = details
        bitTorrentDetailsModalView.layer.cornerRadius = 8.0
        bitTorrentAddTorrentButtonContainerView.layer.cornerRadius = bitTorrentAddTorrentButtonContainerView.frame.height/2.0
        bitTorrentAddTorrentButton.addTarget(self, action: #selector(addTorrentPressed), for: .touchUpInside)
    }
    
    @objc func addTorrentPressed() {
        guard let magnetLink = selectedMagnetLink, 
                let details = selectedMagnetDetails else {
            return
        }
        SphinxOnionManager.sharedInstance.downloadTorrentViaMagnet(
            magnetLink: magnetLink,
            magnetDetails: details,
            completion:{success in
                if(success){
                    NewMessageBubbleHelper().showGenericMessageView(text: "Torrent download started! Check back in a bit to consume your content")
                    self.bitTorrentDetailsModalView.isHidden = true
                }
                else{
                    NewMessageBubbleHelper().showGenericMessageView(text: "There is an issue downloading the torrent. Please try again")
                    self.bitTorrentDetailsModalView.isHidden = true
                }
            }
        )
    }
}
