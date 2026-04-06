//
//  VideoCallManager.swift
//  sphinx
//
//  Created by Tomas Timinskas on 09/04/2020.
//  Copyright © 2020 Sphinx. All rights reserved.
//

import Foundation
import JitsiMeetSDK
import AVKit

@MainActor class VideoCallManager : NSObject {

    nonisolated(unsafe) class var sharedInstance : VideoCallManager {
        struct Static {
            nonisolated(unsafe) static let instance = VideoCallManager()
        }
        return Static.instance
    }

    nonisolated override init() {
        super.init()
    }

    var pipViewCoordinator: CustomPipViewCoordinator?
    var jitsiMeetView: JitsiMeetView?
    var videoCallPayButton: VideoCallPayButton?
    var liveKitVC: LiveKitCallViewController?

    /// Prevents re-entrant calls when syncing roomCtx.isInPip
    private var isTogglingPip = false
    private var isStartingCall = false

    var chat: Chat? = nil
    var videoCallDelegate: VideoCallDelegate? = nil

    var onPiP = false
    var activeCall = false

    func configure(chat: Chat? = nil, videoCallDelegate: VideoCallDelegate) {
        self.chat = chat
        self.videoCallDelegate = videoCallDelegate
    }

    func isGroupChat() -> Bool {
        let isGroup = (chat?.isGroup() ?? false)
        return isGroup
    }
    
    private func teardownLiveKitVC() {
        liveKitVC?.willMove(toParent: nil)
        liveKitVC?.view.removeFromSuperview()
        liveKitVC?.removeFromParent()
        liveKitVC = nil
    }

    func closePipController() {
        guard let coordinator = pipViewCoordinator else {
            // pipViewCoordinator already gone — ensure liveKitVC is still removed
            onPiP = false
            activeCall = false
            teardownLiveKitVC()
            return
        }
        coordinator.hide() { _ in
            self.onPiP = false
            self.activeCall = false
            self.pipViewCoordinator = nil
            self.teardownLiveKitVC()
        }
    }

    /// Removes any stale LiveKit view that survived without an active call coordinator.
    /// Call this on foreground re-entry as a safety net.
    func cleanUpIfStale() {
        guard liveKitVC != nil, !activeCall else { return }
        cleanUp()
    }
    
    func togglePip(pipEnabled: Bool) {
        guard !isTogglingPip else { return }
        isTogglingPip = true
        defer { isTogglingPip = false }

        if pipEnabled {
            pipViewCoordinator?.enterPictureInPicture()
            if let vc = liveKitVC, !vc.roomCtx.isInPip {
                vc.roomCtx.isInPip = true
            }
        } else {
            pipViewCoordinator?.exitPictureInPicture()
            if let vc = liveKitVC, vc.roomCtx.isInPip {
                vc.roomCtx.isInPip = false
            }
        }
    }
    
    func getKeyWindow() -> UIWindow? {
        if #available(iOS 13.0, *) {
            if let window = UIApplication.shared.connectedScenes
                .compactMap({ ($0 as? UIWindowScene)?.windows.first })
                .first(where: { $0.isKeyWindow }) {
                return window
            }
        } else {
            if let window = UIApplication.shared.keyWindow {
                return window
            }
        }
        return nil
    }

    func startVideoCall(
        link: String,
        shouldStartRecording: Bool = false,
        audioOnly: Bool? = nil
    ) {
        guard let owner = UserContact.getOwner() else {
            return
        }

        // Dismiss keyboard before starting call
        hideKeyboardOnCurrentVC()

        let linkUrl = VoIPRequestMessage.getFromString(link)?.link ?? link

        if activeCall {
            return
        }
        
        if linkUrl.isLiveKitCallLink, let room = linkUrl.liveKitRoomName {
            guard !isStartingCall else { return }
            isStartingCall = true
            API.sharedInstance.getLiveKitToken(
                room: room,
                alias: owner.nickname ?? "",
                profilePicture: owner.avatarUrl,
                hiveToken: linkUrl.liveKitHiveToken,
                callback: { url, token in
                    Task { @MainActor [weak self] in
                        guard let self = self else { return }
                        let liveKitVC = LiveKitCallViewController()
                        liveKitVC.url = url
                        liveKitVC.startRecording = linkUrl.contains("record=true") || shouldStartRecording
                        liveKitVC.token = token
                        liveKitVC.audioOnly = audioOnly ?? false

                        guard let window = self.getKeyWindow() else {
                            self.isStartingCall = false
                            return
                        }

                        let rootViewController = window.rootViewController
                        rootViewController?.addChild(liveKitVC)
                        rootViewController?.view.addSubview(liveKitVC.view)

                        self.liveKitVC = liveKitVC
                        self.pipViewCoordinator = CustomPipViewCoordinator(withView: liveKitVC.view, isLiveKit: true)
                        self.pipViewCoordinator?.delegate = self
                        self.pipViewCoordinator?.configureAsStickyView(withParentView: window)
                        self.pipViewCoordinator?.initialPositionInSuperview = .upperRightCorner

                        liveKitVC.didMove(toParent: rootViewController)

                        self.pipViewCoordinator?.show()

                        self.activeCall = true
                        self.isStartingCall = false
                    }
                },
                errorCallback: { error in
                    Task { @MainActor [weak self] in
                        self?.isStartingCall = false
                        AlertHelper.showAlert(title: "error.getting.token.title".localized, message: error)
                    }
                }
            )
        } else if linkUrl.isJitsiCallLink {
            switch(AVAudioSession.sharedInstance().recordPermission){
            case .denied://show alert
                AlertHelper.showAlert(title: "microphone.permission.required".localized, message: "microphone.permission.denied.jitsi".localized)
                return
            case .undetermined://request access & preempt starting video
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01, execute: {
                    let _ = AudioRecorderHelper().configureAudioSession(delegate: self)
                })
                return
            case .granted://continue
                break
            @unknown default:
                break
            }

            cleanUp()

            let jitsiMeetView = JitsiMeetView()
            jitsiMeetView.delegate = self
            
            self.jitsiMeetView = jitsiMeetView

            let options = JitsiMeetConferenceOptions.fromBuilder({(builder: JitsiMeetConferenceOptionsBuilder) -> Void in
                builder.serverURL = URL(string: linkUrl)!
                builder.room = linkUrl.callRoom
                builder.setAudioOnly(audioOnly ?? linkUrl.contains("startAudioOnly=true"))
                builder.setAudioMuted(false)
                builder.setVideoMuted(false)
                builder.setFeatureFlag("welcomepage.enabled", withValue: false)
                builder.setFeatureFlag("prejoinpage.enabled", withValue: false)
                builder.setSubject(" ")
                builder.userInfo = JitsiMeetUserInfo(
                    displayName: owner.nickname,
                    andEmail: nil,
                    andAvatar: URL(string: owner.avatarUrl ?? "")
                )
            })

            jitsiMeetView.join(options)
            jitsiMeetView.alpha = 0
            jitsiMeetView.layer.cornerRadius = 10
            jitsiMeetView.clipsToBounds = true

            if let window = getKeyWindow() {
                pipViewCoordinator = CustomPipViewCoordinator(withView: jitsiMeetView, isLiveKit: false)
                pipViewCoordinator?.delegate = self
                pipViewCoordinator?.configureAsStickyView(withParentView: window)
                pipViewCoordinator?.initialPositionInSuperview = .upperRightCorner
                pipViewCoordinator?.show()

                if !isGroupChat() {
                    videoCallPayButton = getPaymentView()
                    window.addSubview(videoCallPayButton!)
                }
            }
        } else {
            if let url = URL(string: linkUrl) {
                UIApplication.shared.open(url)
            }
        }
    }

    func getPaymentView() -> VideoCallPayButton {
        let windowWidth = WindowsManager.getWindowWidth()
        let videoCallPayButton = VideoCallPayButton(
            frame: CGRect(
                x: windowWidth/2,
                y: getWindowInsets().top + 63,
                width: windowWidth/2,
                height: 46.0
            )
        )
        videoCallPayButton.configure(delegata: self.videoCallDelegate, amount: UserContact.kTipAmount)
        videoCallPayButton.layer.zPosition = CGFloat(Float.greatestFiniteMagnitude)
        videoCallPayButton.isHidden = true
        return videoCallPayButton
    }

    fileprivate func cleanUp() {
        onPiP = false
        activeCall = false
        isStartingCall = false

        videoCallPayButton?.removeFromSuperview()
        videoCallPayButton = nil

        jitsiMeetView?.removeFromSuperview()
        jitsiMeetView = nil

        pipViewCoordinator = nil
        teardownLiveKitVC()
    }

    func paymentSent() {
        SoundsPlayer.playKeySound(soundId: SoundsPlayer.PaymentSent)
        videoCallPayButton?.animatePayment()
    }

    func activeFullScreenCall() -> Bool {
        return activeCall && !onPiP
    }
}

extension VideoCallManager : JitsiMeetViewDelegate {
    nonisolated func conferenceJoined(_ data: [AnyHashable : Any]!) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.activeCall = true
            if self.onPiP { return }
            self.videoCallPayButton?.isHidden = self.isGroupChat()
        }
    }

    nonisolated func conferenceTerminated(_ data: [AnyHashable : Any]!) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.videoCallPayButton?.isHidden = true
            self.pipViewCoordinator?.hide() { _ in
                self.cleanUp()
            }
            self.videoCallDelegate?.didFinishCall()
        }

        if #available(iOS 14.0, *) {
            JitsiIncomingCallManager.sharedInstance.finishCall()
        }
    }

    nonisolated func ready(toClose data: [AnyHashable : Any]!) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.videoCallPayButton?.isHidden = true
            self.pipViewCoordinator?.hide() { _ in
                self.cleanUp()
            }
            self.videoCallDelegate?.didFinishCall()
        }

        if #available(iOS 14.0, *) {
            JitsiIncomingCallManager.sharedInstance.finishCall()
        }
    }

    nonisolated func enterPicture(inPicture data: [AnyHashable : Any]!) {
        Task { @MainActor [weak self] in
            self?.pipViewCoordinator?.enterPictureInPicture()
        }
    }
}

extension VideoCallManager : CustomPipViewCoordinatorDelegate {
    func enterPictureInPicture() {
        onPiP = true
        videoCallPayButton?.isHidden = true
        videoCallDelegate?.didSwitchMode(pip: true)
    }

    func exitPictureInPicture() {
        onPiP = false
        videoCallDelegate?.didSwitchMode(pip: false)
        hideKeyboardOnCurrentVC()

        DelayPerformedHelper.performAfterDelay(seconds: 0.25, completion: {
            self.videoCallPayButton?.isHidden = self.isGroupChat()
        })
    }

    func hideKeyboardOnCurrentVC() {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let centerVC = appDelegate.getCurrentVC()
        centerVC?.view.endEditing(true)
    }
}

extension VideoCallManager : AudioHelperDelegate{
    func didStartRecording(_ success: Bool) {}
    
    func didFinishRecording(_ success: Bool) {}
    
    func audioTooShort() {}
    
    func recordingProgress(minutes: String, seconds: String) {}
}
