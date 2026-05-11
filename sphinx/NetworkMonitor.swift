//
//  NetworkMonitor.swift
//  sphinx
//
//  Created by James Carucci on 6/10/24.
//  Copyright © 2024 sphinx. All rights reserved.
//

import Foundation
import Network

class NetworkMonitor: @unchecked Sendable {
    nonisolated(unsafe) static let shared = NetworkMonitor()
    private var nwMonitor: NWPathMonitor?
    private var isNwMonitoring = false
    
    private(set) var isConnected: Bool = false
    var connectionType: NWInterface.InterfaceType?

    private var lastIsConnected: Bool? = nil
    private var lastConnectionType: NWInterface.InterfaceType? = nil

    private init() {}

    // This method should be called first to start monitoring the network connection.
    func startMonitoring() {
        if isNwMonitoring { return }
        
        nwMonitor = NWPathMonitor()
        
        // Network changes have to be monitored on the background as the changes are to be continuously monitored
        let queue = DispatchQueue(label: "NWMonitor")
        nwMonitor?.start(queue: queue)
        nwMonitor?.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            self.updateConnectionStatus(path: path)
        }
        isNwMonitoring = true
    }

    // Call this method to stop the monitoring.
    func stopMonitoring() {
        if isNwMonitoring, let monitor = nwMonitor {
            monitor.cancel()
            self.nwMonitor = nil
            isNwMonitoring = false
        }
    }

    // Use SCNetworkReachability to determine the actual network state
    private func updateConnectionStatus(path: NWPath) {
        let newIsConnected = path.status == .satisfied

        // Determine the connection type
        let newConnectionType: NWInterface.InterfaceType?
        if path.usesInterfaceType(.wifi) {
            newConnectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            newConnectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            newConnectionType = .wiredEthernet
        } else {
            newConnectionType = nil // Connection type is unknown
        }

        // Deduplicate: skip if state hasn't changed
        if newIsConnected == lastIsConnected && newConnectionType == lastConnectionType {
            print("[NetMonitor] Duplicate status suppressed")
            return
        }

        isConnected = newIsConnected
        connectionType = newConnectionType
        lastIsConnected = newIsConnected
        lastConnectionType = newConnectionType

        print("Network status changed - isConnected: \(isConnected), Connection Type: \(String(describing: connectionType))")

        // Post notifications on main thread — observers may use MainActor.assumeIsolated
        let connected = isConnected
        DispatchQueue.main.async {
            if connected {
                NotificationCenter.default.post(name: .connectedToInternet, object: nil)
            } else {
                NotificationCenter.default.post(name: .disconnectedFromInternet, object: nil)
            }
        }
    }

    func isNetworkConnected() -> Bool {
        guard let _ = nwMonitor else { return false }
        return isConnected
    }
}
