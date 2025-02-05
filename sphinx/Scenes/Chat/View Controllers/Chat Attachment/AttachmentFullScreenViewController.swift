//
//  ImageFullScrennViewController.swift
//  sphinx
//
//  Created by Tomas Timinskas on 31/01/2020.
//  Copyright © 2020 Sphinx. All rights reserved.
//

import UIKit
import PDFKit
import MobileCoreServices

protocol CanRotate {}

class AttachmentFullScreenViewController: UIViewController, CanRotate {
    
    @IBOutlet weak var fullScreenImageView: FullScreenImageView!
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var pdfHeaderView: UIView!
    @IBOutlet weak var shareButton: UIButton!
    @IBOutlet weak var fileNameLabel: UILabel!
    
    var message: TransactionMessage? = nil
    var purchaseAcceptMessage: TransactionMessage?
    
    var pdfDocument: PDFDocument? = nil
    var imageUrl: URL? = nil
    
    var animated = true
    
    static func instantiate(
        messageId: Int? = nil,
        animated: Bool = true,
        imageUrl: URL? = nil
    ) -> AttachmentFullScreenViewController? {
        
        let viewController = StoryboardScene.Chat.attachmentFullScreenViewController.instantiate()
        
        if let messageId = messageId, let message = TransactionMessage.getMessageWith(id: messageId) {
            viewController.message = message
            viewController.purchaseAcceptMessage = message.getPurchaseAcceptItem()
        }
        
        viewController.animated = animated
        viewController.imageUrl = imageUrl
        
        return viewController
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let message = message, message.isPDF(){
            showPDF()
        } else if let _ = imageUrl{
            showWebViewImage()
        } else {
            showImage()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        AppDelegate.orientationLock = .all
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        AppDelegate.orientationLock = .portrait
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .all
    }
    
    override var shouldAutorotate: Bool {
        return true
    }
    
    func showWebViewImage() {
        guard let imageUrl = imageUrl else{
            return
        }
        fullScreenImageView.isHidden = false
        pdfHeaderView.isHidden = true
        
        self.view.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        fullScreenImageView.configureImageScrollView()
        fullScreenImageView.showWebViewImage(url: imageUrl)
        
        let tap = TouchUpGestureRecognizer(target: self, action: #selector(self.handleTap(_:)))
        self.view.addGestureRecognizer(tap)
    }
    
    func showImage() {
        guard let message = message else{
            return
        }
        fullScreenImageView.isHidden = false
        pdfHeaderView.isHidden = true
        
        self.view.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        fullScreenImageView.configureImageScrollView()
        fullScreenImageView.showImage(message: message)
        
        let tap = TouchUpGestureRecognizer(target: self, action: #selector(self.handleTap(_:)))
        self.view.addGestureRecognizer(tap)
    }
    
    func showPDF() {
        guard let message = message else{
            return
        }
        
        fullScreenImageView.isHidden = true
        pdfHeaderView.isHidden = false
        
        if let url = purchaseAcceptMessage?.getMediaUrlFromMediaToken() ?? message.getMediaUrlFromMediaToken() {
            
            let pdfView = PDFView(frame: getPDFViewFrame())
            pdfView.autoScales = true
            self.view.addSubview(pdfView)
            self.view.sendSubviewToBack(pdfView)
            
            MediaLoader.loadFileData(
                url: url,
                message: message,
                mediaKey: purchaseAcceptMessage?.mediaKey ?? message.mediaKey,
                completion: { (_, data) in
                    self.fileNameLabel.text = message.mediaFileName ?? "file.pdf"
                    self.pdfDocument = PDFDocument(data: data)
                    pdfView.document = self.pdfDocument
                },
                errorCompletion: { _ in }
            )
        }
    }
    
    func getPDFViewFrame() -> CGRect {
        let screenSize = UIScreen.main.bounds
        let headerHeight = pdfHeaderView.frame.height + getWindowInsets().top
        return CGRect(x: 0, y: headerHeight, width: screenSize.width, height: screenSize.height - headerHeight)
    }
    
    func deleteLocalPDF() {
        guard let message = message else{
            return
        }
        
        if let _ = pdfDocument, let url = URL(string: message.mediaFileName ?? "file.pdf") {
            do {
                try FileManager.default.removeItem(at: url)
            } catch let error {
                print(error)
            }
        }
    }
    
    @objc func handleTap(_ sender: TouchUpGestureRecognizer? = nil) {
        backButtonTouched()
    }
    
    @IBAction func shareButtonTouched() {
        guard let message = message else{
            return
        }
        if let pdfData = pdfDocument?.dataRepresentation(),
            let pdfUrl = MediaLoader.saveFileInMemory(
                data: pdfData,
                name: message.mediaFileName ?? "file.pdf"
            ) {
                let activityVC = UIActivityViewController(activityItems: [pdfUrl], applicationActivities: nil)
                activityVC.popoverPresentationController?.sourceView = self.shareButton
                self.present(activityVC, animated: true, completion: nil)
            }
    }
    
    @IBAction func backButtonTouched() {
        deleteLocalPDF()
        
        if !UIDevice.current.isIpad {
            UIDevice.current.setValue(Int(UIInterfaceOrientation.portrait.rawValue), forKey: "orientation")
            AppDelegate.orientationLock = .portrait
        }
        
        self.dismiss(animated: animated, completion: {
            WindowsManager.sharedInstance.removeCoveringWindow()
        })
    }
}
