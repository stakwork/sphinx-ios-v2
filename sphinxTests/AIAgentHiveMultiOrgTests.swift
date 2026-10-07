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
        UserDefaults.Keys.hiveLastQueryAtByOrg.removeValue()
    }

    // MARK: - HiveConversation test helpers

    private func setConversationId(_ id: String?, orgId: String) {
        var dict: [String: String] = [:]
        if let data: Data = UserDefaults.Keys.hiveConversationIdByOrg.get(),
           let existing = try? JSONDecoder().decode([String: String].self, from: data) {
            dict = existing
        }
        if let id = id {
            dict[orgId] = id
        } else {
            dict.removeValue(forKey: orgId)
        }
        if let encoded = try? JSONEncoder().encode(dict) {
            UserDefaults.Keys.hiveConversationIdByOrg.set(encoded)
        }
    }

    private func getConversationId(orgId: String) -> String? {
        guard let data: Data = UserDefaults.Keys.hiveConversationIdByOrg.get(),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else { return nil }
        return dict[orgId]
    }

    private func setLastQueryAt(_ date: Date?, orgId: String) {
        var dict: [String: Double] = [:]
        if let data: Data = UserDefaults.Keys.hiveLastQueryAtByOrg.get(),
           let existing = try? JSONDecoder().decode([String: Double].self, from: data) {
            dict = existing
        }
        if let date = date {
            dict[orgId] = date.timeIntervalSince1970
        } else {
            dict.removeValue(forKey: orgId)
        }
        if let encoded = try? JSONEncoder().encode(dict) {
            UserDefaults.Keys.hiveLastQueryAtByOrg.set(encoded)
        }
    }

    private func setPendingProposal(_ proposal: AIAgentManager.PendingProposal?) {
        guard let proposal = proposal, let data = try? JSONEncoder().encode(proposal) else {
            UserDefaults.Keys.hivePendingProposal.removeValue()
            return
        }
        UserDefaults.Keys.hivePendingProposal.set(data)
    }

    /// An unactioned proposal card: a canvas message with a propose_* tool call
    /// and no `approvalResult` yet.
    private func unactionedProposalMessage(proposalId: String) -> AIAgentManager.CanvasChatMessage {
        proposalMessage(proposalId: proposalId)
    }

    /// An actioned proposal card: same shape, but with `approvalResult` set.
    private func actionedProposalMessage(proposalId: String) -> AIAgentManager.CanvasChatMessage {
        let toolCall = AIAgentManager.ToolCall(
            id: "call-\(proposalId)",
            toolName: "propose_feature",
            status: "output-available",
            input: ["proposalId": proposalId, "kind": "feature", "title": "Test"],
            output: ["proposalId": .string(proposalId), "kind": .string("feature")]
        )
        let result = AIAgentManager.ApprovalResult(approved: true, proposalId: proposalId)
        return AIAgentManager.CanvasChatMessage(role: "assistant", content: "result", toolCalls: [toolCall], approvalResult: result)
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

    func testResolveOrg_matchesByFuzzyName() {
        // "Stakwrok" is a one-transposition typo of "Stakwork" — Levenshtein distance 2
        // (standard edit distance has no transposition special-case), within the
        // threshold (max(1, len/4) = 2 for an 8-char name) and not a substring either
        // way, so this only resolves via the Levenshtein pass, not exact/contains.
        let org = makeOrg(id: "sw-1", login: "stakwork", name: "Stakwork")
        let result = AIAgentManager.resolveOrg("Stakwrok", in: [org])
        guard case .success(let resolved) = result else { return XCTFail("expected fuzzy success") }
        XCTAssertEqual(resolved.id, org.id)
    }

    func testResolveOrg_fuzzyNameAmbiguousWhenClose() {
        // "Keta" is Levenshtein distance 1 from both "Beta" and "Zeta" — an exact tie,
        // not "clearly closer" (needs dist+2 <= next), so this must stay ambiguous
        // rather than silently picking one.
        let beta = makeOrg(id: "1", login: "beta", name: "Beta")
        let zeta = makeOrg(id: "2", login: "zeta", name: "Zeta")
        let result = AIAgentManager.resolveOrg("Keta", in: [beta, zeta])
        guard case .failure(.ambiguous(let candidates)) = result else { return XCTFail("expected ambiguous") }
        XCTAssertEqual(Set(candidates.map { $0.id }), Set([beta.id, zeta.id]))
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

    // MARK: - hasUnactionedProposal

    func testHasUnactionedProposal_viaPendingSlot() {
        setPendingProposal(AIAgentManager.PendingProposal(
            proposalId: "p1", kind: "feature", title: "T", description: nil,
            toolCallId: nil, rawInput: nil, orgId: orgA.id, orgGithubLogin: orgA.githubLogin
        ))
        XCTAssertTrue(AIAgentManager.hasUnactionedProposal(orgId: orgA.id))
        XCTAssertFalse(AIAgentManager.hasUnactionedProposal(orgId: orgB.id))
    }

    func testHasUnactionedProposal_viaCanvasHistory_whenPendingSlotBelongsToAnotherOrg() {
        // Org B occupies the single pending slot, but org A has an unactioned
        // card sitting in its own canvas history — A must still be guarded.
        setPendingProposal(AIAgentManager.PendingProposal(
            proposalId: "p-b", kind: "feature", title: "T", description: nil,
            toolCallId: nil, rawInput: nil, orgId: orgB.id, orgGithubLogin: orgB.githubLogin
        ))
        AIAgentManager.persistCanvasHistory(orgId: orgA.id, history: [unactionedProposalMessage(proposalId: "p-a")])

        XCTAssertTrue(AIAgentManager.hasUnactionedProposal(orgId: orgA.id))
        XCTAssertTrue(AIAgentManager.hasUnactionedProposal(orgId: orgB.id))
    }

    func testHasUnactionedProposal_falseWhenCardIsActioned() {
        AIAgentManager.persistCanvasHistory(orgId: orgA.id, history: [actionedProposalMessage(proposalId: "p-a")])
        XCTAssertFalse(AIAgentManager.hasUnactionedProposal(orgId: orgA.id))
    }

    func testHasUnactionedProposal_falseWhenNothingStored() {
        XCTAssertFalse(AIAgentManager.hasUnactionedProposal(orgId: "unknown-org"))
    }

    // MARK: - conversationIdForQuery: scoped reset

    func testConversationIdForQuery_requestNew_clearsOnlyTargetOrg() {
        setConversationId("conv-a", orgId: orgA.id)
        setConversationId("conv-b", orgId: orgB.id)

        let (id, decision) = AIAgentManager.conversationIdForQuery(orgId: orgA.id, requestNew: true, now: Date())

        XCTAssertNil(id)
        XCTAssertEqual(decision.outcome, .reset)
        XCTAssertTrue(decision.requestedNew)
        XCTAssertFalse(decision.blockedByProposal)
        XCTAssertNil(getConversationId(orgId: orgA.id))
        XCTAssertEqual(getConversationId(orgId: orgB.id), "conv-b")
    }

    func testConversationIdForQuery_noFlagNoIdle_continues() {
        setConversationId("conv-a", orgId: orgA.id)
        setLastQueryAt(Date(), orgId: orgA.id)

        let (id, decision) = AIAgentManager.conversationIdForQuery(orgId: orgA.id, requestNew: false, now: Date())

        XCTAssertEqual(id, "conv-a")
        XCTAssertEqual(decision.outcome, .continued)
        XCTAssertFalse(decision.requestedNew)
        XCTAssertFalse(decision.idleExpired)
    }

    // MARK: - conversationIdForQuery: pending-slot guard

    func testConversationIdForQuery_requestNew_blockedBySameOrgPendingProposal() {
        setConversationId("conv-a", orgId: orgA.id)
        setPendingProposal(AIAgentManager.PendingProposal(
            proposalId: "p1", kind: "feature", title: "T", description: nil,
            toolCallId: nil, rawInput: nil, orgId: orgA.id, orgGithubLogin: orgA.githubLogin
        ))

        let (id, decision) = AIAgentManager.conversationIdForQuery(orgId: orgA.id, requestNew: true, now: Date())

        XCTAssertEqual(id, "conv-a")
        XCTAssertEqual(decision.outcome, .continued)
        XCTAssertTrue(decision.blockedByProposal)
        XCTAssertEqual(getConversationId(orgId: orgA.id), "conv-a")
    }

    func testConversationIdForQuery_requestNew_notBlockedByOtherOrgPendingProposal() {
        setConversationId("conv-a", orgId: orgA.id)
        setPendingProposal(AIAgentManager.PendingProposal(
            proposalId: "p1", kind: "feature", title: "T", description: nil,
            toolCallId: nil, rawInput: nil, orgId: orgB.id, orgGithubLogin: orgB.githubLogin
        ))

        let (id, decision) = AIAgentManager.conversationIdForQuery(orgId: orgA.id, requestNew: true, now: Date())

        XCTAssertNil(id)
        XCTAssertEqual(decision.outcome, .reset)
        XCTAssertFalse(decision.blockedByProposal)
    }

    // MARK: - conversationIdForQuery: canvas-history guard (proposal pushed out of slot)

    func testConversationIdForQuery_requestNew_blockedByCanvasHistoryProposal_pushedOutOfSlot() {
        setConversationId("conv-a", orgId: orgA.id)
        // Org A has an unactioned card in its own history...
        AIAgentManager.persistCanvasHistory(orgId: orgA.id, history: [unactionedProposalMessage(proposalId: "p-a")])
        // ...but the single pending slot now holds org B's proposal.
        setPendingProposal(AIAgentManager.PendingProposal(
            proposalId: "p-b", kind: "feature", title: "T", description: nil,
            toolCallId: nil, rawInput: nil, orgId: orgB.id, orgGithubLogin: orgB.githubLogin
        ))

        let (id, decision) = AIAgentManager.conversationIdForQuery(orgId: orgA.id, requestNew: true, now: Date())

        XCTAssertEqual(id, "conv-a")
        XCTAssertEqual(decision.outcome, .continued)
        XCTAssertTrue(decision.blockedByProposal)
    }

    func testConversationIdForQuery_requestNew_goesThroughOnceCanvasCardIsActioned() {
        setConversationId("conv-a", orgId: orgA.id)
        AIAgentManager.persistCanvasHistory(orgId: orgA.id, history: [actionedProposalMessage(proposalId: "p-a")])
        setPendingProposal(AIAgentManager.PendingProposal(
            proposalId: "p-b", kind: "feature", title: "T", description: nil,
            toolCallId: nil, rawInput: nil, orgId: orgB.id, orgGithubLogin: orgB.githubLogin
        ))

        let (id, decision) = AIAgentManager.conversationIdForQuery(orgId: orgA.id, requestNew: true, now: Date())

        XCTAssertNil(id)
        XCTAssertEqual(decision.outcome, .reset)
        XCTAssertFalse(decision.blockedByProposal)
    }

    // MARK: - conversationIdForQuery: idle backstop

    func test29MinutesIdle_continues() {
        setConversationId("conv-a", orgId: orgA.id)
        setLastQueryAt(Date().addingTimeInterval(-29 * 60), orgId: orgA.id)

        let (id, decision) = AIAgentManager.conversationIdForQuery(orgId: orgA.id, requestNew: false, now: Date())

        XCTAssertEqual(id, "conv-a")
        XCTAssertEqual(decision.outcome, .continued)
        XCTAssertFalse(decision.idleExpired)
    }

    func test31MinutesIdle_resets() {
        setConversationId("conv-a", orgId: orgA.id)
        setLastQueryAt(Date().addingTimeInterval(-31 * 60), orgId: orgA.id)

        let (id, decision) = AIAgentManager.conversationIdForQuery(orgId: orgA.id, requestNew: false, now: Date())

        XCTAssertNil(id)
        XCTAssertEqual(decision.outcome, .reset)
        XCTAssertTrue(decision.idleExpired)
    }

    func testMissingTimestamp_withStoredId_resets() {
        setConversationId("conv-a", orgId: orgA.id)
        // No timestamp set at all.
        let (id, decision) = AIAgentManager.conversationIdForQuery(orgId: orgA.id, requestNew: false, now: Date())

        XCTAssertNil(id)
        XCTAssertEqual(decision.outcome, .reset)
        XCTAssertTrue(decision.idleExpired)
    }

    func testMissingTimestamp_withNoId_isNoOp() {
        // Neither a timestamp nor a stored id — nothing to reset.
        let (id, decision) = AIAgentManager.conversationIdForQuery(orgId: orgA.id, requestNew: false, now: Date())

        XCTAssertNil(id)
        XCTAssertEqual(decision.outcome, .continued)
        XCTAssertFalse(decision.idleExpired)
    }

    func testIdleReset_blockedByUnactionedProposal() {
        setConversationId("conv-a", orgId: orgA.id)
        setLastQueryAt(Date().addingTimeInterval(-31 * 60), orgId: orgA.id)
        setPendingProposal(AIAgentManager.PendingProposal(
            proposalId: "p1", kind: "feature", title: "T", description: nil,
            toolCallId: nil, rawInput: nil, orgId: orgA.id, orgGithubLogin: orgA.githubLogin
        ))

        let (id, decision) = AIAgentManager.conversationIdForQuery(orgId: orgA.id, requestNew: false, now: Date())

        XCTAssertEqual(id, "conv-a")
        XCTAssertEqual(decision.outcome, .continued)
        XCTAssertTrue(decision.idleExpired)
        XCTAssertTrue(decision.blockedByProposal)
    }

    // MARK: - storeConversationId (compare-and-set)

    func testStoreConversationId_staleStartedWith_doesNotOverwriteNewerId() {
        setConversationId("new-id", orgId: orgA.id)
        let wrote = AIAgentManager.storeConversationId(orgId: orgA.id, newId: "late-id", startedWith: "old-id")

        XCTAssertFalse(wrote)
        XCTAssertEqual(getConversationId(orgId: orgA.id), "new-id")
    }

    func testStoreConversationId_nilStartedWith_writesIntoEmptySlot() {
        let wrote = AIAgentManager.storeConversationId(orgId: orgA.id, newId: "first-id", startedWith: nil)

        XCTAssertTrue(wrote)
        XCTAssertEqual(getConversationId(orgId: orgA.id), "first-id")
    }

    func testStoreConversationId_twoNilStartedWrites_firstWins() {
        let firstWrote = AIAgentManager.storeConversationId(orgId: orgA.id, newId: "race-first", startedWith: nil)
        XCTAssertTrue(firstWrote)

        // Second racer also started with nil, but the slot is no longer nil —
        // it must not clobber the first writer's id.
        let secondWrote = AIAgentManager.storeConversationId(orgId: orgA.id, newId: "race-second", startedWith: nil)
        XCTAssertFalse(secondWrote)
        XCTAssertEqual(getConversationId(orgId: orgA.id), "race-first")
    }

    func testStoreConversationId_lateWriteCannotResurrectAClearedId() {
        setConversationId("old-id", orgId: orgA.id)
        // A reset clears the slot...
        setConversationId(nil, orgId: orgA.id)
        // ...then a late response from the stream that started with "old-id" arrives.
        let wrote = AIAgentManager.storeConversationId(orgId: orgA.id, newId: "late-id", startedWith: "old-id")

        XCTAssertFalse(wrote)
        XCTAssertNil(getConversationId(orgId: orgA.id))
    }

    func testStoreConversationId_sameValueAsNewId_stillWrites() {
        setConversationId("same-id", orgId: orgA.id)
        let wrote = AIAgentManager.storeConversationId(orgId: orgA.id, newId: "same-id", startedWith: "something-else")
        XCTAssertTrue(wrote)
        XCTAssertEqual(getConversationId(orgId: orgA.id), "same-id")
    }

    // MARK: - recordHiveQuery

    func testRecordHiveQuery_writesTimestamp() {
        let now = Date()
        AIAgentManager.recordHiveQuery(orgId: orgA.id, at: now)

        guard let data: Data = UserDefaults.Keys.hiveLastQueryAtByOrg.get(),
              let dict = try? JSONDecoder().decode([String: Double].self, from: data),
              let stored = dict[orgA.id] else {
            return XCTFail("expected a stored timestamp")
        }
        XCTAssertEqual(stored, now.timeIntervalSince1970, accuracy: 0.001)
    }

    // MARK: - QueryHiveGraphInput decoding

    func testQueryHiveGraphInput_decodesWithoutNewConversation() {
        let json = """
        {"question": "what is up?"}
        """.data(using: .utf8)!
        let decoded = try! JSONDecoder().decode(AIAgentManager.QueryHiveGraphInput.self, from: json)
        XCTAssertEqual(decoded.question, "what is up?")
        XCTAssertNil(decoded.newConversation)
    }

    func testQueryHiveGraphInput_decodesWithNewConversation() {
        let json = """
        {"question": "what is up?", "org": "org-a-login", "new_conversation": true}
        """.data(using: .utf8)!
        let decoded = try! JSONDecoder().decode(AIAgentManager.QueryHiveGraphInput.self, from: json)
        XCTAssertEqual(decoded.question, "what is up?")
        XCTAssertEqual(decoded.org, "org-a-login")
        XCTAssertEqual(decoded.newConversation, true)
    }

    // MARK: - Pruning hiveLastQueryAtByOrg

    func testPruning_removesLastQueryAtForRemovedOrgs() {
        // Simulates the pruning block in fetchAndCacheHiveOrgs: orgB is removed
        // from the cached org list, so its activity timestamp should be pruned
        // the same way its slugs/conversation id/canvas history already are.
        setLastQueryAt(Date(), orgId: orgA.id)
        setLastQueryAt(Date(), orgId: orgB.id)

        let removedIds: Set<String> = [orgB.id]
        if let data: Data = UserDefaults.Keys.hiveLastQueryAtByOrg.get(),
           var dict = try? JSONDecoder().decode([String: Double].self, from: data) {
            for id in removedIds { dict.removeValue(forKey: id) }
            if let encoded = try? JSONEncoder().encode(dict) {
                UserDefaults.Keys.hiveLastQueryAtByOrg.set(encoded)
            }
        }

        guard let data: Data = UserDefaults.Keys.hiveLastQueryAtByOrg.get(),
              let dict = try? JSONDecoder().decode([String: Double].self, from: data) else {
            return XCTFail("expected remaining data")
        }
        XCTAssertNotNil(dict[orgA.id])
        XCTAssertNil(dict[orgB.id])
    }

    // MARK: - Regression: fetchAndCacheOrgSlugs still respects proposal guard

    func testHasUnactionedProposalLocked_matchesPreviousInlinePendingCheck() {
        // Regression check for the fetchAndCacheOrgSlugs switch to
        // hasUnactionedProposalLocked: a pending proposal belonging to this
        // org must still be detected (this was the only case the old inline
        // check covered).
        setPendingProposal(AIAgentManager.PendingProposal(
            proposalId: "p1", kind: "feature", title: "T", description: nil,
            toolCallId: nil, rawInput: nil, orgId: orgA.id, orgGithubLogin: orgA.githubLogin
        ))
        XCTAssertTrue(AIAgentManager.withHiveCacheLock { AIAgentManager.hasUnactionedProposalLocked(orgId: orgA.id) })
        XCTAssertFalse(AIAgentManager.withHiveCacheLock { AIAgentManager.hasUnactionedProposalLocked(orgId: orgB.id) })
    }

    // MARK: - No deadlock: conversationIdForQuery can be called from a context
    // that does not already hold the lock, repeatedly and concurrently.

    func testConversationIdForQuery_noDeadlockUnderConcurrency() {
        let orgIds = (0..<10).map { "concurrent-conv-org-\($0)" }
        let expectation = self.expectation(description: "all decisions complete")
        expectation.expectedFulfillmentCount = orgIds.count

        DispatchQueue.concurrentPerform(iterations: orgIds.count) { i in
            let orgId = orgIds[i]
            _ = AIAgentManager.conversationIdForQuery(orgId: orgId, requestNew: true, now: Date())
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10)
    }
}
