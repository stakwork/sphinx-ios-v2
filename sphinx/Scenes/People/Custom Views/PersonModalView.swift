//
//  PersonModalView.swift
//  sphinx
//
//  Created by Tomas Timinskas on 26/05/2021.
//  Copyright © 2021 Tomas Timinskas. All rights reserved.
//

import UIKit
import SwiftyJSON
import CoreData

class PersonModalView: CommonModalView {

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var nicknameLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var connectButton: UIButton!
    @IBOutlet weak var loadingWheel: UIActivityIndicatorView!
    
    var loading = false {
        didSet {
            LoadingWheelHelper.toggleLoadingWheel(loading: loading, loadingWheel: loadingWheel, loadingWheelColor: UIColor.Sphinx.Text, view: nil)
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    private func setup() {
        Bundle.main.loadNibNamed("PersonModalView", owner: self, options: nil)
        addSubview(contentView)
        contentView.frame = self.bounds
        contentView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        contentView.layer.cornerRadius = 15
        
        imageView.layer.cornerRadius = imageView.frame.height / 2
        
        connectButton.layer.cornerRadius = connectButton.frame.height / 2
        connectButton.addShadow(location: .bottom, opacity: 0.3, radius: 5)
    }
    
    override func modalWillShowWith(query: String, delegate: ModalViewDelegate) {
        super.modalWillShowWith(query: query, delegate: delegate)
        
        loading = true
        
        processQuery()
        let existingUser = getPersonInfo()
        
        if existingUser {
            self.delegate?.shouldDismissVC()
            return
        }
    }
    
    func getPersonInfo() -> Bool {
        if let host = authInfo?.host, let pubkey = authInfo?.pubkey {
            if let _ = UserContact.getContactWith(pubkey: pubkey) {
                showMessage(message: "already.connected".localized, color: UIColor.Sphinx.PrimaryRed)
                return true
            }
            API.sharedInstance.getPersonInfo(host: host, pubkey: pubkey, callback: { success, person in
                if let person = person {
                    self.showPersonInfo(person: person)
                } else {
                    self.delegate?.shouldDismissVC()
                }
            })
        }
        return false
    }
    
    func showPersonInfo(person: JSON) {
        authInfo?.jsonBody = person
        
        if !(authInfo?.jsonBody["owner_route_hint"].string ?? "").isRouteHint {
            showMessage(message: "invalid.public-key".localized, color: UIColor.Sphinx.PrimaryRed)
            delegate?.shouldDismissVC()
            return
        }
        
        if let imageUrl = person["img"].string, let nsUrl = URL(string: imageUrl), imageUrl != "" {
            MediaLoader.asyncLoadImage(imageView: imageView, nsUrl: nsUrl, placeHolderImage: UIImage(named: "profile_avatar"))
        } else {
            imageView.image = UIImage(named: "profile_avatar")
        }
        
        nicknameLabel.text = person["owner_alias"].string ?? "Unknown"
        priceLabel.text = "\("price.to.meet".localized)\((person["price_to_meet"].int ?? 0)) sat"
        
        loading = false
    }
    
    override func modalDidShow() {
        super.modalDidShow()
    }
    
    @IBAction func connectButtonTouched() {
        buttonLoading = true
        
        if let _ = authInfo?.pubkey {
            let nickname = authInfo?.jsonBody["owner_alias"].string ?? "Unknown"
            let pubkey = authInfo?.jsonBody["owner_pubkey"].string ?? ""
            let routeHint = authInfo?.jsonBody["owner_route_hint"].string ?? ""
            
            UserContactsHelper.createV2Contact(
                nickname: nickname,
                pubKey: pubkey,
                routeHint: routeHint,
                callback: { (success, _) in
                    self.loading = false
                
                    if success {
                        self.delegate?.shouldDismissVC()
                    } else {
                        self.showErrorMessage()
                    }
                }
            )
        }
    }
    
    func showErrorMessage() {
        showMessage(message: "generic.error.message".localized, color: UIColor.Sphinx.BadgeRed)
    }
    
    func showMessage(message: String, color: UIColor) {
        buttonLoading = false
        messageBubbleHelper.showGenericMessageView(text: message, delay: 3, textColor: UIColor.white, backColor: color, backAlpha: 1.0)
    }
}

extension PersonModalView : UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.endEditing(true)
    }
}
