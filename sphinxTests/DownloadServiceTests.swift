//
//  DownloadServiceTests.swift
//  sphinxTests
//
//  Missing URL / missing activeDownloads entries must return without
//  touching Core Data. ContentFeed mutation is hopped off the session queue.
//

import XCTest
@testable import sphinx

final class DownloadServiceTests: XCTestCase {

    func testHandlePodcastDownloadUpdate_missingActiveDownload_returnsWithoutTrapping() {
        let service = DownloadService()
        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }

        guard let url = URL(string: "https://example.com/episode.mp3") else {
            XCTFail("Failed to build test URL")
            return
        }
        let task = session.downloadTask(with: url)

        service.handlePodcastDownloadUpdate(
            downloadTask: task,
            totalBytesWritten: 50,
            totalBytesExpectedToWrite: 100
        )

        XCTAssertTrue(service.activeDownloads.isEmpty)
    }

    func testHandlePodcastDownloadCompletion_nilDownload_returnsWithoutTrapping() {
        let service = DownloadService()

        service.handlePodcastDownloadCompletion(
            download: nil,
            urlString: "https://example.com/episode.mp3",
            location: URL(fileURLWithPath: "/tmp/episode.mp3")
        )

        XCTAssertTrue(service.activeDownloads.isEmpty)
    }
}
