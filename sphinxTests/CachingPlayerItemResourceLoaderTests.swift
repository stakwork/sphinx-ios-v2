//
//  CachingPlayerItemResourceLoaderTests.swift
//  sphinxTests
//
//  Unit tests for nil-safe ResourceLoaderDelegate helpers.
//  AVAssetResourceLoadingRequest cannot be constructed, so tests drive
//  extracted helpers on in-memory nil/empty loader state.
//

import XCTest
@testable import sphinx

final class CachingPlayerItemResourceLoaderTests: XCTestCase {

    func testAppendSessionData_whenMediaDataIsNil_doesNotTrap() {
        let loader = CachingPlayerItem.ResourceLoaderDelegate()
        XCTAssertNil(loader.mediaData)

        let result = loader.appendSessionData(Data([0x01, 0x02]), bytesExpected: 2)

        XCTAssertNil(result)
        XCTAssertNil(loader.mediaData)
        XCTAssertTrue(loader.pendingRequests.isEmpty)
    }

    func testAppendSessionData_whenMediaDataExists_appendsAndReturnsProgress() {
        let loader = CachingPlayerItem.ResourceLoaderDelegate()
        loader.mediaData = Data([0x01])

        let result = loader.appendSessionData(Data([0x02, 0x03]), bytesExpected: 10)

        XCTAssertEqual(result?.bytesDownloaded, 3)
        XCTAssertEqual(result?.bytesExpected, 10)
        XCTAssertEqual(loader.mediaData, Data([0x01, 0x02, 0x03]))
    }

    func testCompleteSession_withNilMediaData_clearsPendingAndDoesNotTrap() {
        let loader = CachingPlayerItem.ResourceLoaderDelegate()
        XCTAssertNil(loader.mediaData)

        loader.completeSession(error: nil)

        XCTAssertTrue(loader.pendingRequests.isEmpty)
        XCTAssertNil(loader.mediaData)
    }

    func testCompleteSession_withSessionError_clearsPendingRequests() {
        let loader = CachingPlayerItem.ResourceLoaderDelegate()
        let sessionError = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut, userInfo: nil)

        loader.completeSession(error: sessionError)

        XCTAssertTrue(loader.pendingRequests.isEmpty)
    }

    func testFailPendingRequests_clearsPendingSetWithoutTrapping() {
        let loader = CachingPlayerItem.ResourceLoaderDelegate()
        let error = CachingPlayerItem.ResourceLoaderDelegate.resourceLoadError(
            "resource load failed"
        )
        XCTAssertEqual(error.domain, "com.sphinx.CachingPlayerItem")
        XCTAssertEqual(error.code, 1)

        loader.failPendingRequests(with: error)

        XCTAssertTrue(loader.pendingRequests.isEmpty)
    }

    func testCanStartDataRequest_whenOwnerIsNil_returnsFalse() {
        let loader = CachingPlayerItem.ResourceLoaderDelegate()
        XCTAssertNil(loader.owner)
        XCTAssertFalse(loader.canStartDataRequest())
    }

    func testFillInContentInformationRequest_playingFromDataWithNilMediaData_doesNotTrap() {
        let loader = CachingPlayerItem.ResourceLoaderDelegate()
        loader.playingFromData = true
        loader.mediaData = nil

        loader.fillInContentInformationRequest(nil)

        XCTAssertFalse(loader.canFillContentInformation)
        XCTAssertTrue(loader.pendingRequests.isEmpty)
    }

    func testCompleteSession_withMediaData_doesNotFailOrTrap() {
        let loader = CachingPlayerItem.ResourceLoaderDelegate()
        loader.mediaData = Data([0x01, 0x02])

        loader.completeSession(error: nil)

        XCTAssertTrue(loader.pendingRequests.isEmpty)
        XCTAssertEqual(loader.mediaData, Data([0x01, 0x02]))
    }

    func testResourceLoadError_usesSingleDomainAndCode() {
        let error = CachingPlayerItem.ResourceLoaderDelegate.resourceLoadError(
            "media URL is missing"
        )
        XCTAssertEqual(
            error.domain,
            CachingPlayerItem.ResourceLoaderDelegate.resourceLoadErrorDomain
        )
        XCTAssertEqual(
            error.code,
            CachingPlayerItem.ResourceLoaderDelegate.resourceLoadErrorCode
        )
        XCTAssertEqual(error.localizedDescription, "media URL is missing")
    }
}
