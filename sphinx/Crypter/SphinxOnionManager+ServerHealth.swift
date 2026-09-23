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
            self.applyServerHealth(.unknown)
            self.stopServerHealthStalenessTimer()
        }
    }

    func startServerHealthTracking() {
        runOnMainIfNeeded { [weak self] in
            self?.startServerHealthStalenessTimer()
        }
    }

    func stopServerHealthTracking() {
        runOnMainIfNeeded { [weak self] in
            self?.stopServerHealthStalenessTimer()
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
        let now = nowMs ?? currentServerHealthNowMs()
        do {
            let status = try SphinxServerHealth.parseServerStatus(payload)
            lastServerStatus = status
            lastServerStatusSeenMs = now
            let health = SphinxServerHealth.evaluate(
                last: status,
                lastSeenMs: now,
                nowMs: now
            )
            applyServerHealth(health)
        } catch {
            print("[MQTT] server status parse_failed=true")
            applyServerHealth(.unknown)
        }
    }

    func reevaluateServerHealthStaleness(nowMs: UInt64? = nil) {
        let now = nowMs ?? currentServerHealthNowMs()
        let health = SphinxServerHealth.evaluate(
            last: lastServerStatus,
            lastSeenMs: lastServerStatusSeenMs,
            nowMs: now
        )
        applyServerHealth(health)
    }

    func currentServerHealthNowMs() -> UInt64 {
        if let nowMsProvider {
            return nowMsProvider()
        }
        return UInt64(Date().timeIntervalSince1970 * 1000)
    }

    var isServerHealthBannerVisible: Bool {
        SphinxServerHealth.shouldShowBanner(for: currentServerHealth)
    }

    func applyServerHealth(_ health: MixerServerHealth) {
        let previous = currentServerHealth
        currentServerHealth = health
        if previous != health {
            print("[MQTT] server health \(Self.logName(for: previous)) -> \(Self.logName(for: health))")
            NotificationCenter.default.post(name: .onServerHealthChanged, object: nil)
        }
    }

    private func startServerHealthStalenessTimer() {
        stopServerHealthStalenessTimer()
        let interval = TimeInterval(SphinxServerHealth.heartbeatIntervalMs) / 1000.0
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

    private static func logName(for health: MixerServerHealth) -> String {
        switch health {
        case .ok: return "ok"
        case .degraded: return "degraded"
        case .unknown: return "unknown"
        }
    }
}
