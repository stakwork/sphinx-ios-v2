//
//  ChatPagination.swift
//  sphinx
//
//  Explicit pagination phase machine, real-id probe helpers, and
//  predicate/fetch-limit construction for NewChatTableDataSource.
//  Thread views keep their existing isThread early-exits and do not
//  run this machine.
//

import Foundation

enum PaginationPhase: Equatable {
    case idle
    case loading
    case exhausted
}

struct PaginationState: Equatable {
    var phase: PaginationPhase = .idle
    var pendingScrollRestore = false
    var didAutoPageOnFirstLoad = false
    var fetchMinIndex: Int = 0
    var fetchOldestDate: Date? = nil

    mutating func resetOnChatSwitch() {
        print("pagination chat switch reset → idle")
        phase = .idle
        pendingScrollRestore = false
        didAutoPageOnFirstLoad = false
        fetchMinIndex = 0
        fetchOldestDate = nil
    }

    /// Preconditions run before entering `.loading`. Returns false if the load must not start.
    mutating func beginUserLoad(isThread: Bool, hasChat: Bool) -> Bool {
        if isThread {
            print("pagination skip: thread")
            return false
        }
        if phase != .idle {
            print("pagination skip: phase=\(phase)")
            return false
        }
        if pendingScrollRestore {
            print("pagination skip: pendingScrollRestore")
            return false
        }
        if !hasChat {
            print("pagination skip: no chat")
            return false
        }
        print("pagination idle→loading")
        phase = .loading
        return true
    }

    /// Every path that entered `.loading` and cannot finish must return to `.idle`.
    mutating func failToStart(reason: String) {
        if phase == .loading {
            print("pagination loading→idle (\(reason))")
            phase = .idle
        }
    }

    mutating func completeNetworkPage(messagesCount: Int, itemsPerPage: Int) {
        let wasLoading = phase == .loading
        if wasLoading {
            pendingScrollRestore = true
        }
        if messagesCount < itemsPerPage {
            print("pagination loading→exhausted network messagesCount=\(messagesCount) < page=\(itemsPerPage)")
            phase = .exhausted
        } else if wasLoading {
            print("pagination loading→idle network messagesCount=\(messagesCount) >= page=\(itemsPerPage)")
            phase = .idle
        }
    }

    mutating func completeAlreadyAtOldest() {
        print("pagination loading→exhausted already-at-oldest")
        if phase == .loading {
            pendingScrollRestore = true
        }
        phase = .exhausted
    }

    func shouldRestoreScroll() -> Bool {
        pendingScrollRestore || phase == .loading
    }

    func shouldAutoFillOnFirstLoad(allContentVisible: Bool) -> Bool {
        allContentVisible
            && phase == .idle
            && !pendingScrollRestore
            && !didAutoPageOnFirstLoad
    }

    mutating func markAutoFilled() {
        print("pagination first-load auto-fill")
        didAutoPageOnFirstLoad = true
    }
}

enum ChatPaginationProbe {
    /// `minId` is the smallest non-negative id. `oldestDate` is the minimum
    /// non-nil date among all probe rows (not `objects.last?.date`). All-nil
    /// dates fall back to `Date.distantPast`.
    static func minIndexAndOldestDate(
        from rows: [(id: Int, date: Date?)]
    ) -> (minId: Int, oldestDate: Date)? {
        let realRows = rows.filter { $0.id >= 0 }
        guard let minId = realRows.map({ $0.id }).min() else {
            return nil
        }
        let oldestDate = realRows.compactMap { $0.date }.min() ?? Date.distantPast
        return (minId, oldestDate)
    }
}

enum ChatMessagePredicateBuilder {
    /// Extra id/date restriction appended onto the chat + type-exclusion predicate.
    /// `nil` means no extra restriction (first page / `getAllMessagesFor`).
    static func idRestrictionFormat(
        minIndex: Int?,
        pinnedMessageId: Int?,
        oldestDate: Date?
    ) -> String? {
        if let pinnedMessageId {
            let lowerBound = max(0, pinnedMessageId - 200)
            if oldestDate != nil {
                return "(id >= \(lowerBound) OR (id < 0 AND date >= %@))"
            }
            return "id >= \(lowerBound)"
        }
        if let minIndex {
            if oldestDate != nil {
                return "(id >= \(minIndex) OR (id < 0 AND date >= %@))"
            }
            return "id >= \(minIndex)"
        }
        return nil
    }

    static func paginationProbeFormat() -> String {
        "chat == %@ AND id >= 0 AND (NOT (type IN %@) || (type == %d && replyUUID = nil))"
    }

    static func pinnedProbeFormat(pinnedMessageId: Int) -> String {
        let lowerBound = max(0, pinnedMessageId - 200)
        return "chat == %@ AND id >= \(lowerBound) AND id >= 0 AND (NOT (type IN %@) || (type == %d && replyUUID = nil))"
    }

    static func minMessageIndexFormat() -> String {
        "chat == %@ AND id >= 0"
    }

    static func threadFormat() -> String {
        "chat == %@ AND (NOT (type IN %@) || (type == %d && replyUUID = nil)) AND threadUUID == %@"
    }

    static func unboundedChatFormat() -> String {
        "chat == %@ AND (NOT (type IN %@) || (type == %d && replyUUID = nil))"
    }
}

struct ChatMessagesFetchRequestConfig: Equatable {
    let fetchLimit: Int?

    static func main(
        limit: Int?,
        pinnedMessageId: Int?,
        minIndex: Int?
    ) -> ChatMessagesFetchRequestConfig {
        let applyLimit = limit != nil && pinnedMessageId == nil && minIndex == nil
        return ChatMessagesFetchRequestConfig(fetchLimit: applyLimit ? limit : nil)
    }

    static func paginationProbe(items: Int) -> ChatMessagesFetchRequestConfig {
        ChatMessagesFetchRequestConfig(fetchLimit: items)
    }

    static func pinnedProbe() -> ChatMessagesFetchRequestConfig {
        ChatMessagesFetchRequestConfig(fetchLimit: nil)
    }
}
