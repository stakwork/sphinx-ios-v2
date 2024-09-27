//
//  AuthExternalView.swift
//  sphinx
//
//  Created by Tomas Timinskas on 26/05/2021.
//  Copyright © 2021 Tomas Timinskas. All rights reserved.
//

import UIKit

class AuthExternalView: CommonModalView {
    
    @IBOutlet weak var hostLabel: UILabel!
    @IBOutlet weak var authorizeButton: UIButton!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    private func setup() {
        Bundle.main.loadNibNamed("AuthExternalView", owner: self, options: nil)
        addSubview(contentView)
        contentView.frame = self.bounds
        contentView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        contentView.layer.cornerRadius = 15
        
        authorizeButton.layer.cornerRadius = authorizeButton.frame.height / 2
        authorizeButton.addShadow(location: .bottom, opacity: 0.3, radius: 5)
    }
    
    override func modalWillShowWith(query: String, delegate: ModalViewDelegate) {
        super.modalWillShowWith(query: query, delegate: delegate)
        
        processQuery()
        
        hostLabel.text = "\(authInfo?.host ?? "...")?"
    }
    
    override func modalDidShow() {
        super.modalDidShow()
    }
    
    @IBAction func authorizeButtonTouched() {
        buttonLoading = true
        verifyExternal()
    }
    
    func verifyExternal() {
        guard let query = self.query else {
            AlertHelper.showAlert(
                title: "Error",
                message: "Could not parse auth request"
            )
            authorizationDone(
                success: false,
                host: self.authInfo?.host ?? ""
            )
            return
        }
        
        SphinxOnionManager.sharedInstance.processPeopleAuthChallenge(
            query: query,
            completion: { authParams in
                if authParams != nil{
                    self.authInfo?.host = authParams!.0
                    self.authInfo?.challenge = authParams!.1
                    self.authInfo?.token = authParams!.2
                    self.authInfo?.verificationSignature = authParams!.3["verification_signature"] as? String
                }
                self.authorizationDone(success: authParams != nil, host: self.authInfo?.host ?? "")
        })
    }
    
    func authorizationDone(success: Bool, host: String) {
        if success {
            if let host = authInfo?.host, let challenge = authInfo?.challenge, let url = URL(string: "https://\(host)?challenge=\(challenge)") {
                UIApplication.shared.open(url)
            }
        } else {
            messageBubbleHelper.showGenericMessageView(text: "authorization.failed".localized, delay: 5, textColor: UIColor.white, backColor: UIColor.Sphinx.BadgeRed, backAlpha: 1.0)
        }
        delegate?.shouldDismissVC()
    }
}
