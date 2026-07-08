//
//  NewChatHeaderView.swift
//  sphinx
//
//  Created by Tomas Timinskas on 29/05/2023.
//  Copyright © 2023 sphinx. All rights reserved.
//

import UIKit

class NewChatHeaderView: UIView {
    
    weak var searchDelegate: ChatSearchTextFieldViewDelegate?
    
    @IBOutlet var contentView: UIView!

    @IBOutlet weak var normalModeStackView: UIStackView!
    @IBOutlet weak var chatHeaderView: ChatHeaderView!
    @IBOutlet weak var pinnedMessageView: PinnedMessageView!
    @IBOutlet weak var threadHeaderView: ThreadHeaderView!
    @IBOutlet weak var chatSearchView: ChatSearchTextFieldView!
    
    // MARK: - Live Call Banner Stack
    
    /// Vertical stack of `ActiveCallBannerView` rows, pinned below `normalModeStackView`.
    /// Managed via `showCallBanner`, `hideCallBanner`, `hideAllCallBanners`, `rebuildBannerStack`.
    private(set) lazy var liveCallBannerStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.alignment = .fill
        sv.distribution = .equalSpacing
        sv.spacing = 0
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()
    
    /// Called whenever the banner stack is rebuilt (banners added, removed, or reordered).
    /// Use this to re-trigger `setTableViewHeight()` in the owning view controller.
    var onBannerStackHeightChanged: (() -> Void)?

    // MARK: - Internal Banner State
    
    /// Map from roomName → ActiveCallBannerView (all tracked rooms, including overflow).
    private var bannerViews: [String: ActiveCallBannerView] = [:]
    
    /// Ordered list of (roomName, messageDate) for all active (non-empty) rooms, newest-first.
    private var activeBannerEntries: [(roomName: String, messageDate: Date)] = []
    
    // MARK: - Init
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    private func setup() {
        Bundle.main.loadNibNamed("NewChatHeaderView", owner: self, options: nil)
        addSubview(contentView)
        
        contentView.frame = self.bounds
        contentView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        
        autoresizingMask = [.flexibleHeight, .flexibleWidth]
        
        installLiveCallBannerStack()
    }
    
    // MARK: - Banner Stack Installation
    
    private func installLiveCallBannerStack() {
        // The contentView hosts one outer stack (FI6-aK-lAW in XIB) whose first child is the
        // top-level outer stack containing normalModeStackView and threadHeaderView.
        // We insert the liveCallBannerStack as an arranged subview of that outer stack,
        // immediately after normalModeStackView, so the XIB-driven vertical stack
        // automatically reserves space for it and headerView.bounds.height grows accordingly.
        guard let outerStack = contentView.subviews.first(where: { $0 is UIStackView }) as? UIStackView else {
            return
        }
        // outerStack is the FI6-aK-lAW stack (contains: normalModeStackView, threadHeaderView, chatSearchView)
        // We want to insert liveCallBannerStack right after normalModeStackView (index 0) → index 1
        outerStack.insertArrangedSubview(liveCallBannerStack, at: 1)
    }
    
    // MARK: - Public Header Methods
    
    func checkRoute() {
        chatHeaderView.checkRoute()
    }
    
    func setChatInfoOnHeader() {
        chatHeaderView.setChatInfo()
    }
    
    func updateSatsEarnedOnHeader() {
        chatHeaderView.updateSatsEarned()
    }
    
    func toggleWebAppIcon(showChatIcon: Bool) {
        chatHeaderView.toggleWebAppIcon(showChatIcon: showChatIcon)
    }
    
    func toggleSBIcon(showChatIcon: Bool) {
        chatHeaderView.toggleSBIcon(showChatIcon: showChatIcon)
    }
    
    func configureHeaderWith(
        chat: Chat?,
        contact: UserContact?,
        andDelegate delegate: ChatHeaderViewDelegate,
        searchDelegate: ChatSearchTextFieldViewDelegate? = nil
    ) {
        chatHeaderView.configureWith(
            chat: chat,
            contact: contact,
            delegate: delegate
        )
        
        self.searchDelegate = searchDelegate
        
        chatSearchView.setDelegate(self)
    }
    
    func configureThreadHeaderWith(
        messageCellState: MessageTableCellState,
        mediaData: MessageTableCellState.MediaData?,
        delegate: ThreadHeaderViewDelegate
    ) {
        threadHeaderView.configureWith(
            messageCellState: messageCellState,
            mediaData: mediaData,
            delegate: delegate
        )
        threadHeaderView.isHidden = false
        
        normalModeStackView.isHidden = true
        chatSearchView.isHidden = true
    }
    
    func showThreadHeaderView() {
        threadHeaderView.isHidden = false
        
        normalModeStackView.isHidden = true
        chatSearchView.isHidden = true
    }
    
    func toggleThreadHeaderView(expanded: Bool) {
        threadHeaderView.toggleThreadHeaderView(expanded: expanded)
    }
    
    func configurePinnedMessageViewWith(
        chatId: Int,
        andDelegate delegate: PinnedMessageViewDelegate,
        completion: (() ->())? = nil
    ) {
        pinnedMessageView.configureWith(
            chatId: chatId,
            and: delegate,
            completion: completion
        )
    }
    
    func configureSearchMode(
        active: Bool
    ) {
        normalModeStackView.isHidden = active
        liveCallBannerStack.isHidden = active
        chatSearchView.isHidden = !active
        
        if active {
            chatSearchView.makeFieldActive()
        }
    }
    
    func configureScheduleIcon(
        lastMessage: TransactionMessage,
        ownerId: Int
    ) {
        chatHeaderView.configureScheduleIcon(
            lastMessage: lastMessage,
            ownerId: ownerId
        )
    }
    
    // MARK: - Live Call Banner Public API
    
    /// Upserts a banner for `roomName`, keeping the visible set capped at the newest 3.
    ///
    /// - Parameters:
    ///   - roomName: Unique key identifying the LiveKit room.
    ///   - participants: Current live participants; banner is hidden when this is empty.
    ///   - callLink: The full call URL used for Join/Open actions.
    ///   - messageDate: Creation date of the call message; used for newest-first ordering.
    ///   - isAlreadyInCall: Whether the local user is already in this room.
    ///   - delegate: Receives `didTapJoin` / `didTapOpen` callbacks.
    func showCallBanner(
        roomName: String,
        participants: [BubbleMessageLayoutState.CallParticipantInfo],
        callLink: String,
        messageDate: Date,
        isAlreadyInCall: Bool,
        delegate: ActiveCallBannerDelegate
    ) {
        // If participants is empty, treat as hide.
        guard !participants.isEmpty else {
            hideCallBanner(roomName: roomName)
            return
        }
        
        // Create banner view if needed.
        if bannerViews[roomName] == nil {
            let banner = ActiveCallBannerView()
            bannerViews[roomName] = banner
        }
        
        // Configure the banner.
        bannerViews[roomName]?.configureWith(
            participants: participants,
            callLink: callLink,
            isAlreadyInCall: isAlreadyInCall,
            delegate: delegate
        )
        
        // Upsert into activeBannerEntries (replace if exists, append if new).
        if let idx = activeBannerEntries.firstIndex(where: { $0.roomName == roomName }) {
            activeBannerEntries[idx] = (roomName: roomName, messageDate: messageDate)
        } else {
            activeBannerEntries.append((roomName: roomName, messageDate: messageDate))
        }
        
        rebuildBannerStack()
    }
    
    /// Removes the banner for `roomName` from the active set and reorders remaining banners.
    func hideCallBanner(roomName: String) {
        activeBannerEntries.removeAll { $0.roomName == roomName }
        bannerViews.removeValue(forKey: roomName)
        rebuildBannerStack()
    }
    
    /// Removes all banners and clears all internal state.
    func hideAllCallBanners() {
        activeBannerEntries.removeAll()
        bannerViews.removeAll()
        liveCallBannerStack.arrangedSubviews.forEach {
            liveCallBannerStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
    }
    
    /// Reorders `liveCallBannerStack`'s arranged subviews to match the current
    /// newest-first sorted, top-3-trimmed active list.
    ///
    /// Overflow rows (4th+ newest) are removed from the stack but their `ActiveCallBannerView`
    /// instances are retained in `bannerViews` so they can be re-added if a newer call ends.
    func rebuildBannerStack() {
        let (visible, _) = sortAndTrim(entries: activeBannerEntries, maxVisible: 3)
        
        // Remove all current arranged subviews without destroying them.
        liveCallBannerStack.arrangedSubviews.forEach {
            liveCallBannerStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        
        // Re-add visible banners newest-first.
        for entry in visible {
            if let banner = bannerViews[entry.roomName] {
                liveCallBannerStack.addArrangedSubview(banner)
            }
        }
        
        setNeedsLayout()
        layoutIfNeeded()
        onBannerStackHeightChanged?()
    }
    
    // MARK: - Pure Sort / Trim (internal for unit-test access)
    
    /// Given an unsorted list of `(roomName, messageDate)` pairs, returns:
    /// - `visible`:  newest-first, capped at `maxVisible` entries.
    /// - `overflow`: the remaining entries (oldest first after trim).
    ///
    /// This function is `internal` (not `private`) so unit tests can call it directly.
    func sortAndTrim(
        entries: [(roomName: String, messageDate: Date)],
        maxVisible: Int
    ) -> (visible: [(roomName: String, messageDate: Date)],
          overflow: [(roomName: String, messageDate: Date)]) {
        let sorted = entries.sorted { $0.messageDate > $1.messageDate }
        if sorted.count <= maxVisible {
            return (visible: sorted, overflow: [])
        }
        let visible  = Array(sorted.prefix(maxVisible))
        let overflow = Array(sorted.dropFirst(maxVisible))
        return (visible: visible, overflow: overflow)
    }
}

// MARK: - ChatSearchTextFieldViewDelegate

extension NewChatHeaderView : ChatSearchTextFieldViewDelegate {
    func shouldSearchFor(term: String) {
        searchDelegate?.shouldSearchFor(term: term)
    }
    
    func didTapSearchCancelButton() {
        configureSearchMode(active: false)
        
        searchDelegate?.didTapSearchCancelButton()
    }
}
