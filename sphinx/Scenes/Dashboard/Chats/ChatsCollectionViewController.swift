import UIKit
import SphinxErrorReporter


class ChatsCollectionViewController: UICollectionViewController {
    
    var chatListObjects: [ChatListCommonObject] = []
    var onChatSelected: ((ChatListCommonObject) -> Void)?
    var onContentScrolled: ((UIScrollView) -> Void)?
    var onRefresh: ((UIRefreshControl) -> Void)?
    
    private weak var chatsListDelegate: DashboardChatsListDelegate?

    // Internal so snapshot fail-closed recovery can be exercised from tests.
    var dataSource: DataSource!
    
    private var owner: UserContact!
    
    private var updateWorkItem: DispatchWorkItem?
    var applyGate = ChatListSnapshotApplyGate()
    var snapshotGeneration = 0
    var onCollectionViewExceptionCaptured: ((String?, Bool) -> Void)?
    /// Test-only: when set, the primary apply path raises this ObjC exception
    /// instead of calling `apply`, simulating a UIKit duplicate-identifier failure.
    var testForcePrimaryApplyExceptionReason: String?
    
    private let itemContentInsets = NSDirectionalEdgeInsets(
        top: 0,
        leading: 0,
        bottom: 0,
        trailing: 0
    )
    
    func shouldReloadRowFor(chatId: Int) {
        shouldReloadChatRowsFor(chatIds: [chatId])
    }
    
    func shouldReloadChatRowsFor(chatIds _: [Int]) {
        applyCurrentSnapshot()
    }
}


// MARK: - Instantiation
extension ChatsCollectionViewController {

    static func instantiate(
        chatListObjects: [ChatListCommonObject] = [],
        chatsListDelegate: DashboardChatsListDelegate?,
        onChatSelected: ((ChatListCommonObject) -> Void)? = nil,
        onContentScrolled: ((UIScrollView) -> Void)? = nil,
        onRefresh: ((UIRefreshControl) -> Void)? = nil
    ) -> ChatsCollectionViewController {
        
        let viewController = StoryboardScene.Dashboard.chatsCollectionViewController.instantiate()
        
        viewController.chatListObjects = chatListObjects
        viewController.chatsListDelegate = chatsListDelegate
        viewController.onChatSelected = onChatSelected
        viewController.onContentScrolled = onContentScrolled
        viewController.onRefresh = onRefresh

        return viewController
    }
}


// MARK: - Layout & Data Structure
extension ChatsCollectionViewController {
    enum CollectionViewSection: Int, CaseIterable {
        case all
    }
    
    struct DataSourceItem: Hashable {
        
        var objectId: String

        init(objectId: String) {
            self.objectId = objectId
        }
        
        static func == (lhs: DataSourceItem, rhs: DataSourceItem) -> Bool {
            lhs.objectId == rhs.objectId
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(objectId)
        }

        /// First-wins uniqueness by `objectId`, preserving relative order.
        static func uniqueByObjectId(_ items: [DataSourceItem]) -> [DataSourceItem] {
            var seenObjectIds = Set<String>()
            return items.filter { item in
                if seenObjectIds.contains(item.objectId) {
                    return false
                }
                seenObjectIds.insert(item.objectId)
                return true
            }
        }
    }


    typealias CollectionViewCell = ChatListCollectionViewCell
    typealias CellDataItem = DataSourceItem
    typealias DataSource = UICollectionViewDiffableDataSource<CollectionViewSection, CellDataItem>
    typealias DataSourceSnapshot = NSDiffableDataSourceSnapshot<CollectionViewSection, CellDataItem>
}


// MARK: - Lifecycle
extension ChatsCollectionViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.accessibilityIdentifier = "ChatsCollectionViewController"
        loadChatsList()
        addAccessibilityIdentifiers()
    }
    
    func loadChatsList() {
        registerViews(for: collectionView)
        configure(collectionView)
        configureDataSource(for: collectionView)
        addTableBottomInset(for: collectionView)
    }
    
    func addAccessibilityIdentifiers(){
        self.collectionView.accessibilityIdentifier = "chatListCollectionView"
    }
    
    func addTableBottomInset(for collectionView: UICollectionView) {
        let windowInsets = getWindowInsets()
        let bottomBarHeight:CGFloat = 64
        
        collectionView.contentInset.bottom = bottomBarHeight + windowInsets.bottom
        collectionView.verticalScrollIndicatorInsets.bottom = bottomBarHeight + windowInsets.bottom
    }
}


// MARK: - Event Handling
private extension ChatsCollectionViewController {
    
    @objc func handleRefreshOnPull(refreshControl: UIRefreshControl) {
        onRefresh?(refreshControl)
    }
}


// MARK: - Navigation
private extension ChatsCollectionViewController {
}



// MARK: - Layout Composition
extension ChatsCollectionViewController {

    func makeSectionHeader() -> NSCollectionLayoutBoundarySupplementaryItem {
        let headerSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .estimated(80)
        )

        return NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
    }


    func makeListSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .fractionalHeight(1)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = itemContentInsets


        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .absolute(Constants.kChatListRowHeight)
        )
        let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])


        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .none

        return section
    }


    func makeSectionProvider() -> UICollectionViewCompositionalLayoutSectionProvider {
        { (sectionIndex, layoutEnvironment) -> NSCollectionLayoutSection? in
            switch CollectionViewSection(rawValue: sectionIndex) {
            case .all:
                return self.makeListSection()
            case nil:
                return nil
            }
        }
    }


    func makeLayout() -> UICollectionViewLayout {
        let layoutConfiguration = UICollectionViewCompositionalLayoutConfiguration()

        let layout = UICollectionViewCompositionalLayout(
            sectionProvider: makeSectionProvider()
        )

        layout.configuration = layoutConfiguration

        return layout
    }
}


// MARK: - Collection View Configuration and View Registration
extension ChatsCollectionViewController {

    func registerViews(for collectionView: UICollectionView) {
        collectionView.register(
            CollectionViewCell.nib,
            forCellWithReuseIdentifier: CollectionViewCell.reuseID
        )
    }


    func configure(_ collectionView: UICollectionView) {
        collectionView.collectionViewLayout = makeLayout()

        collectionView.alwaysBounceVertical = true
        collectionView.showsVerticalScrollIndicator = true
        collectionView.backgroundColor = .Sphinx.DashboardHeader
        
        collectionView.delegate = self
        
        collectionView.refreshControl = UIRefreshControl()
        collectionView.refreshControl!.addTarget(
            self,
            action: #selector(handleRefreshOnPull(refreshControl:)),
            for: .valueChanged
        )
    }
    
    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        onContentScrolled?(scrollView)
    }
}



// MARK: - Data Source Configuration
extension ChatsCollectionViewController {

    func makeDataSource(for collectionView: UICollectionView) -> DataSource {
        
        let dataSource = DataSource(
            collectionView: collectionView,
            cellProvider: makeCellProvider(for: collectionView)
        )

        dataSource.supplementaryViewProvider = makeSupplementaryViewProvider(for: collectionView)

        return dataSource
    }


    func configureDataSource(for collectionView: UICollectionView) {
        updateWorkItem?.cancel()
        updateWorkItem = nil
        applyGate.reset()
        snapshotGeneration += 1

        dataSource = makeDataSource(for: collectionView)
        
        updateSnapshot()
    }
}


// MARK: - Data Source View Providers
extension ChatsCollectionViewController {

    func makeCellProvider(for collectionView: UICollectionView) -> DataSource.CellProvider {
        { [weak self] (collectionView, indexPath, chatItem) -> UICollectionViewCell? in
            guard let self else {
                return nil
            }
            
            let section = CollectionViewSection.allCases[indexPath.section]

            switch section {
            case .all:
                guard let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: CollectionViewCell.reuseID,
                    for: indexPath
                ) as? CollectionViewCell else { return nil }

                cell.owner = self.owner
                cell.chatListObject = self.chatListObjects.first(where: { $0.getObjectId() == chatItem.objectId })
                cell.delegate = self

                return cell
            }
        }
    }


    func makeSupplementaryViewProvider(
        for collectionView: UICollectionView
    ) -> DataSource.SupplementaryViewProvider {
        return { (collectionView: UICollectionView, kind: String, indexPath: IndexPath) -> UICollectionReusableView in
            switch kind {
            case UICollectionView.elementKindSectionHeader:
                return UICollectionReusableView()
            default:
                return UICollectionReusableView()
            }
        }
    }
}


// MARK: - Data Source Snapshot
extension ChatsCollectionViewController {

    func updateSnapshot() {
        updateWorkItem?.cancel()
        updateWorkItem = nil
        applyCurrentSnapshot()
    }

    func applyCurrentSnapshot() {
        if Thread.isMainThread {
            performApplyCurrentSnapshot()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.performApplyCurrentSnapshot()
            }
        }
    }

    private func performApplyCurrentSnapshot() {
        guard dataSource != nil else { return }
        updateOwner()

        guard applyGate.beginApplyIfIdle() else { return }

        // Explicit type: `dataSource` is `DataSource!`, and a plain `let` binding
        // of an IUO infers `DataSource?` (the "implicit" unwrap only applies at
        // the original property's use site, not when copying it into a new
        // binding) — confirmed just-checked non-nil above.
        let applyingDataSource: DataSource = dataSource
        let generation = snapshotGeneration
        let snapshot = makeSnapshotFromCurrentObjects()

        applySnapshotFailClosed(
            snapshot,
            on: applyingDataSource,
            generation: generation
        ) { [weak self] in
            guard let self else { return }
            guard self.snapshotGeneration == generation,
                  self.dataSource === applyingDataSource else {
                return
            }

            if self.applyGate.finishApply() {
                self.applyCurrentSnapshot()
            }
        }
    }

    private func makeSnapshotFromCurrentObjects() -> DataSourceSnapshot {
        var snapshot = DataSourceSnapshot()
        snapshot.appendSections(CollectionViewSection.allCases)

        let items = chatListObjects
            .filter { $0.getContact()?.isOwner != true }
            .map { DataSourceItem(objectId: $0.getObjectId()) }

        snapshot.appendItems(
            DataSourceItem.uniqueByObjectId(items),
            toSection: .all
        )
        return snapshot
    }

    func applySnapshotFailClosed(
        _ snapshot: DataSourceSnapshot,
        on applyingDataSource: DataSource,
        generation: Int,
        completion: @escaping () -> Void
    ) {
        guard snapshotGeneration == generation,
              dataSource === applyingDataSource else {
            completion()
            return
        }

        // Always hop a run-loop turn. `apply(animatingDifferences: false)` may
        // invoke its completion synchronously on iOS 15+, and a same-stack
        // `finishApply` → `apply` re-entry is not supported by UIKit.
        let finishOnMain = {
            DispatchQueue.main.async { completion() }
        }

        let forcedPrimaryExceptionReason = testForcePrimaryApplyExceptionReason
        var exceptionReason: NSString?
        let succeeded = NSExceptionCatcher.tryExecute({
            if let reason = forcedPrimaryExceptionReason {
                NSException(
                    name: .internalInconsistencyException,
                    reason: reason,
                    userInfo: nil
                ).raise()
            }
            applyingDataSource.apply(snapshot, animatingDifferences: false, completion: finishOnMain)
        }, exceptionReason: &exceptionReason)

        if succeeded {
            return
        }

        // Do not re-apply the snapshot that just threw. Rebuild from live data.
        guard snapshotGeneration == generation,
              dataSource === applyingDataSource else {
            captureCollectionViewException(
                reason: exceptionReason as String?,
                fallbackSucceeded: false
            )
            completion()
            return
        }

        let rebuiltSnapshot = makeSnapshotFromCurrentObjects()
        var fallbackReason: NSString?
        let fallbackSucceeded = NSExceptionCatcher.tryExecute({
            applyingDataSource.applySnapshotUsingReloadData(
                rebuiltSnapshot,
                completion: finishOnMain
            )
        }, exceptionReason: &fallbackReason)

        captureCollectionViewException(
            reason: exceptionReason as String?,
            fallbackSucceeded: fallbackSucceeded
        )

        if fallbackSucceeded {
            return
        }

        captureCollectionViewException(
            reason: fallbackReason as String?,
            fallbackSucceeded: false
        )
        completion()
    }

    private func captureCollectionViewException(
        reason: String?,
        fallbackSucceeded: Bool
    ) {
        onCollectionViewExceptionCaptured?(reason, fallbackSucceeded)

        let error = NSError(
            domain: "ChatsCollectionView",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: reason ?? "Unknown collection view exception"]
        )
        SphinxErrorReporter.capture(
            error,
            metadata: [
                "source": "ChatsCollectionView",
                "exceptionReason": reason ?? "",
                "fallbackSucceeded": fallbackSucceeded
            ]
        )
    }
    
    func updateOwner() {
        if owner == nil {
            owner = UserContact.getOwner()
        }
    }
}

/// Serializes overlapping chat-list snapshot applies on the main thread.
/// Later refresh requests replace earlier ones via `needsApply`.
struct ChatListSnapshotApplyGate {
    private(set) var isApplying = false
    private(set) var needsApply = false

    mutating func reset() {
        isApplying = false
        needsApply = false
    }

    /// Returns `true` when the caller should start an apply now.
    mutating func beginApplyIfIdle() -> Bool {
        if isApplying {
            needsApply = true
            return false
        }
        isApplying = true
        needsApply = false
        return true
    }

    /// Marks the in-flight apply finished. Returns `true` if another apply is pending.
    mutating func finishApply() -> Bool {
        guard isApplying else { return false }  // prevent double-release from swallowing queued updates
        isApplying = false
        let shouldReapply = needsApply
        needsApply = false
        return shouldReapply
    }
}


// MARK: - Event Handling
private extension ChatsCollectionViewController {
}


// MARK: - Private Helpers
private extension ChatsCollectionViewController {
}


// MARK: - `UICollectionViewDelegate`
extension ChatsCollectionViewController {
    
    override func collectionView(
        _ collectionView: UICollectionView,
        didSelectItemAt indexPath: IndexPath
    ) {
        collectionView.deselectItem(at: indexPath, animated: true)

        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        guard let selected = chatListObjects.first(where: { $0.getObjectId() == item.objectId }) else { return }
        onChatSelected?(selected)
    }
}


extension ChatsCollectionViewController : ChatListCollectionViewCellDelegate, MessageOptionsVCDelegate{
    func didLongPressOnCell(
        cell: ChatListCollectionViewCell,
        chatListObject: ChatListCommonObject,
        owner: UserContact
    ) {
        if let indexPath = collectionView.indexPath(for: cell) {
            
            if chatListObject.lastMessage?.isOutgoing(ownerId: owner.id) == false || ///last message is outgoing, should show mark as read/unread
                chatListObject.isConversation() ///it's a contact, should show delete contact
            {
                if let rowRectAndPath = ChatHelper.getChatRowRectAndPath(
                    collectionView: collectionView,
                    indexPath: indexPath,
                    yOffset: chatsListDelegate?.shouldGetChatsContainerYOffset() ?? 0
                ) {
                    let messageOptionsVC = MessageOptionsViewController.instantiate(
                        message: nil,
                        chat: chatListObject.getChat(),
                        contact: chatListObject.getContact(),
                        purchaseAcceptMessage: nil,
                        delegate: self,
                        isThreadRow: false
                    )
                    
                    messageOptionsVC.setBubblePath(bubblePath: rowRectAndPath)
                    messageOptionsVC.modalPresentationStyle = .overCurrentContext
                    navigationController?.present(messageOptionsVC, animated: false)
                }
            }
        }
    }
    
    func shouldToggleReadUnread(chat: Chat) {
        guard chat.getConversationContact()?.isAgent != true else { return }
        
        guard let lastMessage = chat.lastMessage else {
            return
        }
        
        guard let previousMsg = TransactionMessage.getMessagePreviousTo(
            messageId: lastMessage.id,
            on: chat
        ) else {
            return
        }
        
        let success = SphinxOnionManager.sharedInstance.setReadLevel(
            index: UInt64(previousMsg.id),
            chat: chat,
            recipContact: chat.getContact()
        )
        
        if success {
            let desiredState = !chat.seen
            
            lastMessage.seen = desiredState
            chat.seen = desiredState
            chat.saveChat()
        } else {
            AlertHelper.showAlert(
                title: "generic.error.title".localized,
                message: "generic.error.message".localized
            )
        }
    }
    
    func shouldDeleteContact(contact: UserContact) {
        let confirmDeletionCallback: (() -> ()) = {
            self.deleteContact(contact: contact)
        }
        
        let isInvite = contact.isInvite()
        
        AlertHelper.showTwoOptionsAlert(
            title: "warning".localized,
            message: (isInvite ? "delete.invite.warning" : "delete.contact.warning").localized,
            confirm: confirmDeletionCallback
        )
    }
    
    func deleteContact(contact: UserContact) {
        let som = SphinxOnionManager.sharedInstance
        
        if let inviteCode = contact.invite?.inviteString, contact.isInvite() {
            if !som.cancelInvite(inviteCode: inviteCode) {
                AlertHelper.showAlert(
                    title: "generic.error.title".localized,
                    message: "generic.error.message".localized
                )
                return
            }
        }
        
        if let publicKey = contact.publicKey, publicKey.isNotEmpty {
            if som.deleteContactOrChatMsgsFor(contact: contact) {
                som.deleteContactFromState(pubkey: publicKey)
            }
        }
                
        CoreDataManager.sharedManager.deleteContactObjectsFor(contact)
    }
    
    func shouldDeleteChat(chat: Chat) {
        CoreDataManager.sharedManager.deleteChatObjectsFor(chat)
    }
    
    func shouldDeleteMessage(message: TransactionMessage) {}
    
    func shouldReplyToMessage(message: TransactionMessage) {}
    
    func shouldBoostMessage(message: TransactionMessage) {}
    
    func shouldResendMessage(message: TransactionMessage) {}
    
    func shouldFlagMessage(message: TransactionMessage) {}
    
    func shouldShowThreadFor(message: TransactionMessage) {}
    
    func shouldTogglePinState(message: TransactionMessage, pin: Bool) {}
    
    func shouldReloadChat() {}

}
