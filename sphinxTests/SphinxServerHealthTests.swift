//
//  SphinxServerHealthTests.swift
//  sphinxTests
//
//  Server-health intercept, store, staleness, banner visibility, and mixer error copy.
//

import XCTest
@testable import sphinx

final class SphinxServerHealthTests: XCTestCase {

    override func tearDown() {
        let mgr = SphinxOnionManager.sharedInstance
        mgr.stopWatchdog()
        mgr.stopServerHealthTracking()
        mgr.endReconnectionTimer()
        mgr.onProcessMqttMessages = nil
        mgr.onOnionHandleInvoked = nil
        mgr.onServerStatusIntercepted = nil
        mgr.nowMsProvider = nil
        SphinxOnionManager.resetSharedInstance()
        super.tearDown()
    }

    private func makeFreshManager() -> SphinxOnionManager {
        SphinxOnionManager.resetSharedInstance()
        let mgr = SphinxOnionManager.sharedInstance
        mgr.isV2InitialSetup = false
        mgr.isV2Restore = false
        mgr.connectionInProgress = false
        mgr.onOnionHandleInvoked = nil
        mgr.onServerStatusIntercepted = nil
        mgr.nowMsProvider = nil
        return mgr
    }

    private func healthyPayload(ts: UInt64) -> String {
        "{\"cln_ok\":true,\"degraded\":false,\"reason\":null,\"ts\":\(ts)}"
    }

    private func degradedPayload(ts: UInt64) -> String {
        "{\"cln_ok\":false,\"degraded\":true,\"reason\":\"cln down\",\"ts\":\(ts)}"
    }

    // MARK: - Intercept

    func test_statusTopic_isInterceptedBeforeHandle() {
        let mgr = makeFreshManager()
        var intercepted: String?
        var handleTopic: String?
        mgr.onServerStatusIntercepted = { intercepted = $0 }
        mgr.onOnionHandleInvoked = { handleTopic = $0 }

        mgr.processMqttMessageForTest(
            topic: serverStatusTopic(),
            payload: healthyPayload(ts: 1_700_000_000_000)
        )

        XCTAssertEqual(intercepted, serverStatusTopic())
        XCTAssertNil(handleTopic, "onion handle() must not run for the exact status topic")
    }

    func test_substringTopic_isNotIntercepted() {
        let mgr = makeFreshManager()
        var intercepted: String?
        mgr.onServerStatusIntercepted = { intercepted = $0 }

        mgr.processMqttMessageForTest(
            topic: "prefix/\(serverStatusTopic())/suffix",
            payload: healthyPayload(ts: 1_700_000_000_000)
        )

        XCTAssertNil(intercepted, "substring topics must not match")
        XCTAssertFalse(SphinxServerHealthMapping.isExactStatusTopic("prefix/server_status/suffix"))
        XCTAssertTrue(SphinxServerHealthMapping.isExactStatusTopic(serverStatusTopic()))
    }

    // MARK: - Store start / recovery / staleness

    func test_healthStoreStartsUnknown() {
        let mgr = makeFreshManager()
        XCTAssertEqual(mgr.currentServerHealth, ServerHealth.unknown)
        XCTAssertNil(mgr.lastServerStatus)
        XCTAssertTrue(mgr.isServerHealthBannerVisible)
    }

    func test_invalidPayloadMapsToUnknownWithoutCallingHandle() {
        let mgr = makeFreshManager()
        var handleTopic: String?
        mgr.onOnionHandleInvoked = { handleTopic = $0 }

        mgr.processMqttMessageForTest(topic: serverStatusTopic(), payload: "not-json")

        XCTAssertEqual(mgr.currentServerHealth, ServerHealth.unknown)
        XCTAssertNil(handleTopic)
    }

    func test_healthyHeartbeatAfterDegradedRestoresOkAndHidesBanner() {
        let mgr = makeFreshManager()
        let now: UInt64 = 1_700_000_090_000
        mgr.nowMsProvider = { now }

        mgr.ingestServerStatusPayloadString(degradedPayload(ts: now), nowMs: now)
        XCTAssertEqual(mgr.currentServerHealth, ServerHealth.degraded)
        XCTAssertTrue(mgr.isServerHealthBannerVisible)

        mgr.ingestServerStatusPayloadString(healthyPayload(ts: now), nowMs: now)
        XCTAssertEqual(mgr.currentServerHealth, ServerHealth.ok)
        XCTAssertFalse(mgr.isServerHealthBannerVisible)
    }

    func test_stalenessTransitionsToUnknownWhileMqttRemainsUp() {
        let mgr = makeFreshManager()
        let interval = SphinxServerHealthMapping.heartbeatIntervalMs
        let n = UInt64(SphinxServerHealthMapping.maxMissedIntervals)
        let seen: UInt64 = 1_700_000_000_000
        mgr.isConnected = true
        mgr.nowMsProvider = { seen }

        mgr.ingestServerStatusPayloadString(healthyPayload(ts: seen), nowMs: seen)
        XCTAssertEqual(mgr.currentServerHealth, ServerHealth.ok)
        XCTAssertTrue(mgr.isConnected)

        mgr.nowMsProvider = { seen + interval * (n - 1) }
        mgr.reevaluateServerHealthStaleness()
        XCTAssertEqual(mgr.currentServerHealth, ServerHealth.ok, "N-1 missed intervals still trusts last sample")
        XCTAssertTrue(mgr.isConnected)

        mgr.nowMsProvider = { seen + interval * n + 1 }
        mgr.reevaluateServerHealthStaleness()
        XCTAssertEqual(mgr.currentServerHealth, ServerHealth.unknown)
        XCTAssertTrue(mgr.isConnected, "MQTT liveness is independent of health Unknown")
        XCTAssertTrue(mgr.isServerHealthBannerVisible)
    }

    func test_staleRetainedTsDoesNotFlashOk() {
        let mgr = makeFreshManager()
        let now: UInt64 = 1_700_000_090_000
        let staleTs = now - (SphinxServerHealthMapping.heartbeatIntervalMs * 10)
        mgr.nowMsProvider = { now }

        mgr.ingestServerStatusPayloadString(healthyPayload(ts: staleTs), nowMs: now)
        XCTAssertEqual(mgr.currentServerHealth, ServerHealth.unknown)
        XCTAssertTrue(mgr.isServerHealthBannerVisible)
    }

    // MARK: - Error mapping

    func test_mappedErrorCopyForKnownAndUnknownCodes() {
        XCTAssertEqual(
            parseMixerErrorCode(raw: "CLN_UNAVAILABLE"),
            MixerErrorCode.clnUnavailable
        )
        XCTAssertEqual(
            parseMixerErrorCode(raw: "{\"code\":\"CLN_TIMEOUT\"}"),
            MixerErrorCode.clnTimeout
        )
        XCTAssertEqual(
            parseMixerErrorCode(raw: "INSUFFICIENT_BALANCE"),
            MixerErrorCode.insufficientBalance
        )
        XCTAssertEqual(
            parseMixerErrorCode(raw: "not-a-code"),
            MixerErrorCode.unknown
        )

        XCTAssertEqual(
            SphinxServerHealthMapping.userFacingMessage(for: .clnUnavailable),
            "mixer.error.cln-unavailable".localized
        )
        XCTAssertEqual(
            SphinxServerHealthMapping.userFacingMessage(for: .clnTimeout),
            "mixer.error.cln-timeout".localized
        )
        XCTAssertEqual(
            SphinxServerHealthMapping.userFacingMessage(for: .insufficientBalance),
            "mixer.error.insufficient-balance".localized
        )
        XCTAssertEqual(
            SphinxServerHealthMapping.userFacingMessage(forCode: nil),
            "generic.error.message".localized
        )
        XCTAssertEqual(
            SphinxServerHealthMapping.userFacingMessage(forCode: "UNKNOWN"),
            "mixer.error.unknown".localized
        )
        XCTAssertEqual(
            SphinxServerHealthMapping.userFacingMessage(forRawError: "Account seed not found"),
            "Account seed not found"
        )
    }

    func test_sentStatusMapsOptionalCode() {
        let json = "{\"tag\":\"abc\",\"status\":\"FAILED\",\"code\":\"CLN_UNAVAILABLE\"}"
        let sent = SentStatus(JSONString: json)
        XCTAssertEqual(sent?.code, "CLN_UNAVAILABLE")
        XCTAssertEqual(
            SphinxServerHealthMapping.userFacingMessage(forCode: sent?.code),
            "mixer.error.cln-unavailable".localized
        )
    }

    func test_ffiTypesRoundTripThroughHealthStore() {
        let status = ServerStatus(clnOk: true, degraded: false, reason: nil, ts: 1)
        XCTAssertEqual(status.clnOk, true)
        XCTAssertEqual(evaluateServerHealth(
            last: status,
            lastSeenMs: 1,
            nowMs: 1,
            intervalMs: SphinxServerHealthMapping.heartbeatIntervalMs,
            maxMissed: SphinxServerHealthMapping.maxMissedIntervals
        ), ServerHealth.ok)
    }

    func test_bannerCopyNeverUsesPayloadReason() {
        XCTAssertEqual(
            SphinxServerHealthMapping.bannerCopy(for: .degraded),
            "server.health.degraded".localized
        )
        XCTAssertEqual(
            SphinxServerHealthMapping.bannerCopy(for: .unknown),
            "server.health.unknown".localized
        )
        XCTAssertNil(SphinxServerHealthMapping.bannerCopy(for: .ok))
        XCTAssertFalse(
            SphinxServerHealthMapping.bannerCopy(for: .degraded)?.contains("cln down") == true
        )
    }
}
