//
//  SphinxOnionManager+ServerHealth.swift
//  sphinx
//
//  Health-store for mixer server-status heartbeats. Independent of MQTT
//  connected/disconnected chrome. All store updates run on the main thread.
//

import Foundation
import CocoaMQTT

extension SphinxOnionManager {
    func resetServerHealthStore() {
        runOnMainIfNeeded { [weak self] in
            guard let self else { return }
            self.lastServerStatus = nil
            self.lastServerStatusSeenMs = 0
            self.clearServerHealthLaunchGrace()
            self.applyServerHealth(.unknown)
            self.stopServerHealthStalenessTimer()
            NotificationCenter.default.post(name: .onServerHealthChanged, object: nil)
        }
    }

    func startServerHealthTracking() {
        runOnMainIfNeeded { [weak self] in
            self?.armServerHealthLaunchGraceIfNeeded()
            self?.startServerHealthStalenessTimer()
        }
    }

    func stopServerHealthTracking() {
        runOnMainIfNeeded { [weak self] in
            guard let self else { return }
            self.stopServerHealthStalenessTimer()
            self.clearServerHealthLaunchGrace()
            NotificationCenter.default.post(name: .onServerHealthChanged, object: nil)
        }
    }

    func processMqttMessageForTest(topic: String, payload: String = "") {
        processMqttMessages(
            message: CocoaMQTTMessage(
                topic: topic,
                payload: [UInt8](payload.utf8)
            )
        )
    }

    func ingestServerStatusPayload(_ payload: [UInt8], nowMs: UInt64? = nil) {
        let payloadString = String(bytes: payload, encoding: .utf8) ?? ""
        ingestServerStatusPayloadString(payloadString, nowMs: nowMs)
    }

    func ingestServerStatusPayloadString(_ payload: String, nowMs: UInt64? = nil) {
        let capturedNow = nowMs
        runOnMainIfNeeded { [weak self] in
            guard let self else { return }
            let now = capturedNow ?? self.currentServerHealthNowMs()
            self.markServerStatusReceived()
            do {
                let status = try parseServerStatus(payload: payload)
                self.lastServerStatus = status
                self.lastServerStatusSeenMs = now
                let health = evaluateServerHealth(
                    last: status,
                    lastSeenMs: now,
                    nowMs: now,
                    intervalMs: ServerHealthPresentation.heartbeatIntervalMs,
                    maxMissed: ServerHealthPresentation.maxMissedIntervals
                )
                self.applyServerHealthAndRefreshIfUnchanged(health)
            } catch {
                print("[MQTT] server status parse_failed=true")
                self.applyServerHealthAndRefreshIfUnchanged(.unknown)
            }
        }
    }

    func reevaluateServerHealthStaleness(nowMs: UInt64? = nil) {
        let capturedNow = nowMs
        runOnMainIfNeeded { [weak self] in
            guard let self else { return }
            let now = capturedNow ?? self.currentServerHealthNowMs()
            self.applyServerHealth(
                evaluateServerHealth(
                    last: self.lastServerStatus,
                    lastSeenMs: self.lastServerStatusSeenMs,
                    nowMs: now,
                    intervalMs: ServerHealthPresentation.heartbeatIntervalMs,
                    maxMissed: ServerHealthPresentation.maxMissedIntervals
                )
            )
        }
    }

    func currentServerHealthNowMs() -> UInt64 {
        if let nowMsProvider {
            return nowMsProvider()
        }
        return UInt64(Date().timeIntervalSince1970 * 1000)
    }

    var isServerHealthBannerVisible: Bool {
        ServerHealthPresentation.shouldShowBanner(
            health: currentServerHealth,
            hasReceivedServerStatus: hasReceivedServerStatus,
            trackingStartedAtMs: serverHealthTrackingStartedAtMs,
            nowMs: currentServerHealthNowMs()
        )
    }

    func applyServerHealth(_ health: ServerHealth) {
        let previous = currentServerHealth
        currentServerHealth = health
        if previous != health {
            print("[MQTT] server health \(Self.logName(for: previous)) -> \(Self.logName(for: health))")
            NotificationCenter.default.post(name: .onServerHealthChanged, object: nil)
        }
    }

    func armServerHealthLaunchGraceIfNeeded() {
        guard serverHealthTrackingStartedAtMs == nil else { return }
        serverHealthTrackingStartedAtMs = currentServerHealthNowMs()
        let interval = TimeInterval(ServerHealthPresentation.launchGraceMs) / 1000.0
        serverHealthLaunchGraceTimer = Timer.scheduledTimer(
            withTimeInterval: interval,
            repeats: false
        ) { [weak self] _ in
            self?.handleServerHealthLaunchGraceElapsed()
        }
        NotificationCenter.default.post(name: .onServerHealthChanged, object: nil)
    }

    func handleServerHealthLaunchGraceElapsed() {
        invalidateServerHealthLaunchGraceTimer()
        NotificationCenter.default.post(name: .onServerHealthChanged, object: nil)
    }

    private func startServerHealthStalenessTimer() {
        stopServerHealthStalenessTimer()
        let interval = TimeInterval(ServerHealthPresentation.heartbeatIntervalMs) / 1000.0
        serverHealthStalenessTimer = Timer.scheduledTimer(
            withTimeInterval: interval,
            repeats: true
        ) { [weak self] _ in
            guard let self, self.isConnected else { return }
            self.reevaluateServerHealthStaleness()
        }
    }

    private func stopServerHealthStalenessTimer() {
        serverHealthStalenessTimer?.invalidate()
        serverHealthStalenessTimer = nil
    }

    private func markServerStatusReceived() {
        hasReceivedServerStatus = true
        invalidateServerHealthLaunchGraceTimer()
    }

    private func applyServerHealthAndRefreshIfUnchanged(_ health: ServerHealth) {
        let previous = currentServerHealth
        applyServerHealth(health)
        if previous == health {
            NotificationCenter.default.post(name: .onServerHealthChanged, object: nil)
        }
    }

    private func clearServerHealthLaunchGrace() {
        hasReceivedServerStatus = false
        serverHealthTrackingStartedAtMs = nil
        invalidateServerHealthLaunchGraceTimer()
    }

    private func invalidateServerHealthLaunchGraceTimer() {
        serverHealthLaunchGraceTimer?.invalidate()
        serverHealthLaunchGraceTimer = nil
    }

    private static func logName(for health: ServerHealth) -> String {
        switch health {
        case .ok: return "ok"
        case .degraded: return "degraded"
        case .unknown: return "unknown"
        }
    }
}
