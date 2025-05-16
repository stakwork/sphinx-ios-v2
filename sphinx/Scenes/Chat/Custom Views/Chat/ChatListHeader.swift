//
//  ChatListHeader.swift
//  sphinx
//
//  Created by Tomas Timinskas on 16/07/2020.
//  Copyright © 2020 Sphinx. All rights reserved.
//

import UIKit
import CocoaMQTT

protocol ChatListHeaderDelegate: class {
    func leftMenuButtonTouched()
}

class ChatListHeader: UIView {
    
    weak var delegate: ChatListHeaderDelegate?{
        didSet{
            print("set")
        }
    }
    
    @IBOutlet var contentView: UIView!
    
    @IBOutlet weak var smallBalanceLabel: UILabel!
    @IBOutlet weak var smallUnitLabel: UILabel!
    @IBOutlet weak var healthCheckButton: UIButton!
    @IBOutlet weak var mqttCheckButton: UIButton!
    @IBOutlet weak var upgradeAppButton: UIButton!
    
    @IBOutlet weak var loadingWheel: UIActivityIndicatorView!
    
    let walletBalanceService = WalletBalanceService()
    let messageBubbleHelper = NewMessageBubbleHelper()
    
    public static let kConnectedColor = UIColor.Sphinx.PrimaryGreen
    public static let kNotConnectedColor = UIColor.Sphinx.SphinxOrange

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }

    private func setup() {
        Bundle.main.loadNibNamed("ChatListHeader", owner: self, options: nil)
        addSubview(contentView)
        contentView.frame = self.bounds
        contentView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        
        upgradeAppButton.layer.cornerRadius = upgradeAppButton.frame.size.height / 2
        
        let balanceTap = UITapGestureRecognizer(target: self, action: #selector(self.balanceLabelTapped(gesture:)))
        self.smallBalanceLabel.addGestureRecognizer(balanceTap)
    }
    
    func listenForEvents() {
        NotificationCenter.default.addObserver(forName: .onBalanceDidChange, object: nil, queue: OperationQueue.main) { (n: Notification) in
            self.updateBalance()
        }
        
        NotificationCenter.default.addObserver(forName: .onConnectionStatusChanged, object: nil, queue: OperationQueue.main) { (n: Notification) in
            self.updateConnectionSign()
        }
        
        NotificationCenter.default.addObserver(forName: .onMQTTConnectionStatusChanged, object: nil, queue: OperationQueue.main) { (n: Notification) in
            self.updateSigningStatusSign()
        }
    }
    
    func shouldCheckAppVersions() {
        API.sharedInstance.getAppVersions(callback: { [weak self] v in
            let version = Int(v) ?? 0
            let appVersion = Int(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0") ?? 0
            self?.upgradeAppButton.isHidden = version <= appVersion
        })
    }
    
    func updateConnectionSign() {
        let connected = SphinxOnionManager.sharedInstance.isConnected
        healthCheckButton.setTitleColor(connected ? ChatListHeader.kConnectedColor : ChatListHeader.kNotConnectedColor, for: .normal)
    }
    
    func updateSigningStatusSign(){
        if let mqtt = CrypterManager.sharedInstance.mqtt{
            let status = mqtt.connState
            let connected = status == CocoaMQTTConnState.connected
            mqttCheckButton.setTitleColor(connected ? ChatListHeader.kConnectedColor : ChatListHeader.kNotConnectedColor, for: .normal)
        }
        else{
            mqttCheckButton.setTitleColor(ChatListHeader.kNotConnectedColor, for: .normal)
        }
        
    }
    
    func showBalance() {
        smallUnitLabel.text = "chat-header.balance.unit".localized
        
        let hideBalances = UserDefaults.Keys.hideBalances.get(defaultValue: false)
        
        if (hideBalances) {
            smallBalanceLabel.text = "＊＊＊＊"
        } else {
            walletBalanceService.updateBalance(labels: [smallBalanceLabel])
        }
        
//        shouldCheckAppVersions()
    }
    
    func updateBalance() {
        smallUnitLabel.text = "chat-header.balance.unit".localized
        walletBalanceService.updateBalance(labels: [smallBalanceLabel])
    }
    
    func takeUserToSupport() {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.goToSupport()
    }
    
    @IBAction func signStatusCheckButtonTouched(){
        var message = "signer.not.connected".localized
        if let mqtt = CrypterManager.sharedInstance.mqtt{
            let status = mqtt.connState
            let connected = status == CocoaMQTTConnState.connected
            mqttCheckButton.setTitleColor(connected ? ChatListHeader.kConnectedColor : ChatListHeader.kNotConnectedColor, for: .normal)
            switch(status) {
            case .connected:
                message = "signer.connected".localized
                break
            case .connecting:
                message = "signer.connecting".localized
                break
            case .disconnected:
                message = "signer.not.connected".localized
                break
            default:
                message = "signer.not.connected".localized
                break
            }
        }
        DelayPerformedHelper.performAfterDelay(seconds: 0.5, completion: {
            self.messageBubbleHelper.showGenericMessageView(text:message, delay: 3)
        })
    }
    
    @IBAction func healthCheckButtonTouched() {
//        let status = API.sharedInstance.connectionStatus
//        let socketConnected = SphinxSocketManager.sharedInstance.isConnected()
    }
    
    @IBAction func upgradeAppButtonTouched() {
        let urlStr = "https://testflight.apple.com/join/QoaCkJn6"
        UIApplication.shared.open(URL(string: urlStr)!, options: [:], completionHandler: nil)
    }
    
    @IBAction func leftMenuButtonTouched() {
        delegate?.leftMenuButtonTouched()
    }
    
    @objc private func balanceLabelTapped(gesture: UIGestureRecognizer) {
        let hideBalances = UserDefaults.Keys.hideBalances.get(defaultValue: false)
        UserDefaults.Keys.hideBalances.set(!hideBalances)
        updateBalance()
    }
    
}
