import Foundation
import UIKit

class BitTorrentSearchViewController: UIViewController {

    @IBOutlet weak var bitTorrentSearchTableView: UITableView!
    @IBOutlet weak var bitTorrentDetailsModalView: UIView!
    @IBOutlet weak var bitTorrentAddTorrentButton: UIButton!
    @IBOutlet weak var bitTorrentModalTitle: UILabel!
    @IBOutlet weak var bitTorrentFilesTableView: UITableView!
    @IBOutlet weak var bitTorrentAddTorrentButtonContainerView: UIView!
    @IBOutlet weak var bitTorrentAddButtonActivityView: UIActivityIndicatorView!
    @IBOutlet weak var bitTorrentCancelButtonContainerView: UIView!
    @IBOutlet weak var bitTorrentCancelButton: UIButton!
    
    var bitTorrentSearchTableViewDataSource: BitTorrentSearchTableViewDataSource? = nil
    var selectedMagnetLink: String?
    var selectedMagnetDetails: MagnetDetailsResponse?
    var isLoadingTorrent : Bool = false{
        didSet{
            if(isLoadingTorrent){
                bitTorrentAddButtonActivityView.isHidden = false
                bitTorrentAddButtonActivityView.startAnimating()
                bitTorrentAddTorrentButtonContainerView.isUserInteractionEnabled = false
            }
            else{
                bitTorrentAddButtonActivityView.isHidden = true
                bitTorrentAddButtonActivityView.stopAnimating()
                bitTorrentAddTorrentButtonContainerView.isUserInteractionEnabled = true
            }
        }
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        bitTorrentDetailsModalView.isHidden = true
        configureTableView()
        isLoadingTorrent = false
    }

    static func instantiate() -> BitTorrentSearchViewController {
        let viewController = StoryboardScene
            .Dashboard
            .bitTorrentSearchViewController
            .instantiate()
        return viewController
    }
    
    func updateSearchTerm(keyword:String){
        bitTorrentSearchTableViewDataSource?.searchBitTorrent(keyword: keyword)
    }

    func configureTableView() {
        bitTorrentSearchTableViewDataSource = BitTorrentSearchTableViewDataSource()
        bitTorrentSearchTableViewDataSource?.dataSourceType = .searchResults

        bitTorrentSearchTableView.register(UINib(nibName: "BTSearchResultTableViewCell", bundle: nil), forCellReuseIdentifier: "BTSearchResultTableViewCell")
        bitTorrentSearchTableView.dataSource = bitTorrentSearchTableViewDataSource
        bitTorrentSearchTableView.delegate = bitTorrentSearchTableViewDataSource
        bitTorrentSearchTableViewDataSource?.linkedTableView = bitTorrentSearchTableView
        bitTorrentSearchTableViewDataSource?.searchBitTorrent(keyword: "hercules")
        bitTorrentSearchTableViewDataSource?.getMagnetDetailsCallback = { [weak self] magnetLink, details in
            self?.showMagnetDetails(magnetLink: magnetLink, details: details)
        }
    }

    func configureFilesTableView() {
        bitTorrentSearchTableViewDataSource = BitTorrentSearchTableViewDataSource()
        bitTorrentSearchTableViewDataSource?.dataSourceType = .magnetDetails

        bitTorrentFilesTableView.register(UITableViewCell.self, forCellReuseIdentifier: "BTFileTableViewCell")
        bitTorrentFilesTableView.dataSource = bitTorrentSearchTableViewDataSource
        bitTorrentFilesTableView.delegate = bitTorrentSearchTableViewDataSource
        bitTorrentSearchTableViewDataSource?.linkedTableView = bitTorrentFilesTableView
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
        bitTorrentModalTitle.adjustsFontSizeToFitWidth = true
        selectedMagnetLink = magnetLink
        selectedMagnetDetails = details
        bitTorrentDetailsModalView.layer.cornerRadius = 8.0
        bitTorrentAddTorrentButtonContainerView.layer.cornerRadius = bitTorrentAddTorrentButtonContainerView.frame.height / 2.0
        bitTorrentCancelButtonContainerView.layer.cornerRadius = bitTorrentCancelButtonContainerView.frame.height / 2.0
        configureFilesTableView()
        bitTorrentSearchTableViewDataSource?.updateMagnetFiles(details.details?.files ?? [])
        bitTorrentAddTorrentButton.addTarget(self, action: #selector(addTorrentPressed), for: .touchUpInside)
        bitTorrentCancelButton.addTarget(self, action: #selector(cancelAddTorrent), for: .touchUpInside)
    }
    
    @objc func cancelAddTorrent() {
        self.bitTorrentDetailsModalView.isHidden = true
    }

    @objc func addTorrentPressed() {
        guard let magnetLink = selectedMagnetLink,
              let details = selectedMagnetDetails else {
            return
        }
        isLoadingTorrent = true
        SphinxOnionManager.sharedInstance.downloadTorrentViaMagnet(
            magnetLink: magnetLink,
            magnetDetails: details,
            completion: { success in
                self.isLoadingTorrent = false
                if (success) {
                    NewMessageBubbleHelper().showGenericMessageView(text: "Torrent download started! Check back in a bit to consume your content")
                    self.bitTorrentDetailsModalView.isHidden = true
                } else {
                    NewMessageBubbleHelper().showGenericMessageView(text: "There is an issue downloading the torrent. Please try again")
                    self.bitTorrentDetailsModalView.isHidden = true
                }
            }
        )
    }
    
    func clearResults() {
        bitTorrentSearchTableViewDataSource?.btSearchResults = []
        bitTorrentSearchTableView.reloadData()
    }
}
