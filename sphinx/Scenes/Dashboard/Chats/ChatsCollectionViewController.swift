import UIKit


class ChatsCollectionViewController: UICollectionViewController {
    
    var chatListObjects: [ChatListCommonObject] = []
    var onChatSelected: ((ChatListCommonObject) -> Void)?
    var onContentScrolled: ((UIScrollView) -> Void)?
    var onRefresh: ((UIRefreshControl) -> Void)?
    
    private weak var chatsListDelegate: DashboardChatsListDelegate?

    private var currentDataSnapshot: DataSourceSnapshot!
    private var dataSource: DataSource!
    
    private var owner: UserContact!
    
    let dataSourceQueue = DispatchQueue(label: "chatList.datasourceQueue", attributes: .concurrent)
    
    private let itemContentInsets = NSDirectionalEdgeInsets(
        top: 0,
        leading: 0,
        bottom: 0,
        trailing: 0
    )
    
    func shouldReloadRowFor(chatId: Int) {
        if let index = chatListObjects.firstIndex(where: { chatId == $0.getChat()?.id }) {
            var snapshot = self.dataSource.snapshot()
            let itemIdentifier = snapshot.itemIdentifiers[index]
            
            self.dataSourceQueue.sync {
                snapshot.reloadItems([itemIdentifier])
                DispatchQueue.main.async {
                    self.dataSource.apply(snapshot, animatingDifferences: true)
                }
            }
        }
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
        var messageId: Int?
        var messageStatus: Int?
        var message30SecOld: Bool
        var messageSeen: Bool
        var unseenCount: Int
        var contactStatus: Int?
        var inviteStatus: Int?
        var muted: Bool

        init(
            objectId: String,
            messageId: Int?,
            messageStatus: Int?,
            message30SecOld: Bool,
            messageSeen: Bool,
            unseenCount: Int,
            contactStatus: Int?,
            inviteStatus: Int?,
            muted: Bool
        )
        {
            self.objectId = objectId
            self.messageId = messageId
            self.messageStatus = messageStatus
            self.message30SecOld = message30SecOld
            self.messageSeen = messageSeen
            self.unseenCount = unseenCount
            self.contactStatus = contactStatus
            self.inviteStatus = inviteStatus
            self.muted = muted
        }
        
        static func == (lhs: DataSourceItem, rhs: DataSourceItem) -> Bool {
            let isEqual =
                lhs.objectId == rhs.objectId &&
                lhs.messageId == rhs.messageId &&
                lhs.messageStatus == rhs.messageStatus &&
                lhs.message30SecOld == rhs.message30SecOld &&
                lhs.messageSeen == rhs.messageSeen &&
                lhs.unseenCount == rhs.unseenCount &&
                lhs.contactStatus == rhs.contactStatus &&
                lhs.inviteStatus == rhs.inviteStatus &&
                lhs.muted == rhs.muted
            
            return isEqual
         }

        func hash(into hasher: inout Hasher) {
            hasher.combine(objectId)
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
                cell.chatListObject = self.chatListObjects[indexPath.row]
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
        updateOwner()
        
        var snapshot = DataSourceSnapshot()
        
        snapshot.appendSections(CollectionViewSection.allCases)
        
        let items = self.chatListObjects.filter({ $0.getContact()?.isOwner != true }).map {
            DataSourceItem(
                objectId: $0.getObjectId(),
                messageId: $0.lastMessage?.id,
                messageStatus: $0.lastMessage?.status,
                message30SecOld: ($0.lastMessage?.date ?? Date()) < Date().addingTimeInterval(-30),
                messageSeen: $0.isSeen(ownerId: self.owner.id),
                unseenCount: $0.getUnseenMessagesCount(ownerId: self.owner.id),
                contactStatus: $0.getContactStatus(),
                inviteStatus: $0.getInviteStatus(),
                muted: $0.isMuted()
            )
        }
        
        dataSourceQueue.sync {
            snapshot.appendItems(items, toSection: .all)
            self.dataSource.apply(snapshot, animatingDifferences: true)
        }
    }
    
    func updateOwner() {
        if owner == nil {
            owner = UserContact.getOwner()
        }
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
        
        let selectedChatObject = chatListObjects[indexPath.row]
        onChatSelected?(selectedChatObject)
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
