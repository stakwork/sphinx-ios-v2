//
//  GraphChatSSEManagerTests.swift
//  sphinxTests
//
//  stopOrgStream must fully tear down the retained org session, task, and
//  conversation-id callback so a delayed URLSession callback cannot race a
//  niled closure on a background queue.
//

import XCTest
@testable import sphinx

final class GraphChatSSEManagerTests: XCTestCase {

    func testStopOrgStream_clearsTaskSessionAndCallback() {
        let manager = GraphChatSSEManager()
        manager.onConversationId = { _ in }
        manager.orgSession = URLSession(configuration: .ephemeral)

        XCTAssertNotNil(manager.onConversationId)
        XCTAssertNotNil(manager.orgSession)

        manager.stopOrgStream()

        XCTAssertNil(manager.orgDataTask)
        XCTAssertNil(manager.orgSession)
        XCTAssertNil(manager.onConversationId)
    }
}
