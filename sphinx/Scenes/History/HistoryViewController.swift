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
        
        loading = true
        checkResultsLimit(count: 0)
        
        SphinxOnionManager.sharedInstance.getTransactionsHistory(
            paymentsHistoryCallback: handlePaymentHistoryCompletion,
            itemsPerPage: itemsPerPage,
            sinceTimestamp: UInt64(Date().timeIntervalSince1970)
        )
        
    }
    
    func handlePaymentHistoryCompletion(
        jsonString: String?,
        error: String?
    ) {
        if let _ = error {
            setNoResultsLabel(count: 0)
            loading = false
            
            AlertHelper.showAlert(
                title: "generic.error.title".localized,
                message: "error.loading.transactions".localized
            )
            return
        }
        
        // 1. Pull history with messages from local DB
        var history = [PaymentTransaction]()
        
        let messages = TransactionMessage.fetchTransactionMessagesForHistory()
        
        for message in messages {
            history.append(PaymentTransaction(fromTransactionMessage: message))
        }
        
        // 2. Collect and process remote transactions not accounted for with messages
        if let jsonString = jsonString,
           let results = Mapper<PaymentTransactionFromServer>().mapArray(JSONString: jsonString) {
            let localHistoryIndices = messages.map { $0.id }
            let localHistoryPaymentHashes = messages.compactMap { $0.paymentHash } // Ensure no nil values
            
            let unAccountedResults = results.filter { result in
                let msgIdxUnaccounted = !localHistoryIndices.contains(result.msg_idx ?? -21)
                let rhashUnaccounted = !localHistoryPaymentHashes.contains(result.rhash ?? "")
                
                // Check for amount and timestamp condition
                let amountThreshold = 5000 // msats
                let timestampThreshold: TimeInterval = 10 // seconds
                
                let similarTransactionExists = messages.contains { message in
                    guard let messageAmountSats = message.amount?.intValue,
                          let messageTimestamp = message.date?.timeIntervalSince1970 else {
                        return false
                    }
                    
                    let messageAmountMsats = messageAmountSats * 1000
                    let resultAmountMsats = result.amt_msat ?? 0
                    let resultTimestamp = TimeInterval(result.ts ?? 0) / 1000
                    
                    return resultAmountMsats > amountThreshold &&
                           resultAmountMsats == messageAmountMsats &&
                           abs(resultTimestamp - messageTimestamp) <= timestampThreshold
                }
                
                if !msgIdxUnaccounted && !rhashUnaccounted {
                    print("Filtered out result with rhash: \(result.rhash ?? "nil")")
                }
                
                return (msgIdxUnaccounted || rhashUnaccounted) && !similarTransactionExists
            }
            
            for result in unAccountedResults {
                let newHistory = PaymentTransaction(fromFetchedParams: result)
                history.append(newHistory)
            }
        }
        
        history = history.sorted { $0.getDate() > $1.getDate() }
        
        setNoResultsLabel(count: history.count)
        checkResultsLimit(count: history.count)
        historyDataSource.loadTransactions(transactions: history)
        loading = false
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
        
        guard let oldestTransaction = historyDataSource.transactions.last else {
            return
        }
        
        let oldestTimestamp = UInt64(oldestTransaction.getDate().timeIntervalSince1970)
        
        loading = true
        
        SphinxOnionManager.sharedInstance.getTransactionsHistory(
            paymentsHistoryCallback: handlePaymentHistoryCompletion,
            itemsPerPage: itemsPerPage,
            sinceTimestamp: oldestTimestamp
        )
    }
}
