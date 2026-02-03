import UIKit


class ChatsContainerViewController: UIViewController {
    @IBOutlet weak var chatsListContainerView: UIView!
    
    private var chatsCollectionViewController: ChatsCollectionViewController!
    private weak var chatsListDelegate: DashboardChatsListDelegate?
    
    private(set) var chats: [ChatListCommonObject] = []
    
    public enum Tab: Int {
        case Friends
        case Tribes
    }
}


// MARK: - Instantiation
extension ChatsContainerViewController {
    
    static func instantiate(
        chatsListDelegate: DashboardChatsListDelegate
    ) -> ChatsContainerViewController {
        
        let viewController = StoryboardScene
            .Dashboard
            .chatsContainerViewController
            .instantiate()
        
        viewController.chatsListDelegate = chatsListDelegate
        
        return viewController
    }
    
    
    public func updateWithNewChats(
        _ chats: [ChatListCommonObject]
    ) {
        self.chats = chats
        
        self.chatsCollectionViewController?.chatListObjects = chats
        self.chatsCollectionViewController?.updateSnapshot()
    }
    
    func onMessagesStatusChangedFor(chatIds: [Int]) {
        self.chatsCollectionViewController?.shouldReloadChatRowsFor(chatIds: chatIds)
    }
    
    func shouldReloadRowFor(chatId: Int) {
        chatsCollectionViewController?.shouldReloadRowFor(chatId: chatId)
    }
}


// MARK: - Lifecycle
extension ChatsContainerViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.accessibilityIdentifier = "ChatsContainerViewController"
        configureContactChatsCollectionView()
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
}


// MARK: - Event Handling
private extension ChatsContainerViewController {
    
    func handleChatSelection(_ chatListObject: ChatListCommonObject) {
        if let chat = chatListObject as? Chat {
            chatsListDelegate?.viewController(self, didSelectChat: chat, orContact: nil)
        } else if let contact = chatListObject as? UserContact {
            chatsListDelegate?.viewController(self, didSelectChat: nil, orContact: contact)
        }
    }
    
    func handleChatsListRefresh(refreshControl: UIRefreshControl) {
        chatsListDelegate?.viewControllerDidRefreshChats(self, using: refreshControl)
    }
    
    func handleChatsScroll(scrollView: UIScrollView) {
        chatsListDelegate?.viewControllerContentScrolled(scrollView: scrollView)
    }
}


// MARK: - Private Helpers
extension ChatsContainerViewController {
    
    private func configureContactChatsCollectionView() {
        chatsCollectionViewController = ChatsCollectionViewController
            .instantiate(
                chatListObjects: chats,
                chatsListDelegate: chatsListDelegate,
                onChatSelected: handleChatSelection(_:),
                onContentScrolled: handleChatsScroll(scrollView:),
                onRefresh: handleChatsListRefresh(refreshControl:)
            )

        addChildVC(
            child: chatsCollectionViewController,
            container: chatsListContainerView
        )

        // Note: updateSnapshot() is already called in ChatsCollectionViewController.configureDataSource()
        // during viewDidLoad(), so we don't need to call it again here
    }
    
    func reloadCollectionView() {
        chatsCollectionViewController?.loadChatsList()
    }
}

