//
//  PaginationControlViewTests.swift
//  sphinxTests
//
//  Copyright © 2025 Sphinx. All rights reserved.
//

import XCTest
import SwiftyJSON
@testable import sphinx

class PaginationControlViewTests: XCTestCase {

    // MARK: - Helpers

    private func makePaginationView() -> PaginationControlView {
        let view = PaginationControlView(frame: .zero)
        return view
    }

    // MARK: - isHidden when totalPages <= 1

    func testConfigureWithOnePage_IsHidden() {
        let view = makePaginationView()
        view.configure(currentPage: 1, totalPages: 1)
        XCTAssertTrue(view.isHidden, "View should be hidden when totalPages == 1")
    }

    func testConfigureWithZeroPages_IsHidden() {
        let view = makePaginationView()
        view.configure(currentPage: 1, totalPages: 0)
        XCTAssertTrue(view.isHidden, "View should be hidden when totalPages == 0")
    }

    func testConfigureWithTwoPages_IsVisible() {
        let view = makePaginationView()
        view.configure(currentPage: 1, totalPages: 2)
        XCTAssertFalse(view.isHidden, "View should be visible when totalPages == 2")
    }

    func testConfigureWithManyPages_IsVisible() {
        let view = makePaginationView()
        view.configure(currentPage: 1, totalPages: 20)
        XCTAssertFalse(view.isHidden, "View should be visible when totalPages == 20")
    }

    // MARK: - Page window calculation

    func testPageWindow_FirstPage_SmallTotal() {
        let view = makePaginationView()
        // 2 total pages, on page 1 → [1, 2]
        let window = view.pageWindow(currentPage: 1, totalPages: 2)
        XCTAssertEqual(window, [1, 2])
    }

    func testPageWindow_FirstPage_LargeTotal() {
        let view = makePaginationView()
        // On page 1 of 20 → should show [1,2,3,4,5]
        let window = view.pageWindow(currentPage: 1, totalPages: 20)
        XCTAssertEqual(window, [1, 2, 3, 4, 5])
    }

    func testPageWindow_MiddlePage() {
        let view = makePaginationView()
        // On page 6 of 20 → should show [4,5,6,7,8]
        let window = view.pageWindow(currentPage: 6, totalPages: 20)
        XCTAssertEqual(window, [4, 5, 6, 7, 8])
    }

    func testPageWindow_LastPage() {
        let view = makePaginationView()
        // On page 20 of 20 → should show [16,17,18,19,20]
        let window = view.pageWindow(currentPage: 20, totalPages: 20)
        XCTAssertEqual(window, [16, 17, 18, 19, 20])
    }

    func testPageWindow_NearLastPage() {
        let view = makePaginationView()
        // On page 19 of 20 → should show [16,17,18,19,20]
        let window = view.pageWindow(currentPage: 19, totalPages: 20)
        XCTAssertEqual(window, [16, 17, 18, 19, 20])
    }

    func testPageWindow_ExactlyFivePages_PageOne() {
        let view = makePaginationView()
        let window = view.pageWindow(currentPage: 1, totalPages: 5)
        XCTAssertEqual(window, [1, 2, 3, 4, 5])
    }

    func testPageWindow_ExactlyFivePages_PageThree() {
        let view = makePaginationView()
        let window = view.pageWindow(currentPage: 3, totalPages: 5)
        XCTAssertEqual(window, [1, 2, 3, 4, 5])
    }

    func testPageWindow_ExactlyFivePages_PageFive() {
        let view = makePaginationView()
        let window = view.pageWindow(currentPage: 5, totalPages: 5)
        XCTAssertEqual(window, [1, 2, 3, 4, 5])
    }

    func testPageWindow_OnePage_ReturnsEmpty() {
        let view = makePaginationView()
        let window = view.pageWindow(currentPage: 1, totalPages: 1)
        XCTAssertTrue(window.isEmpty, "Window should be empty for totalPages == 1")
    }

    func testPageWindow_CurrentPageAlwaysInWindow() {
        let view = makePaginationView()
        for total in [5, 10, 20] {
            for current in 1...total {
                let window = view.pageWindow(currentPage: current, totalPages: total)
                XCTAssertTrue(window.contains(current),
                              "Window \(window) should contain current page \(current) (total: \(total))")
            }
        }
    }

    func testPageWindow_NeverExceedsFiveButtons() {
        let view = makePaginationView()
        for total in [2, 3, 5, 10, 20] {
            for current in 1...total {
                let window = view.pageWindow(currentPage: current, totalPages: total)
                XCTAssertLessThanOrEqual(window.count, 5,
                                         "Window should never exceed 5 buttons (total: \(total), current: \(current))")
            }
        }
    }

    // MARK: - Arrow button enabled/disabled states

    func testArrowStates_PageOne_FirstAndPrevDisabled() {
        let view = makePaginationView()
        view.configure(currentPage: 1, totalPages: 5)

        // Find buttons by tag
        let firstBtn = findButton(in: view, tag: -2)
        let prevBtn  = findButton(in: view, tag: -1)
        let nextBtn  = findButton(in: view, tag: -3)
        let lastBtn  = findButton(in: view, tag: -4)

        XCTAssertFalse(firstBtn?.isEnabled ?? true, "First button should be disabled on page 1")
        XCTAssertFalse(prevBtn?.isEnabled  ?? true, "Prev button should be disabled on page 1")
        XCTAssertTrue(nextBtn?.isEnabled   ?? false, "Next button should be enabled on page 1")
        XCTAssertTrue(lastBtn?.isEnabled   ?? false, "Last button should be enabled on page 1")
    }

    func testArrowStates_LastPage_NextAndLastDisabled() {
        let view = makePaginationView()
        view.configure(currentPage: 5, totalPages: 5)

        let firstBtn = findButton(in: view, tag: -2)
        let prevBtn  = findButton(in: view, tag: -1)
        let nextBtn  = findButton(in: view, tag: -3)
        let lastBtn  = findButton(in: view, tag: -4)

        XCTAssertTrue(firstBtn?.isEnabled  ?? false, "First button should be enabled on last page")
        XCTAssertTrue(prevBtn?.isEnabled   ?? false, "Prev button should be enabled on last page")
        XCTAssertFalse(nextBtn?.isEnabled  ?? true,  "Next button should be disabled on last page")
        XCTAssertFalse(lastBtn?.isEnabled  ?? true,  "Last button should be disabled on last page")
    }

    func testArrowStates_MiddlePage_AllEnabled() {
        let view = makePaginationView()
        view.configure(currentPage: 3, totalPages: 5)

        let firstBtn = findButton(in: view, tag: -2)
        let prevBtn  = findButton(in: view, tag: -1)
        let nextBtn  = findButton(in: view, tag: -3)
        let lastBtn  = findButton(in: view, tag: -4)

        XCTAssertTrue(firstBtn?.isEnabled ?? false, "First should be enabled in the middle")
        XCTAssertTrue(prevBtn?.isEnabled  ?? false, "Prev should be enabled in the middle")
        XCTAssertTrue(nextBtn?.isEnabled  ?? false, "Next should be enabled in the middle")
        XCTAssertTrue(lastBtn?.isEnabled  ?? false, "Last should be enabled in the middle")
    }

    // MARK: - PaginationInfo JSON parsing

    func testPaginationInfo_FullJSON() {
        let json = JSON(["page": 3, "totalPages": 10, "totalCount": 195, "hasMore": true])
        let info = PaginationInfo(json: json)
        XCTAssertEqual(info.page, 3)
        XCTAssertEqual(info.totalPages, 10)
        XCTAssertEqual(info.totalCount, 195)
        XCTAssertTrue(info.hasMore)
    }

    func testPaginationInfo_EmptyJSON_UsesDefaults() {
        let info = PaginationInfo(json: JSON([:]))
        XCTAssertEqual(info.page, 1)
        XCTAssertEqual(info.totalPages, 1)
        XCTAssertEqual(info.totalCount, 0)
        XCTAssertFalse(info.hasMore)
    }

    func testPaginationInfo_PartialJSON() {
        let json = JSON(["page": 2, "totalPages": 5])
        let info = PaginationInfo(json: json)
        XCTAssertEqual(info.page, 2)
        XCTAssertEqual(info.totalPages, 5)
        XCTAssertEqual(info.totalCount, 0,  "Missing totalCount should default to 0")
        XCTAssertFalse(info.hasMore,        "Missing hasMore should default to false")
    }

    func testPaginationInfo_Empty_StaticProperty() {
        let info = PaginationInfo.empty
        XCTAssertEqual(info.page, 1)
        XCTAssertEqual(info.totalPages, 1)
        XCTAssertEqual(info.totalCount, 0)
        XCTAssertFalse(info.hasMore)
    }

    func testPaginationInfo_HasMoreFalse() {
        let json = JSON(["page": 5, "totalPages": 5, "totalCount": 100, "hasMore": false])
        let info = PaginationInfo(json: json)
        XCTAssertFalse(info.hasMore)
        XCTAssertEqual(info.page, 5)
        XCTAssertEqual(info.totalPages, 5)
    }

    // MARK: - Private helpers

    private func findButton(in view: UIView, tag: Int) -> UIButton? {
        for subview in view.subviews {
            if let btn = subview as? UIButton, btn.tag == tag { return btn }
            // Also check inside stack view
            if let stack = subview as? UIStackView {
                for arranged in stack.arrangedSubviews {
                    if let btn = arranged as? UIButton, btn.tag == tag { return btn }
                }
            }
        }
        return nil
    }
}
