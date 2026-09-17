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
            topic: SphinxServerHealth.topic,
            payload: healthyPayload(ts: 1_700_000_000_000)
        )

        XCTAssertEqual(intercepted, SphinxServerHealth.topic)
        XCTAssertNil(handleTopic, "onion handle() must not run for the exact status topic")
    }

    func test_substringTopic_isNotIntercepted() {
        let mgr = makeFreshManager()
        var intercepted: String?
        mgr.onServerStatusIntercepted = { intercepted = $0 }

        mgr.processMqttMessageForTest(
            topic: "prefix/\(SphinxServerHealth.topic)/suffix",
            payload: healthyPayload(ts: 1_700_000_000_000)
        )

        XCTAssertNil(intercepted, "substring topics must not match")
        XCTAssertFalse(SphinxServerHealth.isExactStatusTopic("prefix/server_status/suffix"))
        XCTAssertTrue(SphinxServerHealth.isExactStatusTopic("server_status"))
    }

    // MARK: - Store start / recovery / staleness

    func test_healthStoreStartsUnknown() {
        let mgr = makeFreshManager()
        XCTAssertEqual(mgr.currentServerHealth, .unknown)
        XCTAssertNil(mgr.lastServerStatus)
        XCTAssertTrue(mgr.isServerHealthBannerVisible)
    }

    func test_invalidPayloadMapsToUnknownWithoutCallingHandle() {
        let mgr = makeFreshManager()
        var handleTopic: String?
        mgr.onOnionHandleInvoked = { handleTopic = $0 }

        mgr.processMqttMessageForTest(topic: SphinxServerHealth.topic, payload: "not-json")

        XCTAssertEqual(mgr.currentServerHealth, .unknown)
        XCTAssertNil(handleTopic)
    }

    func test_healthyHeartbeatAfterDegradedRestoresOkAndHidesBanner() {
        let mgr = makeFreshManager()
        let now: UInt64 = 1_700_000_090_000
        mgr.nowMsProvider = { now }

        mgr.ingestServerStatusPayloadString(degradedPayload(ts: now), nowMs: now)
        XCTAssertEqual(mgr.currentServerHealth, .degraded)
        XCTAssertTrue(mgr.isServerHealthBannerVisible)

        mgr.ingestServerStatusPayloadString(healthyPayload(ts: now), nowMs: now)
        XCTAssertEqual(mgr.currentServerHealth, .ok)
        XCTAssertFalse(mgr.isServerHealthBannerVisible)
    }

    func test_stalenessTransitionsToUnknownWhileMqttRemainsUp() {
        let mgr = makeFreshManager()
        let interval = SphinxServerHealth.heartbeatIntervalMs
        let n = UInt64(SphinxServerHealth.maxMissedIntervals)
        let seen: UInt64 = 1_700_000_000_000
        mgr.isConnected = true
        mgr.nowMsProvider = { seen }

        mgr.ingestServerStatusPayloadString(healthyPayload(ts: seen), nowMs: seen)
        XCTAssertEqual(mgr.currentServerHealth, .ok)
        XCTAssertTrue(mgr.isConnected)

        mgr.nowMsProvider = { seen + interval * (n - 1) }
        mgr.reevaluateServerHealthStaleness()
        XCTAssertEqual(mgr.currentServerHealth, .ok, "N-1 missed intervals still trusts last sample")
        XCTAssertTrue(mgr.isConnected)

        mgr.nowMsProvider = { seen + interval * n + 1 }
        mgr.reevaluateServerHealthStaleness()
        XCTAssertEqual(mgr.currentServerHealth, .unknown)
        XCTAssertTrue(mgr.isConnected, "MQTT liveness is independent of health Unknown")
        XCTAssertTrue(mgr.isServerHealthBannerVisible)
    }

    func test_staleRetainedTsDoesNotFlashOk() {
        let mgr = makeFreshManager()
        let now: UInt64 = 1_700_000_090_000
        let staleTs = now - (SphinxServerHealth.heartbeatIntervalMs * 10)
        mgr.nowMsProvider = { now }

        mgr.ingestServerStatusPayloadString(healthyPayload(ts: staleTs), nowMs: now)
        XCTAssertEqual(mgr.currentServerHealth, .unknown)
        XCTAssertTrue(mgr.isServerHealthBannerVisible)
    }

    // MARK: - Error mapping

    func test_mappedErrorCopyForKnownAndUnknownCodes() {
        XCTAssertEqual(
            SphinxServerHealth.parseMixerErrorCode("CLN_UNAVAILABLE"),
            .clnUnavailable
        )
        XCTAssertEqual(
            SphinxServerHealth.parseMixerErrorCode("{\"code\":\"CLN_TIMEOUT\"}"),
            .clnTimeout
        )
        XCTAssertEqual(
            SphinxServerHealth.parseMixerErrorCode("INSUFFICIENT_BALANCE"),
            .insufficientBalance
        )
        XCTAssertEqual(
            SphinxServerHealth.parseMixerErrorCode("not-a-code"),
            .unknown
        )

        XCTAssertEqual(
            SphinxServerHealth.userFacingMessage(for: .clnUnavailable),
            "mixer.error.cln-unavailable".localized
        )
        XCTAssertEqual(
            SphinxServerHealth.userFacingMessage(for: .clnTimeout),
            "mixer.error.cln-timeout".localized
        )
        XCTAssertEqual(
            SphinxServerHealth.userFacingMessage(for: .insufficientBalance),
            "mixer.error.insufficient-balance".localized
        )
        XCTAssertEqual(
            SphinxServerHealth.userFacingMessage(forCode: nil),
            "generic.error.message".localized
        )
        XCTAssertEqual(
            SphinxServerHealth.userFacingMessage(forCode: "UNKNOWN"),
            "mixer.error.unknown".localized
        )
        XCTAssertEqual(
            SphinxServerHealth.userFacingMessage(forRawError: "Account seed not found"),
            "Account seed not found"
        )
    }

    func test_sentStatusMapsOptionalCode() {
        let json = "{\"tag\":\"abc\",\"status\":\"FAILED\",\"code\":\"CLN_UNAVAILABLE\"}"
        let sent = SentStatus(JSONString: json)
        XCTAssertEqual(sent?.code, "CLN_UNAVAILABLE")
        XCTAssertEqual(
            SphinxServerHealth.userFacingMessage(forCode: sent?.code),
            "mixer.error.cln-unavailable".localized
        )
    }

    func test_bannerCopyNeverUsesPayloadReason() {
        XCTAssertEqual(
            SphinxServerHealth.bannerCopy(for: .degraded),
            "server.health.degraded".localized
        )
        XCTAssertEqual(
            SphinxServerHealth.bannerCopy(for: .unknown),
            "server.health.unknown".localized
        )
        XCTAssertNil(SphinxServerHealth.bannerCopy(for: .ok))
        XCTAssertFalse(
            SphinxServerHealth.bannerCopy(for: .degraded)?.contains("cln down") == true
        )
    }
}
