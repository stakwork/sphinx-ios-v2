//
//  WalletBalanceService.swift
//  sphinx
//
//  Created by Tomas Timinskas on 04/10/2019.
//  Copyright © 2019 Sphinx. All rights reserved.
//

import Foundation
import UIKit

public final class WalletBalanceService {
    
    var balance: UInt64? {
        get {
            if let balance = UserData.sharedInstance.getBalanceSats() {
                return UInt64(balance)
            }
            return nil
        }
        set {
            if let balance = newValue {
                UserData.sharedInstance.save(balance: balance)
            }
        }
    }
    
    init() {}
    
    func updateBalance(labels: [UILabel]) {
        DispatchQueue.global().async {
            if let storedBalance = self.balance {
                self.updateLabels(labels: labels, balance: storedBalance.formattedWithSeparator)
            }
        }
    }
    
    private func updateLabels(labels: [UILabel], balance: String) {
        DispatchQueue.main.async {
            let hideBalances = UserDefaults.Keys.hideBalances.get(defaultValue: false)
            for label in labels {
                if (hideBalances) {
                    label.text = "＊＊＊＊"
                } else {
                    label.text = balance
                }
            }
        }
    }
}
