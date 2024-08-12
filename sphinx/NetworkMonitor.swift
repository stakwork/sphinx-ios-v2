//
//  NetworkMonitor.swift
//  sphinx
//
//  Created by James Carucci on 6/10/24.
//  Copyright © 2024 sphinx. All rights reserved.
//
import Foundation
import Network
import UIKit


import Foundation
import Network

class NetworkMonitor {
    static let shared = NetworkMonitor()
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue.global(qos: .background)

    private(set) var isConnected: Bool = false
    var connectionType: NWInterface.InterfaceType?

    private init() {
        startMonitoring()
    }

    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            self.updateConnectionStatus(path: path)
        }
        monitor.start(queue: queue)
    }

    private func updateConnectionStatus(path: NWPath) {
        // Directly check the path status
        self.isConnected = path.status != .satisfied
        print("Direct Path Check - isConnected: \(self.isConnected), Path Status: \(path.status)")
        
        // Example Notification Logic (Corrected to reflect status)
        if self.isConnected {
            NotificationCenter.default.post(name: .connectedToInternet, object: nil)
        } else {
            NotificationCenter.default.post(name: .disconnectedFromInternet, object: nil)
        }
    }

    func checkConnectionSync() -> Bool {
        // Fetch the current path and evaluate
        let path = monitor.currentPath
        updateConnectionStatus(path: path)
        return isConnected
    }

    deinit {
        monitor.cancel()
    }
}
