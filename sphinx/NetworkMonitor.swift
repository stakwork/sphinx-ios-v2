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
    private var skipInitialUpdate = false

    /// Guards `isConnected` and `hasReceivedPath`, which are written on the
    /// NWMonitor background queue and read from the main thread.
    private let stateLock = NSLock()

    private var _isConnected: Bool = false
    private(set) var isConnected: Bool {
        get {
            stateLock.lock()
            defer { stateLock.unlock() }
            return _isConnected
        }
        set {
            stateLock.lock()
            _isConnected = newValue
            stateLock.unlock()
        }
    }

    /// True once at least one real path update has been received since the
    /// monitor last started. Used to distinguish "known offline" from "not
    /// yet known" so UI doesn't briefly read as offline before the first
    /// path callback arrives.
    private var _hasReceivedPath: Bool = false
    private var hasReceivedPath: Bool {
        get {
            stateLock.lock()
            defer { stateLock.unlock() }
            return _hasReceivedPath
        }
        set {
            stateLock.lock()
            _hasReceivedPath = newValue
            stateLock.unlock()
        }
    }

    var connectionType: NWInterface.InterfaceType?

    private var lastIsConnected: Bool? = nil
    private var lastConnectionType: NWInterface.InterfaceType? = nil

    private init() {}

    // This method should be called first to start monitoring the network connection.
    func startMonitoring() {
        if isNwMonitoring { return }

        nwMonitor = NWPathMonitor()
        skipInitialUpdate = true

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
        hasReceivedPath = false
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
            newConnectionType = nil
        }

        // On first callback after startMonitoring(), seed state without notifying.
        // NWPathMonitor always fires immediately on start; we don't want that initial
        // fire to trigger a reconnect if the network type changed while we were stopped.
        if skipInitialUpdate {
            skipInitialUpdate = false
            isConnected = newIsConnected
            connectionType = newConnectionType
            lastIsConnected = newIsConnected
            lastConnectionType = newConnectionType
            hasReceivedPath = true

            // Notify UI-only observers (e.g. reachability-driven banner/bolt state)
            // that a real reading now exists, without touching `.connectedToInternet`
            // observers that trigger MQTT reconnect logic.
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .networkReachabilitySeeded, object: nil)
            }
            return
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
        hasReceivedPath = true

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

    /// UI-facing reachability reading. Treats "not yet known" as online, so
    /// UI doesn't flash offline before the first path callback arrives.
    /// Only reads as offline once a real path update reported unsatisfied.
    var isReachableOrUnknown: Bool {
        !hasReceivedPath || isConnected
    }

    func isNetworkConnected() -> Bool {
        guard let _ = nwMonitor else { return false }
        return isConnected
    }
}
