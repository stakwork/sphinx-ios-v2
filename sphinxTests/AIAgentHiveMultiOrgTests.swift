//
//  AIAgentHiveMultiOrgTests.swift
//  sphinxTests
//
//  Unit tests for multi-org Hive agent support: org resolution, per-org slug/
//  conversation/canvas caching, and proposal-org resolution.
//
//  NOTE: `DefaultKey` (see Extensions/UserDefaults.swift) always reads/writes
//  `UserDefaults.standard` — it has no suite-name injection point — so these
//  tests clean up the specific keys they touch in setUp/tearDown rather than
//  using a dedicated UserDefaults suite (mirrors the existing pattern in
//  HiveTokenKeychainTests).
//

import XCTest
@testable import sphinx

final class AIAgentHiveMultiOrgTests: XCTestCase {

    override func setUp() {
        super.setUp()
        clearHiveKeys()
    }

    override func tearDown() {
        clearHiveKeys()
        super.tearDown()
    }

    private func clearHiveKeys() {
        UserDefaults.Keys.hiveOrgs.removeValue()
        UserDefaults.Keys.hiveOrgSlugsByOrg.removeValue()
        UserDefaults.Keys.hiveConversationIdByOrg.removeValue()
        UserDefaults.Keys.hiveCanvasChatHistoryByOrg.removeValue()
        UserDefaults.Keys.hivePendingProposal.removeValue()
    }

    // MARK: - Fixtures

    private func makeOrg(id: String, login: String, name: String) -> HiveOrg {
        HiveOrg(id: id, githubLogin: login, name: name)
    }

    private let orgA = HiveOrg(id: "org-a-id", githubLogin: "org-a-login", name: "Org Alpha")
    private let orgB = HiveOrg(id: "org-b-id", githubLogin: "org-b-login", name: "Org Beta")

    private func proposalMessage(proposalId: String, toolName: String = "propose_feature") -> AIAgentManager.CanvasChatMessage {
        let toolCall = AIAgentManager.ToolCall(
            id: "call-\(proposalId)",
            toolName: toolName,
            status: "output-available",
            input: ["proposalId": proposalId, "kind": "feature", "title": "Test"],
            output: ["proposalId": .string(proposalId), "kind": .string("feature")]
        )
        return AIAgentManager.CanvasChatMessage(role: "assistant", content: "result", toolCalls: [toolCall], approvalResult: nil)
    }

    // MARK: - resolveOrg

    func testResolveOrg_singleOrgNoRef_resolvesTheOnlyOrg() {
        let result = AIAgentManager.resolveOrg(nil, in: [orgA])
        guard case .success(let org) = result else { return XCTFail("expected success") }
        XCTAssertEqual(org.id, orgA.id)
    }

    func testResolveOrg_singleOrgEmptyStringRef_resolvesTheOnlyOrg() {
        let result = AIAgentManager.resolveOrg("   ", in: [orgA])
        guard case .success(let org) = result else { return XCTFail("expected success") }
        XCTAssertEqual(org.id, orgA.id)
    }

    func testResolveOrg_multiOrgNoRef_isAmbiguous() {
        let result = AIAgentManager.resolveOrg(nil, in: [orgA, orgB])
        guard case .failure(.ambiguous(let candidates)) = result else { return XCTFail("expected ambiguous") }
        XCTAssertEqual(candidates.count, 2)
    }

    func testResolveOrg_emptyList_isNoOrgs() {
        let result = AIAgentManager.resolveOrg("anything", in: [])
        guard case .failure(.noOrgs) = result else { return XCTFail("expected noOrgs") }
    }

    func testResolveOrg_matchesByLoginCaseInsensitiveWithWhitespace() {
        let result = AIAgentManager.resolveOrg("  ORG-A-LOGIN  ", in: [orgA, orgB])
        guard case .success(let org) = result else { return XCTFail("expected success") }
        XCTAssertEqual(org.id, orgA.id)
    }

    func testResolveOrg_matchesById() {
        let result = AIAgentManager.resolveOrg(orgB.id, in: [orgA, orgB])
        guard case .success(let org) = result else { return XCTFail("expected success") }
        XCTAssertEqual(org.id, orgB.id)
    }

    func testResolveOrg_matchesByNameCaseInsensitive() {
        let result = AIAgentManager.resolveOrg("org alpha", in: [orgA, orgB])
        guard case .success(let org) = result else { return XCTFail("expected success") }
        XCTAssertEqual(org.id, orgA.id)
    }

    func testResolveOrg_duplicateNames_isAmbiguous() {
        let dupA = makeOrg(id: "dup-1", login: "dup-login-1", name: "Shared Name")
        let dupB = makeOrg(id: "dup-2", login: "dup-login-2", name: "Shared Name")
        let result = AIAgentManager.resolveOrg("Shared Name", in: [dupA, dupB])
        guard case .failure(.ambiguous(let candidates)) = result else { return XCTFail("expected ambiguous") }
        XCTAssertEqual(Set(candidates.map { $0.id }), Set([dupA.id, dupB.id]))
    }

    func testResolveOrg_unknownRef_isUnknown() {
        let result = AIAgentManager.resolveOrg("does-not-exist", in: [orgA, orgB])
        guard case .failure(.unknown) = result else { return XCTFail("expected unknown") }
    }

    func testResolveOrg_resultIsAlwaysElementOfList() {
        let orgs = [orgA, orgB]
        for ref in [nil, orgA.id, orgB.githubLogin, orgA.name] {
            if case .success(let org) = AIAgentManager.resolveOrg(ref, in: orgs) {
                XCTAssertTrue(orgs.contains(org), "resolved org must be drawn from the cached list")
            }
        }
    }

    // MARK: - HiveOrg Codable round-trip

    func testHiveOrg_codableRoundTrip() {
        let encoded = try! JSONEncoder().encode(orgA)
        let decoded = try! JSONDecoder().decode(HiveOrg.self, from: encoded)
        XCTAssertEqual(decoded, orgA)
    }

    // MARK: - Org cache round trip

    func testCacheHiveOrgs_roundTrip() {
        AIAgentManager.cacheHiveOrgs([orgA, orgB])
        let cached = AIAgentManager.cachedHiveOrgs()
        XCTAssertEqual(Set(cached.map { $0.id }), Set([orgA.id, orgB.id]))
    }

    func testCachedHiveOrgs_emptyWhenNothingCached() {
        XCTAssertTrue(AIAgentManager.cachedHiveOrgs().isEmpty)
    }

    func testDefaultOrg_onlyWhenExactlyOneCached() {
        AIAgentManager.cacheHiveOrgs([orgA])
        XCTAssertEqual(AIAgentManager.defaultOrg?.id, orgA.id)

        AIAgentManager.cacheHiveOrgs([orgA, orgB])
        XCTAssertNil(AIAgentManager.defaultOrg)

        AIAgentManager.cacheHiveOrgs([])
        XCTAssertNil(AIAgentManager.defaultOrg)
    }

    // MARK: - Canvas history isolation

    func testCanvasHistory_emptyForUnknownOrg() {
        XCTAssertEqual(AIAgentManager.canvasHistory(orgId: "unknown-org").count, 0)
    }

    func testCanvasHistory_isolatedBetweenOrgs() {
        let historyA = [AIAgentManager.CanvasChatMessage(role: "user", content: "question for A")]
        let historyB = [
            AIAgentManager.CanvasChatMessage(role: "user", content: "question for B"),
            AIAgentManager.CanvasChatMessage(role: "assistant", content: "answer for B")
        ]
        AIAgentManager.persistCanvasHistory(orgId: orgA.id, history: historyA)
        AIAgentManager.persistCanvasHistory(orgId: orgB.id, history: historyB)

        let readA = AIAgentManager.canvasHistory(orgId: orgA.id)
        let readB = AIAgentManager.canvasHistory(orgId: orgB.id)

        XCTAssertEqual(readA.count, 1)
        XCTAssertEqual(readA.first?.content, "question for A")
        XCTAssertEqual(readB.count, 2)
        XCTAssertEqual(readB.last?.content, "answer for B")
    }

    func testCanvasHistory_queryingOneOrgDoesNotMutateAnother() {
        // Simulates: query org B, then approve org A's proposal — A's history must
        // contain only A's turns, and B's history must be unchanged.
        let historyA = [proposalMessage(proposalId: "prop-a")]
        AIAgentManager.persistCanvasHistory(orgId: orgA.id, history: historyA)

        var historyB = AIAgentManager.canvasHistory(orgId: orgB.id) // []
        historyB.append(AIAgentManager.CanvasChatMessage(role: "user", content: "B question"))
        AIAgentManager.persistCanvasHistory(orgId: orgB.id, history: historyB)

        let finalA = AIAgentManager.canvasHistory(orgId: orgA.id)
        let finalB = AIAgentManager.canvasHistory(orgId: orgB.id)
        XCTAssertEqual(finalA.count, 1)
        XCTAssertEqual(finalB.count, 1)
        XCTAssertEqual(finalB.first?.content, "B question")
    }

    // MARK: - resolveProposalOrg

    func testResolveProposalOrg_pendingWithOrgId_resolvesFromIt() {
        AIAgentManager.cacheHiveOrgs([orgA, orgB])
        let pending = AIAgentManager.PendingProposal(
            proposalId: "prop-1", kind: "feature", title: "T", description: nil,
            toolCallId: nil, rawInput: nil, orgId: orgB.id, orgGithubLogin: orgB.githubLogin
        )
        let result = AIAgentManager.resolveProposalOrg(proposalId: "prop-1", pendingProposal: pending)
        guard case .success(let org) = result else { return XCTFail("expected success") }
        XCTAssertEqual(org.id, orgB.id)
    }

    func testResolveProposalOrg_pendingOrgNoLongerCached_refused() {
        AIAgentManager.cacheHiveOrgs([orgA]) // orgB removed
        let pending = AIAgentManager.PendingProposal(
            proposalId: "prop-1", kind: "feature", title: "T", description: nil,
            toolCallId: nil, rawInput: nil, orgId: orgB.id, orgGithubLogin: orgB.githubLogin
        )
        let result = AIAgentManager.resolveProposalOrg(proposalId: "prop-1", pendingProposal: pending)
        guard case .failure = result else { return XCTFail("expected failure") }
    }

    func testResolveProposalOrg_historyOnlyUniqueMatch_resolves() {
        AIAgentManager.cacheHiveOrgs([orgA, orgB])
        AIAgentManager.persistCanvasHistory(orgId: orgA.id, history: [proposalMessage(proposalId: "prop-2")])
        AIAgentManager.persistCanvasHistory(orgId: orgB.id, history: [])

        let result = AIAgentManager.resolveProposalOrg(proposalId: "prop-2", pendingProposal: nil)
        guard case .success(let org) = result else { return XCTFail("expected success") }
        XCTAssertEqual(org.id, orgA.id)
    }

    func testResolveProposalOrg_foundInTwoOrgs_refused() {
        AIAgentManager.cacheHiveOrgs([orgA, orgB])
        AIAgentManager.persistCanvasHistory(orgId: orgA.id, history: [proposalMessage(proposalId: "prop-3")])
        AIAgentManager.persistCanvasHistory(orgId: orgB.id, history: [proposalMessage(proposalId: "prop-3")])

        let result = AIAgentManager.resolveProposalOrg(proposalId: "prop-3", pendingProposal: nil)
        guard case .failure = result else { return XCTFail("expected failure when found in >1 org") }
    }

    func testResolveProposalOrg_foundInNoOrg_refused() {
        AIAgentManager.cacheHiveOrgs([orgA, orgB])
        let result = AIAgentManager.resolveProposalOrg(proposalId: "prop-missing", pendingProposal: nil)
        guard case .failure = result else { return XCTFail("expected failure") }
    }

    func testResolveProposalOrg_legacyProposal_singleOrg_resolves() {
        AIAgentManager.cacheHiveOrgs([orgA])
        let legacy = AIAgentManager.PendingProposal(
            proposalId: "prop-legacy", kind: "feature", title: "T", description: nil,
            toolCallId: nil, rawInput: nil
            // orgId / orgGithubLogin default to nil — simulates JSON saved pre-multi-org
        )
        let result = AIAgentManager.resolveProposalOrg(proposalId: "prop-legacy", pendingProposal: legacy)
        guard case .success(let org) = result else { return XCTFail("expected success") }
        XCTAssertEqual(org.id, orgA.id)
    }

    func testResolveProposalOrg_legacyProposal_multipleOrgs_refused() {
        AIAgentManager.cacheHiveOrgs([orgA, orgB])
        let legacy = AIAgentManager.PendingProposal(
            proposalId: "prop-legacy-2", kind: "feature", title: "T", description: nil,
            toolCallId: nil, rawInput: nil
        )
        let result = AIAgentManager.resolveProposalOrg(proposalId: "prop-legacy-2", pendingProposal: legacy)
        guard case .failure = result else { return XCTFail("expected failure with multiple cached orgs") }
    }

    func testResolveProposalOrg_legacyJSON_decodesAndResolvesSingleOrg() {
        // Simulates a PendingProposal JSON blob persisted before orgId/orgGithubLogin existed.
        let legacyJSON = """
        {"proposalId":"prop-legacy-json","kind":"feature","title":"T","description":null,"toolCallId":null,"rawInput":null}
        """.data(using: .utf8)!
        let decoded = try! JSONDecoder().decode(AIAgentManager.PendingProposal.self, from: legacyJSON)
        XCTAssertNil(decoded.orgId)

        AIAgentManager.cacheHiveOrgs([orgA])
        let result = AIAgentManager.resolveProposalOrg(proposalId: "prop-legacy-json", pendingProposal: decoded)
        guard case .success(let org) = result else { return XCTFail("expected success") }
        XCTAssertEqual(org.id, orgA.id)
    }

    // MARK: - Concurrency

    func testConcurrentCanvasHistoryWrites_allOrgsSurvive() {
        let orgIds = (0..<20).map { "concurrent-org-\($0)" }
        let expectation = self.expectation(description: "all writes complete")
        expectation.expectedFulfillmentCount = orgIds.count

        DispatchQueue.concurrentPerform(iterations: orgIds.count) { i in
            let orgId = orgIds[i]
            let history = [AIAgentManager.CanvasChatMessage(role: "user", content: "msg-\(i)")]
            AIAgentManager.persistCanvasHistory(orgId: orgId, history: history)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10)

        for (i, orgId) in orgIds.enumerated() {
            let history = AIAgentManager.canvasHistory(orgId: orgId)
            XCTAssertEqual(history.count, 1, "history for \(orgId) should survive concurrent writes")
            XCTAssertEqual(history.first?.content, "msg-\(i)")
        }

        // Clean up the extra keys this test created.
        UserDefaults.Keys.hiveCanvasChatHistoryByOrg.removeValue()
    }
}
