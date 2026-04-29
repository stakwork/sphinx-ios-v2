//
//  MessageOptionsViewController.swift
//  sphinx
//
//  Created by Tomas Timinskas on 10/04/2020.
//  Copyright © 2020 Sphinx. All rights reserved.
//

import UIKit

@MainActor @objc protocol MessageOptionsVCDelegate: class {
    func shouldDeleteMessage(message: TransactionMessage)
    func shouldReplyToMessage(message: TransactionMessage)
    func shouldBoostMessage(message: TransactionMessage)
    func shouldResendMessage(message: TransactionMessage)
    func shouldFlagMessage(message: TransactionMessage)
    func shouldShowThreadFor(message:TransactionMessage)
    func shouldTogglePinState(message: TransactionMessage, pin: Bool)
    func shouldReloadChat()
    func shouldToggleReadUnread(chat: Chat)
    func shouldDeleteContact(contact: UserContact)
    func shouldDeleteChat(chat: Chat)
}

class MessageOptionsViewController: UIViewController {
    
    weak var delegate: MessageOptionsVCDelegate?
    
    var bubbleShapeLayers: [(CGRect, CAShapeLayer)] = [(CGRect, CAShapeLayer)]()
    var bubblePath: (CGRect, CGPath)? = nil
    
    var message: TransactionMessage? = nil
    var chat: Chat? = nil
    var contact: UserContact? = nil
    
    var purchaseAcceptMessage: TransactionMessage? = nil
    
    var isThreadRow: Bool = false
    
    // Rebuild context for live tracking
    var rebuildIndexPath: IndexPath? = nil
    var rebuildBubbleViewRect: CGRect? = nil
    weak var rebuildTableView: UITableView? = nil
    weak var rebuildContentView: UIView? = nil
    
    // Live-tracking state — updated in-place every display frame
    private var displayLink: CADisplayLink?
    private var blurMaskShapeLayer: CAShapeLayer?
    private var currentMenuView: MessageOptionsView?
    private var lastBubbleRect: CGRect = .zero
    
    static func instantiate(
        message: TransactionMessage?,
        chat: Chat?,
        contact: UserContact?,
        purchaseAcceptMessage: TransactionMessage?,
        delegate: MessageOptionsVCDelegate?,
        isThreadRow: Bool
    ) -> MessageOptionsViewController {
        
        let viewController = StoryboardScene.Chat.messageOptionsViewController.instantiate()
        viewController.message = message
        viewController.chat = chat
        viewController.contact = contact
        viewController.purchaseAcceptMessage = purchaseAcceptMessage
        viewController.delegate = delegate
        viewController.isThreadRow = isThreadRow
        
        return viewController
    }
    
    func setBubbleShapesData(bubbleShapeLayers: [(CGRect, CAShapeLayer)]) {
        self.bubbleShapeLayers = bubbleShapeLayers
    }
    
    func setBubblePath(bubblePath: (CGRect, CGPath)) {
        self.bubblePath = bubblePath
    }
    
    func setRebuildContext(
        indexPath: IndexPath,
        bubbleViewRect: CGRect,
        tableView: UITableView,
        contentView: UIView
    ) {
        self.rebuildIndexPath = indexPath
        self.rebuildBubbleViewRect = bubbleViewRect
        self.rebuildTableView = tableView
        self.rebuildContentView = contentView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        SoundsPlayer.playHaptic()
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(viewTapped))
        self.view.addGestureRecognizer(tap)
        
        highlightMessage()
        startDisplayLink()
    }
    
    // MARK: - CADisplayLink live tracking
    
    private func startDisplayLink() {
        guard rebuildTableView != nil, rebuildIndexPath != nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(displayLinkFired))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }
    
    @objc private func displayLinkFired() {
        guard
            let tableView = rebuildTableView,
            let contentView = rebuildContentView,
            let indexPath = rebuildIndexPath,
            let storedBubbleViewRect = rebuildBubbleViewRect
        else { return }
        
        // Always read the live bubble frame from the actual cell so size changes
        // (e.g. a boost row being added) are reflected immediately.
        let liveBubbleViewRect: CGRect
        if let cell = tableView.cellForRow(at: indexPath) as? CommonNewMessageTableViewCell,
           let liveFrame = cell.getBubbleView()?.frame {
            liveBubbleViewRect = liveFrame
        } else {
            liveBubbleViewRect = storedBubbleViewRect
        }
        
        guard let (newRect, newPath) = ChatHelper.getMessageBubbleRectAndPath(
            tableView: tableView,
            indexPath: indexPath,
            contentView: contentView,
            bubbleViewRect: liveBubbleViewRect
        ) else {
            shouldDismissViewController()
            return
        }
        
        guard newRect != lastBubbleRect else { return }
        lastBubbleRect = newRect
        
        updateBlurMask(bubbleRect: newRect, bubbleCGPath: newPath)
        updateMenuPosition(bubbleRect: newRect)
    }
    
    private func updateBlurMask(bubbleRect: CGRect, bubbleCGPath: CGPath) {
        guard let maskLayer = blurMaskShapeLayer else { return }
        
        let windowSize = WindowsManager.getWindowSize()
        let fullPath = UIBezierPath(rect: CGRect(x: 0, y: 0, width: windowSize.width, height: windowSize.height))
        
        let holePath = UIBezierPath(cgPath: bubbleCGPath)
        holePath.apply(CGAffineTransform(translationX: bubbleRect.origin.x, y: bubbleRect.origin.y))
        fullPath.append(holePath)
        fullPath.usesEvenOddFillRule = true
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        maskLayer.path = fullPath.cgPath
        CATransaction.commit()
    }
    
    private func updateMenuPosition(bubbleRect: CGRect) {
        guard let menuView = currentMenuView else { return }
        let leftTopCorner = CGPoint(x: bubbleRect.origin.x, y: bubbleRect.origin.y)
        let rightBottomCorner = CGPoint(
            x: bubbleRect.origin.x + bubbleRect.width,
            y: bubbleRect.origin.y + bubbleRect.height
        )
        menuView.updatePosition(
            leftTopCorner: leftTopCorner,
            rightBottomCorner: rightBottomCorner,
            incoming: message?.isIncoming() ?? true
        )
    }
    
    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopDisplayLink()
    }
    
    // MARK: - Initial render
    
    func highlightMessage() {
        let windowSize = WindowsManager.getWindowSize()
        let entireView = UIView(frame: CGRect(x: 0, y: 0, width: windowSize.width, height: windowSize.height))
        let entireViewPath = UIBezierPath(rect: entireView.frame)

        var leftTopCorner = CGPoint(x: 0, y: 0)
        var rightBottomCorner = CGPoint(x: 0, y: 0)
        
        func saveRectPosition(bubbleRect: CGRect) {
            leftTopCorner.x = (leftTopCorner.x == 0) ? bubbleRect.origin.x : min(leftTopCorner.x, bubbleRect.origin.x)
            
            leftTopCorner.y = (leftTopCorner.y == 0) ? bubbleRect.origin.y : min(leftTopCorner.y, bubbleRect.origin.y)
            
            let newX2 = bubbleRect.origin.x + bubbleRect.size.width
            rightBottomCorner.x = (rightBottomCorner.x == 0) ? newX2 : max(rightBottomCorner.x, newX2)
            
            let newY2 = bubbleRect.origin.y + bubbleRect.size.height
            rightBottomCorner.y = (rightBottomCorner.y == 0) ? newY2 : max(rightBottomCorner.y, newY2)
        }
        
        if let bubblePath = bubblePath {
            let rectangleMessageRect = CGRect(x: bubblePath.0.origin.x,
                                              y: bubblePath.0.origin.y,
                                              width: bubblePath.0.width,
                                              height: bubblePath.0.height)
            
            saveRectPosition(bubbleRect: rectangleMessageRect)
            lastBubbleRect = rectangleMessageRect
            
            let messageViewPath = UIBezierPath(cgPath: bubblePath.1)
            messageViewPath.apply(CGAffineTransform(translationX: rectangleMessageRect.origin.x, y: rectangleMessageRect.origin.y))
            
            entireViewPath.append(messageViewPath)
        } else {
            for (rect, layer) in bubbleShapeLayers {
                let messageShapeLayer = layer
                let containerFrame = rect
                
                if let path = messageShapeLayer.path {
                    let rectangleMessageRect = CGRect(x: messageShapeLayer.frame.origin.x + containerFrame.origin.x,
                                                      y: messageShapeLayer.frame.origin.y + containerFrame.origin.y,
                                                      width: messageShapeLayer.frame.width,
                                                      height: messageShapeLayer.frame.height)
                    
                    saveRectPosition(bubbleRect: rectangleMessageRect)
                    
                    let messageViewPath = UIBezierPath(cgPath: path)
                    messageViewPath.apply(CGAffineTransform(translationX: rectangleMessageRect.origin.x, y: rectangleMessageRect.origin.y))
                    
                    entireViewPath.append(messageViewPath)
                }
            }
        }
        
        entireViewPath.usesEvenOddFillRule = true
        
        let entireViewLayer = CAShapeLayer()
        entireViewLayer.path = entireViewPath.cgPath
        entireViewLayer.fillRule = .evenOdd
        entireViewLayer.fillColor = UIColor.black.resolvedCGColor(with: self.view)
        entireView.layer.addSublayer(entireViewLayer)
        blurMaskShapeLayer = entireViewLayer
        
        let blurEffect = UIBlurEffect(style: UIBlurEffect.Style.dark)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.frame = view.bounds
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        blurEffectView.mask = entireView
        view.addSubview(blurEffectView)
        
        currentMenuView = addMenuView(leftTopCorner: leftTopCorner, rightBottomCorner: rightBottomCorner)
    }
    
    func addMessageBubbleBorder(messageViewPath: UIBezierPath) {
        let windowSize = WindowsManager.getWindowSize()
        let messagesView = UIView(frame: CGRect(x: 0, y: 0, width: windowSize.width, height: windowSize.height))
        let messageLayer = CAShapeLayer()
        messageLayer.path = messageViewPath.cgPath
        messageLayer.fillRule = .evenOdd
        messageLayer.fillColor = UIColor.clear.resolvedCGColor(with: self.view)
        messageLayer.strokeColor = UIColor.Sphinx.MessageOptionDivider.resolvedCGColor(with: self.view)
        messagesView.layer.addSublayer(messageLayer)
        view.addSubview(messagesView)
    }
    
    @discardableResult
    func addMenuView(
        leftTopCorner: CGPoint,
        rightBottomCorner: CGPoint
    ) -> MessageOptionsView {
        let menuView = MessageOptionsView(
            message: message,
            chat: chat,
            contact: contact,
            leftTopCorner: leftTopCorner,
            rightBottomCorner: rightBottomCorner,
            isThreadRow: isThreadRow,
            delegate: self
        )
        self.view.addSubview(menuView)
        return menuView
    }
    
    func addMessageShadow(layer: CALayer) {
        layer.shadowColor = UIColor.white.resolvedCGColor(with: self.view)
        layer.shadowOffset = CGSize(width: 1.0, height: 1.0)
        layer.shadowOpacity = 1.0
        layer.shadowRadius = 3.0
        layer.shouldRasterize = true
        layer.rasterizationScale = UIScreen.main.scale
    }

    @objc func viewTapped() {
        shouldDismissViewController()
    }
    
    func shouldDismissViewController(_ completion: (() -> ())? = nil) {
        SoundsPlayer.playHaptic()
        
        self.dismiss(animated: false, completion: {
            self.delegate?.shouldReloadChat()
            
            completion?()
        })
    }
}

extension MessageOptionsViewController : MessageOptionsDelegate {
    func shouldDismiss(completion: @escaping (() -> ())) {
        shouldDismissViewController(completion)
    }
    
    func shouldReplyToMessage() {
        if let message = message {
            delegate?.shouldReplyToMessage(message: message)
        }
    }
    
    func shouldDeleteMessage() {
        if let message = message {
            delegate?.shouldDeleteMessage(message: message)
        }
    }
    
    func shouldBoostMessage() {
        if let message = message {
            delegate?.shouldBoostMessage(message: message)
        }
    }
    
    func shouldSaveFile() {
        MediaDownloader.shouldSaveFile(
            message: message,
            purchaseAcceptMessage: purchaseAcceptMessage,
            completion: { success, alertMessage in
                self.showMediaSaveAlert(
                    success: success,
                    
                    alertMessage: alertMessage)
            }
        )
    }
    
    func shouldResendMessage() {
        if let message = message {
            delegate?.shouldResendMessage(message: message)
        }
    }
    
    func shouldFlagMessage() {
        if let message = message {
            delegate?.shouldFlagMessage(message: message)
        }
    }
    
    func shouldTogglePinState(pin: Bool) {
        if let message = message {
            delegate?.shouldTogglePinState(message: message, pin: pin)
        }
    }
    
    func showMediaSaveAlert(success: Bool, alertMessage: String) {
        DispatchQueue.main.async {
            NewMessageBubbleHelper().showGenericMessageView(text: alertMessage)
        }
    }
    
    func shouldShowThread() {
        if let message = message {
            delegate?.shouldShowThreadFor(message: message)
        }
    }
    
    //Unused Methods
    func shouldToggleReadUnread(chat: Chat) {
        delegate?.shouldToggleReadUnread(chat: chat)
    }
    
    func shouldDeleteContact(contact: UserContact) {
        delegate?.shouldDeleteContact(contact: contact)
    }
    
    func shouldDeleteChat(chat: Chat) {
        delegate?.shouldDeleteChat(chat: chat)
    }
    
}
