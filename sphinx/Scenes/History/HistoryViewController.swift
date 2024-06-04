//
//  Library
//
//  Created by Tomas Timinskas on 19/04/2019.
//  Copyright © 2019 Sphinx. All rights reserved.
//

import UIKit
import ObjectMapper

class HistoryViewController: UIViewController {
    
    @IBOutlet weak var viewTitle: UILabel!
    @IBOutlet weak var headerView: UIView!
    @IBOutlet weak var historyTableView: UITableView!
    @IBOutlet weak var noResultsLabel: UILabel!
    @IBOutlet weak var loadingWheel: UIActivityIndicatorView!
    
    var historyDataSource : HistoryDataSource!
    
    var loading = false {
        didSet {
            LoadingWheelHelper.toggleLoadingWheel(loading: loading, loadingWheel: loadingWheel, loadingWheelColor: UIColor.Sphinx.Text)
        }
    }
    
    var page = 1
    var didReachLimit = false
    let itemsPerPage : UInt32 = 50
    
    static func instantiate() -> HistoryViewController {
        let viewController = StoryboardScene.History.historyViewController.instantiate()
        return viewController
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.accessibilityIdentifier = "HistoryViewController"
        setStatusBarColor()
        
        viewTitle.addTextSpacing(value: 2)
        headerView.addShadow(location: VerticalLocation.bottom, opacity: 0.2, radius: 2.0)
        configureTableView()
    }
    
    func configureTableView() {
        historyTableView.backgroundColor = UIColor.Sphinx.Body
        
        historyTableView.rowHeight = UITableView.automaticDimension
        historyTableView.estimatedRowHeight = 80
        
        historyTableView.registerCell(LoadingMoreTableViewCell.self)
        historyTableView.registerCell(TransactionTableViewCell.self)
        
        historyDataSource = HistoryDataSource(tableView: historyTableView, delegate: self)
        historyTableView.delegate = historyDataSource
        historyTableView.dataSource = historyDataSource
        
        //loading = true
        loading = false
        
        self.setNoResultsLabel(count: 0)
        self.checkResultsLimit(count: 0)
        
        SphinxOnionManager.sharedInstance.getTransactionHistory(
            handlePaymentHistoryCompletion: handlePaymentHistoryCompletion(jsonString:),
            itemsPerPage: itemsPerPage,
            sinceTimestamp: UInt64(Date().timeIntervalSince1970)
        )
        
    }
    
    func handlePaymentHistoryCompletion(
        jsonString:String?
    ){
        //1. Pull history with messages from local DB
        var history = [PaymentTransaction]()

        let messages = TransactionMessage.fetchTransactionMessagesForHistory()
        
        for message in messages{
            history.append(PaymentTransaction(fromTransactionMessage: message))
        }
        
        //2. Collect and process remote transactions not accounted for with messages
        if let jsonString = jsonString,
           let results = Mapper<PaymentTransactionFromServer>().mapArray(JSONString: jsonString){
            let localHistoryIndices = messages.map { $0.id }
            let unAccountedResults = results.filter({localHistoryIndices.contains($0.msg_idx ?? -21) == false})
            print(unAccountedResults)
        }
        
        self.setNoResultsLabel(count: history.count)
        self.checkResultsLimit(count: history.count)
        self.historyDataSource.loadTransactions(transactions: history)
        self.loading = false
    }
    
    func setNoResultsLabel(count: Int) {
        noResultsLabel.alpha = count > 0 ? 0.0 : 1.0
    }
    
    func checkResultsLimit(count: Int) {
        didReachLimit = count < itemsPerPage
    }
    
    @IBAction func closeButtonTouched() {
        setStatusBarColor()
        dismiss(animated: true, completion: nil)
    }
}

extension HistoryViewController : HistoryDataSourceDelegate {
    func shouldLoadMoreTransactions() {
        if didReachLimit {
            return
        }
        
        page = page + 1
//        
//        API.sharedInstance.getTransactionsList(page: page, itemsPerPage: itemsPerPage, callback: { transactions in
//            self.checkResultsLimit(count: transactions.count)
//            self.historyDataSource.addMoreTransactions(transactions: transactions)
//        }, errorCallback: { })
    }
}
