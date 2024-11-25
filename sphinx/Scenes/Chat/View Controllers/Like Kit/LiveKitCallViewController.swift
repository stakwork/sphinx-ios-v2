//
//  LiveKitCallViewController.swift
//  sphinx
//
//  Created by Tomas Timinskas on 04/11/2024.
//  Copyright © 2024 sphinx. All rights reserved.
//

import UIKit
import SwiftUI
import LiveKit
import KeychainAccess
import AVFoundation

class LiveKitCallViewController: UIViewController {
    
    var url: String? = nil
    var token: String? = nil
    var audioOnly: Bool = true
    
    var appCtx = AppContext(store: sync)
    var roomCtx = RoomContext(store: sync)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let url = url, let token = token else {
            return
        }
        
        roomCtx.url = url
        roomCtx.token = token
        roomCtx.audioOnly = audioOnly
        
        // Create the SwiftUI view
        let swiftUIView = RoomContextView(onCallEnded: {
            Task { @MainActor in
                VideoCallManager.sharedInstance.closePipController()
            }
        }).environmentObject(appCtx).environmentObject(roomCtx)

        // Create a hosting controller
        let hostingController = UIHostingController(rootView: swiftUIView)
        
        // Add the hosting controller as a child
        addChild(hostingController)
        view.addSubview(hostingController.view)
        
        // Set up constraints or frame for the hosting controller's view
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        hostingController.didMove(toParent: self)
    }
}

@MainActor let sync = ValueStore<Preferences>(store: Keychain(service: "group.com.gl.sphinx.v2"),
                                              key: "preferences",
                                              default: Preferences())

struct RoomSwitchView: View {
    @EnvironmentObject var appCtx: AppContext
    @EnvironmentObject var roomCtx: RoomContext
    @EnvironmentObject var room: Room

    var shouldShowRoomView: Bool {
        true
    }

    func computeTitle() -> String {
        if shouldShowRoomView {
            var elements: [String] = []
            if let roomName = room.name {
                elements.append(roomName)
            }
            if let localParticipantName = room.localParticipant.name {
                elements.append(localParticipantName)
            }
            return elements.joined(separator: " ")
        }

        return "LiveKit"
    }

    var body: some View {
        ZStack {
            Color(UIColor.Sphinx.Body).ignoresSafeArea()

            if shouldShowRoomView {
                RoomView()
            } else {
                ConnectView()
            }
        }
        .navigationTitle(computeTitle())
        .onChange(of: shouldShowRoomView) { _ in
            
        }
    }
}

// Attaches RoomContext and Room to the environment
struct RoomContextView: View {
    @EnvironmentObject var appCtx: AppContext
    @EnvironmentObject var roomCtx: RoomContext    
    
    typealias OnCallEnded = () -> Void
    private var onCallEnded: OnCallEnded? = nil
    
    init(onCallEnded: OnCallEnded? = nil) {
        self.onCallEnded = onCallEnded
    }
    
    var body: some View {
        RoomSwitchView()
            .environmentObject(roomCtx)
            .environmentObject(roomCtx.room)
            .environment(\.colorScheme, .dark)
            .foregroundColor(Color.white)
            .onDisappear {
                print("\(String(describing: type(of: self))) onDisappear")
                Task {
                    await roomCtx.disconnect()
                }
            }
            .onAppear() {
                Task {
                    if !roomCtx.token.isEmpty {
                        let room = try await roomCtx.connect(onConnected: {
                            self.enableMic()
                            
                            if !roomCtx.audioOnly {
                                self.enableCamera()
                            }
                        }, onCallEnded: {
                            self.onCallEnded?()
                        })
                        appCtx.connectionHistory.update(room: room, e2ee: false, e2eeKey: "")
                    }
                }
            }
            .onOpenURL(perform: { url in

                guard let urlComponent = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
                guard let host = url.host else { return }

                let secureValue = urlComponent.queryItems?.first(where: { $0.name == "secure" })?.value?.lowercased()
                let secure = ["true", "1"].contains { $0 == secureValue }

                let tokenValue = urlComponent.queryItems?.first(where: { $0.name == "token" })?.value ?? ""

                let e2ee = ["true", "1"].contains { $0 == secureValue }
                let e2eeKey = urlComponent.queryItems?.first(where: { $0.name == "e2eeKey" })?.value ?? ""

                var builder = URLComponents()
                builder.scheme = secure ? "wss" : "ws"
                builder.host = host
                builder.port = url.port

                guard let builtUrl = builder.url?.absoluteString else { return }

                print("built URL: \(builtUrl), token: \(tokenValue)")

                Task { @MainActor in
                    roomCtx.url = builtUrl
                    roomCtx.token = tokenValue
                    roomCtx.isE2eeEnabled = e2ee
                    roomCtx.e2eeKey = e2eeKey
                    if !roomCtx.token.isEmpty {
                        let room = try await roomCtx.connect()
                        appCtx.connectionHistory.update(room: room, e2ee: e2ee, e2eeKey: e2eeKey)
                    }
                }
            })
            .border(Color(UIColor.Sphinx.TextInverted), width: roomCtx.isInPip ? 1 : 0)
    }
    
    func enableMic() {
        Task {
            try await roomCtx.room.localParticipant.setMicrophone(enabled: true)
        }
    }
    
    func enableCamera() {
        Task {
            let captureOptions = CameraCaptureOptions(
                device: AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                dimensions: .h1080_169
            )
            
            let maxFPS: Int = 30

            let publishOptions = VideoPublishOptions(
                name: nil,
                encoding: VideoEncoding(maxBitrate: VideoParameters.presetH1080_169.encoding.maxBitrate, maxFps: maxFPS),
                screenShareEncoding: nil,
                simulcast: true,
                simulcastLayers: [],
                screenShareSimulcastLayers: [],
                preferredCodec: VideoCodec.vp8,
                preferredBackupCodec: nil
            )
            
            try await roomCtx.room.localParticipant.setCamera(
                enabled: true,
                captureOptions: captureOptions,
                publishOptions: publishOptions
            )
        }
    }
}
