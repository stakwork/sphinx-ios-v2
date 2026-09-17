//
//  SphinxServerHealth.swift
//  sphinx
//
//  Shared server-health parse / staleness / mixer-error mapping.
//  Mirrors sphinx-ffi `health.rs` so iOS can consume the mixer contract
//  even before regenerated UniFFI symbols land in `sphinxrs.swift`.
//

import Foundation

struct MixerServerStatus: Equatable, Sendable {
    let clnOk: Bool
    let degraded: Bool
    let reason: String?
    let ts: UInt64
}

enum MixerServerHealth: Equatable, Sendable {
    case ok
    case degraded
    case unknown
}

enum MixerErrorCode: Equatable, Sendable {
    case clnUnavailable
    case clnTimeout
    case insufficientBalance
    case unknown
}

enum SphinxServerHealth {
    /// Matches `server_status_topic()` in sphinx-ffi (`sphinx/src/topics.rs` family, same as `blockheight`).
    static let topic = "server_status"

    static let heartbeatIntervalMs: UInt64 = 30_000
    static let maxMissedIntervals: UInt32 = 3

    private static let codeClnUnavailable = "CLN_UNAVAILABLE"
    private static let codeClnTimeout = "CLN_TIMEOUT"
    private static let codeInsufficientBalance = "INSUFFICIENT_BALANCE"

    static func isExactStatusTopic(_ topic: String) -> Bool {
        topic == Self.topic
    }

    static func parseServerStatus(_ payload: String) throws -> MixerServerStatus {
        guard let data = payload.data(using: .utf8),
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw SphinxError.BadMsg(r: "invalid server status JSON")
        }

        guard let clnOk = object["cln_ok"] as? Bool,
              let degraded = object["degraded"] as? Bool
        else {
            throw SphinxError.BadMsg(r: "invalid server status JSON")
        }

        let ts: UInt64
        if let value = object["ts"] as? UInt64 {
            ts = value
        } else if let value = object["ts"] as? Int, value >= 0 {
            ts = UInt64(value)
        } else if let value = object["ts"] as? Double, value >= 0 {
            ts = UInt64(value)
        } else if let value = object["ts"] as? NSNumber {
            ts = value.uint64Value
        } else {
            throw SphinxError.BadMsg(r: "invalid server status JSON")
        }

        let reason = object["reason"] as? String
        return MixerServerStatus(
            clnOk: clnOk,
            degraded: degraded,
            reason: reason,
            ts: ts
        )
    }

    static func evaluate(
        last: MixerServerStatus?,
        lastSeenMs: UInt64,
        nowMs: UInt64,
        intervalMs: UInt64 = heartbeatIntervalMs,
        maxMissed: UInt32 = maxMissedIntervals
    ) -> MixerServerHealth {
        guard let last else {
            return .unknown
        }

        let thresholdMs = intervalMs.multipliedReportingOverflow(by: UInt64(maxMissed)).partialValue
        let localAgeMs = nowMs > lastSeenMs ? nowMs - lastSeenMs : 0
        if localAgeMs > thresholdMs {
            return .unknown
        }

        if last.ts == 0 || last.ts > nowMs {
            return .unknown
        }
        let payloadAgeMs = nowMs > last.ts ? nowMs - last.ts : 0
        if payloadAgeMs > thresholdMs {
            return .unknown
        }

        if last.degraded || !last.clnOk {
            return .degraded
        }
        return .ok
    }

    static func parseMixerErrorCode(_ raw: String) -> MixerErrorCode {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let code: String
        if let data = trimmed.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data)
        {
            if let object = json as? [String: Any], let value = object["code"] as? String {
                code = value
            } else if let value = json as? String {
                code = value
            } else {
                code = trimmed
            }
        } else {
            code = trimmed
        }

        switch code {
        case codeClnUnavailable:
            return .clnUnavailable
        case codeClnTimeout:
            return .clnTimeout
        case codeInsufficientBalance:
            return .insufficientBalance
        default:
            return .unknown
        }
    }

    static func userFacingMessage(
        forCode code: String?,
        fallback: String = "generic.error.message".localized
    ) -> String {
        guard let code, !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return fallback
        }
        return userFacingMessage(for: parseMixerErrorCode(code), raw: code, fallback: fallback)
    }

    static func userFacingMessage(
        forRawError raw: String?,
        fallback: String = "generic.error.message".localized
    ) -> String {
        guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return fallback
        }
        return userFacingMessage(for: parseMixerErrorCode(raw), raw: raw, fallback: raw)
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

    static func bannerCopy(for health: MixerServerHealth) -> String? {
        switch health {
        case .ok:
            return nil
        case .degraded:
            return "server.health.degraded".localized
        case .unknown:
            return "server.health.unknown".localized
        }
    }

    static func shouldShowBanner(for health: MixerServerHealth) -> Bool {
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
