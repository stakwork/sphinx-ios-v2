//
//  SphinxServerHealthMapping.swift
//  sphinx
//
//  Localized banner and mixer-error copy. Parsing and health evaluation
//  live in the UniFFI bindings (`parseServerStatus`, `evaluateServerHealth`,
//  `parseMixerErrorCode`, `serverStatusTopic`).
//

import Foundation

enum SphinxServerHealthMapping {
    static let heartbeatIntervalMs: UInt64 = 30_000
    static let maxMissedIntervals: UInt32 = 3

    static func isExactStatusTopic(_ topic: String) -> Bool {
        topic == serverStatusTopic()
    }

    static func evaluate(
        last: ServerStatus?,
        lastSeenMs: UInt64,
        nowMs: UInt64,
        intervalMs: UInt64 = heartbeatIntervalMs,
        maxMissed: UInt32 = maxMissedIntervals
    ) -> ServerHealth {
        evaluateServerHealth(
            last: last,
            lastSeenMs: lastSeenMs,
            nowMs: nowMs,
            intervalMs: intervalMs,
            maxMissed: maxMissed
        )
    }

    static func userFacingMessage(
        forCode code: String?,
        fallback: String = "generic.error.message".localized
    ) -> String {
        guard let code, !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return fallback
        }
        return userFacingMessage(for: parseMixerErrorCode(raw: code), raw: code, fallback: fallback)
    }

    static func userFacingMessage(
        forRawError raw: String?,
        fallback: String = "generic.error.message".localized
    ) -> String {
        guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return fallback
        }
        return userFacingMessage(for: parseMixerErrorCode(raw: raw), raw: raw, fallback: raw)
    }

    static func userFacingMessage(for code: MixerErrorCode) -> String {
        switch code {
        case .clnUnavailable:
            return "mixer.error.cln-unavailable".localized
        case .clnTimeout:
            return "mixer.error.cln-timeout".localized
        case .insufficientBalance:
            return "mixer.error.insufficient-balance".localized
        case .unknown:
            return "generic.error.message".localized
        }
    }

    static func bannerCopy(for health: ServerHealth) -> String? {
        switch health {
        case .ok:
            return nil
        case .degraded:
            return "server.health.degraded".localized
        case .unknown:
            return "server.health.unknown".localized
        }
    }

    static func shouldShowBanner(for health: ServerHealth) -> Bool {
        health != .ok
    }

    private static func userFacingMessage(
        for code: MixerErrorCode,
        raw: String,
        fallback: String
    ) -> String {
        switch code {
        case .clnUnavailable, .clnTimeout, .insufficientBalance:
            return userFacingMessage(for: code)
        case .unknown:
            if isMixerCodeShape(raw) {
                return "mixer.error.unknown".localized
            }
            return fallback
        }
    }

    private static func isMixerCodeShape(_ raw: String) -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == "UNKNOWN" {
            return true
        }
        if let data = trimmed.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           object["code"] != nil
        {
            return true
        }
        return false
    }
}
