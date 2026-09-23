//
//  ServerHealthPresentation.swift
//  sphinx
//
//  App-only server-health presentation. Parse / evaluate / topic live in
//  the UniFFI bindings (`sphinxrs.swift`); this file keeps banner copy,
//  staleness constants, and mixer error strings the FFI does not provide.
//

import Foundation

enum ServerHealthPresentation {
    static let heartbeatIntervalMs: UInt64 = 30_000
    static let maxMissedIntervals: UInt32 = 3
    static let launchGraceMs: UInt64 = 15_000

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

    static func shouldShowBanner(
        health: ServerHealth,
        hasReceivedServerStatus: Bool,
        trackingStartedAtMs: UInt64?,
        nowMs: UInt64
    ) -> Bool {
        switch health {
        case .ok:
            return false
        case .degraded:
            return true
        case .unknown:
            if hasReceivedServerStatus {
                return true
            }
            guard let startedAt = trackingStartedAtMs else {
                return false
            }
            guard nowMs >= startedAt else {
                return false
            }
            return nowMs - startedAt >= launchGraceMs
        }
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
