import Foundation
import UIKit

enum DataSourceType {
    case searchResults
    case magnetDetails
}

class BitTorrentSearchTableViewDataSource: NSObject, UITableViewDataSource, UITableViewDelegate {
    var btSearchResults = [BTFeedSearchDataMapper]()
    var magnetFiles = [MagnetFile]()
    var linkedTableView: UITableView? = nil
    var getMagnetDetailsCallback: ((String, MagnetDetailsResponse?) -> Void)?
    var dataSourceType: DataSourceType = .searchResults

    override init() {
        super.init()
    }

    func searchBitTorrent() {
        SphinxOnionManager.sharedInstance.authorizeBT(callback: { success in
            if(success) {
                SphinxOnionManager.sharedInstance.searchAllTorrents(
                    keyword: "the matrix",
                    callback: { [self] results in
                        self.btSearchResults = results
                        linkedTableView?.reloadData()
                    }
                )
            }
        })
    }

    func updateMagnetFiles(_ files: [MagnetFile]) {
        self.magnetFiles = files
        linkedTableView?.reloadData()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch dataSourceType {
        case .searchResults:
            return btSearchResults.count
        case .magnetDetails:
            return magnetFiles.count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch dataSourceType {
        case .searchResults:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "BTSearchResultTableViewCell", for: indexPath) as? BTSearchResultTableViewCell else {
                fatalError("Unexpected cell type")
            }
            let result = btSearchResults[indexPath.row]
            cell.configure(withTitle: result.name ?? "", seeders: result.seeders ?? 0)
            cell.isLoading = true
            return cell
        case .magnetDetails:
            let cell = tableView.dequeueReusableCell(withIdentifier: "BTFileTableViewCell", for: indexPath)
            let file = magnetFiles[indexPath.row]
            cell.textLabel?.text = file.name
            cell.textLabel?.font = UIFont(name: "Roboto", size: 12.0)
            cell.isUserInteractionEnabled = false
            return cell
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch dataSourceType {
        case .searchResults:
            let result = btSearchResults[indexPath.row]
            if let magnetLink = result.magnet_link {
                SphinxOnionManager.sharedInstance.getMagnetDetails(
                    data: result,
                    callback: { detailsResponse in
                        if let responseCallback = self.getMagnetDetailsCallback {
                            responseCallback(magnetLink, detailsResponse)
                        }
                    }
                )
            }
        case .magnetDetails:
            // Handle file selection if needed
            break
        }
    }

    // Set the height for the cells
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80.0
    }
}
