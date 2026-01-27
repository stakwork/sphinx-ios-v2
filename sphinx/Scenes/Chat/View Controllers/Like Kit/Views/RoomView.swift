/*
 * Copyright 2024 LiveKit
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import LiveKit
import SFSafeSymbols
import SwiftUI
import UIKit
import SDWebImageSwiftUI

let adaptiveMin = 170.0
let toolbarPlacement: ToolbarItemPlacement = .bottomBar

extension CIImage {
    // helper to create a `CIImage` for both platforms
    convenience init(named name: String) {
        self.init(cgImage: UIImage(named: name)!.cgImage!)
    }
}

struct RoomView: View {
    @EnvironmentObject var appCtx: AppContext
    @EnvironmentObject var roomCtx: RoomContext
    @EnvironmentObject var room: Room

    @State var isCameraPublishingBusy = false
    @State var isMicrophonePublishingBusy = false
    @State var isScreenSharePublishingBusy = false
    @State var isARCameraPublishingBusy = false

    @State private var screenPickerPresented = false
    @State private var publishOptionsPickerPresented = false
    @State private var publishParticipantsView = false

    @State private var cameraPublishOptions = VideoPublishOptions()

    @State private var showConnectionTime = true
    @State private var canSwitchCameraPosition = false

    @State var isAnyParticipantAudioSubscribed = true

    // Call timer
    @State private var callElapsedTime: TimeInterval = 0
    @State private var callTimer: Timer? = nil

    // Participant join alert
    @State private var joinedParticipant: Participant? = nil
    @State private var showJoinAlert: Bool = false
    @State private var previousParticipantIds: Set<String> = []

    let newMessageBubbleHelper = NewMessageBubbleHelper()

    // MARK: - Call Timer

    /// Returns the earliest joinedAt time from all participants as the room start time
    private var roomStartTime: Date? {
        let allJoinTimes = room.allParticipants.values.compactMap { $0.joinedAt }
        return allJoinTimes.min()
    }

    /// Formats a TimeInterval as MM:SS or HH:MM:SS if over an hour
    private func formatElapsedTime(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(interval)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    /// Starts the call timer using the room start time
    private func startCallTimer() {
        // Invalidate any existing timer
        callTimer?.invalidate()

        // Update immediately
        updateElapsedTime()

        // Start periodic updates
        callTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                updateElapsedTime()
            }
        }
    }

    /// Updates the elapsed time based on room start time
    private func updateElapsedTime() {
        if let startTime = roomStartTime {
            callElapsedTime = Date().timeIntervalSince(startTime)
        }
    }

    /// Stops the call timer
    private func stopCallTimer() {
        callTimer?.invalidate()
        callTimer = nil
    }

    // MARK: - Participant Join Alert

    /// Checks for new participants and shows join alert
    private func checkForNewParticipants() {
        let currentIds = Set(room.allParticipants.values.compactMap { $0.sid?.stringValue })

        // Find newly joined participants (excluding local participant)
        let newIds = currentIds.subtracting(previousParticipantIds)

        for newId in newIds {
            if let participant = room.allParticipants.values.first(where: { $0.sid?.stringValue == newId }),
               !(participant is LocalParticipant) {
                showParticipantJoinAlert(participant)
                break // Show one at a time
            }
        }

        previousParticipantIds = currentIds
    }

    /// Shows the join alert for a participant
    private func showParticipantJoinAlert(_ participant: Participant) {
        joinedParticipant = participant

        withAnimation(.easeOut(duration: 0.3)) {
            showJoinAlert = true
        }

        // Auto-dismiss after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeIn(duration: 0.3)) {
                showJoinAlert = false
            }
            // Clear participant after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                joinedParticipant = nil
            }
        }
    }

    /// The participant join alert view (full width on iOS)
    private func participantJoinAlertView() -> some View {
        Group {
            if let participant = joinedParticipant {
                HStack(spacing: 10) {
                    // Participant image or initials
                    if let profilePictureUrl = participant.profilePictureUrl,
                       let url = URL(string: profilePictureUrl) {
                        WebImage(url: url)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                    } else {
                        ZStack {
                            Circle()
                                .fill(roomCtx.getColorForParticipan(participantId: participant.sid?.stringValue) ?? Color(UIColor.random()))
                                .frame(width: 32, height: 32)

                            Text((participant.name ?? "Unknown").getInitialsFromName())
                                .font(Font(UIFont(name: "Roboto-Medium", size: 14.0)!))
                                .foregroundColor(.white)
                        }
                    }

                    // Join message
                    Text("\(participant.name ?? "Someone") joined the call")
                        .font(Font(UIFont(name: "Roboto-Medium", size: 13.0)!))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Color.black
                        .opacity(0.85)
                        .cornerRadius(10)
                )
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .offset(y: showJoinAlert ? 0 : -100)
                .opacity(showJoinAlert ? 1 : 0)
            }
        }
    }

    private func toggleRecording() {
        guard let roomName = room.name else {
            return
        }
        roomCtx.isProcessingRecordRequest = true
        
        let urlAction = roomCtx.didStartRecording ? "stop" : "start"
        var isoStringWithMilliseconds: String? = nil
        
        if !roomCtx.didStartRecording {
            let currentDate = Date()
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            isoStringWithMilliseconds = isoFormatter.string(from: currentDate)
        }
        
        self.roomCtx.didStartRecording.toggle()
        
        self.newMessageBubbleHelper.showGenericMessageView(
            text: self.roomCtx.didStartRecording ? "Starting call recording. Please wait..." : "Stopping call recording. Please wait...",
            delay: 5,
            textColor: UIColor.white,
            backColor: UIColor.Sphinx.BadgeRed,
            backAlpha: 1.0
        )
        
        API.sharedInstance.toggleLiveKitRecording(
            room: roomName,
            now: isoStringWithMilliseconds,
            action: urlAction,
            callback: { success in
                if !success {
                    DispatchQueue.main.async {
                        self.roomCtx.didStartRecording.toggle()
                    }
                }
                DispatchQueue.main.async {
                    self.roomCtx.isProcessingRecordRequest = false
                }
            }
        )
    }
    
    private func stopRecording() {
        guard let roomName = room.name else {
            return
        }
        
        API.sharedInstance.toggleLiveKitRecording(
            room: roomName,
            now: nil,
            action: "stop",
            callback: { _ in }
        )
    }

    func sortedParticipants() -> [Participant] {
        room.allParticipants.values.sorted { p1, p2 in
            if p1 is LocalParticipant { return true }
            if p2 is LocalParticipant { return false }
            return (p1.joinedAt ?? Date()) < (p2.joinedAt ?? Date())
        }
    }
    
    func scrollToTop(_ scrollView: ScrollViewProxy) {
        guard let first = sortedParticipants().first else { return }
        withAnimation {
            scrollView.scrollTo(first.id)
        }
    }
    
    private func updateAudioSubscriptionStatus() {
        isAnyParticipantAudioSubscribed = room.remoteParticipants.count == 0 || room.remoteParticipants.values.filter({ ($0.firstAudioPublication as? RemoteTrackPublication)?.subscriptionState == .subscribed }).count > 0
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isAnyParticipantAudioSubscribed = room.remoteParticipants.count == 0 || room.remoteParticipants.values.filter({ ($0.firstAudioPublication as? RemoteTrackPublication)?.subscriptionState == .subscribed }).count > 0
        }
    }

    func content(geometry: GeometryProxy) -> some View {
        ZStack {
            VStack(spacing: roomCtx.isInPip ? 0 : 8) {
                if !roomCtx.isInPip {
                    HStack(spacing: 20) {
                        Button(action: {
                           Task {
                               publishParticipantsView = false
                               roomCtx.isInPip.toggle()
                           }
                        },
                        label: {
                            HStack(spacing: 7) {
                                Image(systemSymbol: .arrowBackward)
                                    .renderingMode(.template)
                                    .foregroundColor(Color.white)
                                    .font(.system(size: 20))

                                Text("Chat")
                                    .foregroundColor(.white)
                                    .font(Font(UIFont(name: "Roboto-Medium", size: 17.0)!))
                            }
                        })

                        // Call duration timer
                        if room.connectionState == .connected {
                            Text(formatElapsedTime(callElapsedTime))
                                .font(Font(UIFont(name: "Roboto-Regular", size: 14.0)!))
                                .foregroundColor(Color(UIColor.Sphinx.SecondaryText))
                                .monospacedDigit()
                                .padding(.horizontal, 13)
                                .padding(.vertical, 8)
                                .background(
                                    Color(UIColor.Sphinx.MainBottomIcons)
                                        .opacity(0.1)
                                        .cornerRadius(8.0)
                                )
                        }

                        Spacer()
                        
                        Button(action: {
                            Task {
                                for participant in room.remoteParticipants.values {
                                    if let remotePub = participant.firstAudioPublication as? RemoteTrackPublication {
                                        try await remotePub.set(subscribed: !isAnyParticipantAudioSubscribed)
                                    }
                                }
                                updateAudioSubscriptionStatus()
                            }
                        },
                        label: {
                            Image(systemSymbol: isAnyParticipantAudioSubscribed ? .speakerWave2Fill : .speakerSlashFill)
                                .renderingMode(.template)
                                .foregroundColor(Color.white)
                                .font(.system(size: 20))
                        })
                        
                        let isCameraEnabled = room.localParticipant.isCameraEnabled()
                        
                        if isCameraEnabled, canSwitchCameraPosition {
                            Button(action: {
                                Task {
                                    isCameraPublishingBusy = true
                                    defer { Task { @MainActor in isCameraPublishingBusy = false } }
                                    if let track = room.localParticipant.firstCameraVideoTrack as? LocalVideoTrack,
                                       let cameraCapturer = track.capturer as? CameraCapturer
                                    {
                                        try await cameraCapturer.switchCameraPosition()
                                    }
                                }
                            },
                            label: {
                                Image(systemSymbol: .arrowTriangle2CirclepathCameraFill)
                                    .renderingMode(.template)
                                    .foregroundColor(Color.white)
                                    .font(.system(size: 20))
                            })
                        }
                        
                        Menu {
                            Toggle("Show info overlay", isOn: $appCtx.showInformationOverlay)
                            
                            Group {
                                Toggle("VideoView visible", isOn: $appCtx.videoViewVisible)
                                Toggle("VideoView flip", isOn: $appCtx.videoViewMirrored)
                                Divider()
                            }
                            
                            Group {
                                Divider()
                                
                                Button {
                                    Task {
                                        await room.localParticipant.unpublishAll()
                                    }
                                } label: {
                                    Text("Unpublish all")
                                }
                            }
                            
                        } label: {
                            Text("more_vert")
                                .font(.custom("MaterialIcons-Regular", size: 24))
                                .foregroundColor(Color.white)
                        }
                    }
                    .frame(height: 60)
                    .frame(minWidth: 0, maxWidth: .infinity)
                }
                
                if case .connecting = room.connectionState {
                    Text("Connecting...")
                        .multilineTextAlignment(.center)
                        .font(Font(UIFont(name: "Roboto-Regular", size: 16.0)!))
                        .foregroundColor(.white)
                        .padding()
                }

                HorVStack(axis: geometry.isTall ? .vertical : .horizontal, spacing: 5) {
                    Group {
                        if let focusParticipant = roomCtx.focusParticipant {
                            ZStack(alignment: .bottomTrailing) {
                                ParticipantView(participant: focusParticipant,
                                                videoViewMode: appCtx.videoViewMode)
                                { _ in
                                    roomCtx.focusParticipant = nil
                                }
                            }

                        } else {
                            ParticipantLayout(sortedParticipants(), spacing: 8) { participant in
                                ParticipantView(participant: participant,
                                                videoViewMode: appCtx.videoViewMode)
                                { participant in
                                    roomCtx.focusParticipant = participant
                                }
                            }
                        }
                    }
                    .frame(
                        minWidth: 0,
                        maxWidth: .infinity,
                        minHeight: 0,
                        maxHeight: .infinity
                    )
                }
                
                ZStack {
                    HStack(spacing: 16) {
                        ZStack(alignment: .center) {
                            let isCameraEnabled = room.localParticipant.isCameraEnabled()
                            
                            // Toggle camera enabled
                            GeometryReader { geometry in
                                let size = (geometry.size.width > geometry.size.height) ? geometry.size.height : geometry.size.width
                                let HPadding = (geometry.size.width - geometry.size.height)

                                Button(action: {
                                    Task {
                                        isCameraPublishingBusy = true
                                        defer { Task { @MainActor in isCameraPublishingBusy = false } }
                                        try await room.localParticipant.setCamera(enabled: !isCameraEnabled)
                                    }
                                },
                                label: {
                                    Image(systemSymbol: isCameraEnabled ? .videoFill : .videoSlashFill)
                                        .renderingMode(.template)
                                        .foregroundColor(isCameraEnabled ? Color.white : Color(UIColor(hex: "#FF6F6F")))
                                        .font(.system(size: roomCtx.isInPip ? 18 : 20))
                                        .frame(width: roomCtx.isInPip ? min(geometry.size.width, 50) : size)
                                        .frame(height: size)
                                        .aspectRatio(roomCtx.isInPip ? nil : 1, contentMode: .fill)
                                        .padding(.leading, HPadding / 2)
                                })
                                // disable while publishing/un-publishing
                                .disabled(isCameraPublishingBusy)
                                .background(
                                    Color(isCameraEnabled ? UIColor.Sphinx.MainBottomIcons : UIColor.Sphinx.BadgeRed)
                                        .opacity(isCameraEnabled ? 0.2 : 0.2)
                                        .cornerRadius(size / 2)
                                        .frame(width: roomCtx.isInPip ? min(geometry.size.width, 50) : size)
                                        .frame(height: size)
                                        .aspectRatio(roomCtx.isInPip ? nil : 1, contentMode: .fill)
                                        .padding(.leading, HPadding / 2)
                                )
                            }
                            .frame(maxWidth: .infinity)
                            .frame(maxHeight: .infinity)
                            // MARK: - Commented out camera options menu/popover (kept for future use)
                            // Original implementation had two paths:
                            // 1. When camera enabled + canSwitchPosition: Menu with "Switch position" and "Disable"
                            // 2. When camera disabled: Button that opens publishOptionsPickerPresented popover
                            // .popover(isPresented: $publishOptionsPickerPresented) {
                            //     PublishOptionsView(publishOptions: cameraPublishOptions) { captureOptions, publishOptions in
                            //         publishOptionsPickerPresented = false
                            //         isCameraPublishingBusy = true
                            //         cameraPublishOptions = publishOptions
                            //         Task {
                            //             defer { Task { @MainActor in isCameraPublishingBusy = false } }
                            //             try await room.localParticipant.setCamera(enabled: true,
                            //                                                       captureOptions: captureOptions,
                            //                                                       publishOptions: publishOptions)
                            //         }
                            //     }
                            //     .padding()
                            // }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: roomCtx.isInPip ? 40 : 64)
                        .layoutPriority(1)
                        
                        ZStack(alignment: .center) {
                            let isMicrophoneEnabled = room.localParticipant.isMicrophoneEnabled()
                            // Toggle microphone enabled
                            GeometryReader { geometry in
                                let size = (geometry.size.width > geometry.size.height) ? geometry.size.height : geometry.size.width
                                
                                Button(action: {
                                   Task {
                                       isMicrophonePublishingBusy = true
                                       defer { Task { @MainActor in isMicrophonePublishingBusy = false } }
                                       try await room.localParticipant.setMicrophone(enabled: !isMicrophoneEnabled)
                                   }
                                },
                                label: {
                                   Image(systemSymbol: isMicrophoneEnabled ? .micFill : .micSlashFill)
                                       .renderingMode(.template)
                                       .foregroundColor(isMicrophoneEnabled ? Color.white : Color(UIColor(hex: "#FF6F6F")))
                                       .font(.system(size: roomCtx.isInPip ? 18 : 20))
                                       .frame(width: roomCtx.isInPip ? min(geometry.size.width, 50) : size)
                                       .frame(height: size)
                                       .aspectRatio(roomCtx.isInPip ? nil : 1, contentMode: .fill)
                                })
                                // disable while publishing/un-publishing
                                .disabled(isMicrophonePublishingBusy)
                                .background(
                                    Color(isMicrophoneEnabled ? UIColor.Sphinx.MainBottomIcons : UIColor.Sphinx.BadgeRed)
                                        .opacity(isMicrophoneEnabled ? 0.2 : 0.2)
                                        .cornerRadius(size / 2)
                                        .frame(width: roomCtx.isInPip ? min(geometry.size.width, 50) : size)
                                        .frame(height: size)
                                        .aspectRatio(roomCtx.isInPip ? nil : 1, contentMode: .fill)
                                )
                                .frame(maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fill)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(maxHeight: .infinity)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: roomCtx.isInPip ? 40 : 64)
                        .layoutPriority(1)
                        
                        if !roomCtx.isInPip {
                            // Toggle recording
                            ZStack(alignment: .center) {
                                GeometryReader { geometry in
                                    let size = (geometry.size.width > geometry.size.height) ? geometry.size.height : geometry.size.width
                                    
                                    Button(action: {
                                       Task {
                                           if roomCtx.isProcessingRecordRequest {
                                               return
                                           }
                                           if (room.isRecording && roomCtx.didStartRecording) || !room.isRecording {
                                               toggleRecording()
                                           }
                                       }
                                    },
                                    label: {
                                        Image(systemSymbol: room.isRecording && roomCtx.didStartRecording ? .stopCircle : .recordCircle)
                                            .renderingMode(.template)
                                            .foregroundColor(room.isRecording ? Color(UIColor(hex: "#FF6F6F")) : Color.white)
                                            .font(.system(size: 30))
                                            .opacity(roomCtx.shouldAnimate ? 0.4 : 1.0)
                                            .frame(height: size)
                                            .aspectRatio(1, contentMode: .fill)
                                    })
                                    .background(
                                        Color(UIColor.Sphinx.MainBottomIcons)
                                            .opacity(0.2)
                                            .cornerRadius(size / 2)
                                            .frame(width: size)
                                            .frame(height: size)
                                            .aspectRatio(1, contentMode: .fill)
                                    )
                                    .frame(maxWidth: .infinity)
                                    .aspectRatio(1, contentMode: .fill)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(maxHeight: .infinity)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 64)
                            .layoutPriority(1)
                            
                            ZStack(alignment: .center) {
                                Group {
                                    GeometryReader { geometry in
                                        let size = (geometry.size.width > geometry.size.height) ? geometry.size.height : geometry.size.width
                                        
                                        Button(action: {
                                            Task { @MainActor in
                                                publishParticipantsView = true
                                            }
                                        },
                                               label: {
                                            Image(systemSymbol: .person2Fill)
                                                .renderingMode(.template)
                                                .foregroundColor(Color.white)
                                                .font(.system(size: 20))
                                                .frame(width: size)
                                                .frame(height: size)
                                                .aspectRatio(1, contentMode: .fill)
                                        })
                                        .background(
                                            Color(UIColor.Sphinx.MainBottomIcons)
                                                .opacity(0.2)
                                                .cornerRadius(size / 2)
                                                .frame(width: size)
                                                .frame(height: size)
                                                .aspectRatio(1, contentMode: .fill)
                                        )
                                        .frame(maxWidth: .infinity)
                                        .aspectRatio(1, contentMode: .fill)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(maxHeight: .infinity)
                                }
                                if room.participantCount > 0 {
                                    GeometryReader { geometry in
                                        HStack() {
                                            Spacer()
                                            
                                            VStack {
                                                Text("\(room.participantCount)")
                                                    .foregroundColor(Color.black)
                                                    .font(Font(UIFont(name: "Roboto-Bold", size: 12.0)!))
                                                    .padding(.horizontal, 7.5)
                                                    .padding(.vertical, 4)
                                                    .background(
                                                        Color(UIColor.white)
                                                            .cornerRadius(geometry.size.height / 2)
                                                            .frame(minWidth: 22)
                                                    )
                                                
                                                Spacer()
                                            }
                                            
                                            Spacer()
                                                .frame(width: (geometry.size.width - 64) / 2)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 64)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 64)
                            .layoutPriority(1)
                        } else {
                            ZStack(alignment: .center) {
                                GeometryReader { geometry in
                                    Button(action: {
                                       Task {
                                           roomCtx.isInPip.toggle()
                                       }
                                    },
                                    label: {
                                        Image(systemSymbol: .pipExit)
                                           .renderingMode(.template)
                                           .foregroundColor(Color.white)
                                           .font(.system(size: 16))
                                           .frame(height: geometry.size.height)
                                           .frame(width: min(geometry.size.width, 50))
                                    })
                                    .background(
                                        Color(UIColor.Sphinx.MainBottomIcons)
                                            .opacity(0.2)
                                            .cornerRadius(geometry.size.height / 2)
                                            .frame(height: geometry.size.height)
                                            .frame(width: min(geometry.size.width, 50))
                                    )
                                    .frame(maxWidth: .infinity)
                                    .aspectRatio(1, contentMode: .fill)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(maxHeight: .infinity)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .layoutPriority(1)
                        }
                        
                        ZStack {
                            GeometryReader { geometry in
                                Button(action: {
                                    Task {
                                        if roomCtx.didStartRecording && room.isRecording {
                                            roomCtx.stopAnimation()
                                        }
                                        await roomCtx.disconnect()
                                    }
                                },
                                label: {
                                    Image(systemSymbol: .phoneDownFill)
                                       .renderingMode(.template)
                                       .foregroundColor(Color.white)
                                       .font(.system(size: roomCtx.isInPip ? 18 : 22))
                                       .frame(height: geometry.size.height)
                                       .frame(width: min(geometry.size.width, roomCtx.isInPip ? 50 : 80))
                                })
                                .background(
                                    Color(UIColor.Sphinx.BadgeRed)
                                        .opacity(1)
                                        .cornerRadius(min(geometry.size.width, roomCtx.isInPip ? 50 : 80) / 2)
                                        .frame(height: min(geometry.size.width, roomCtx.isInPip ? 50 : 80))
                                        .frame(width: min(geometry.size.width, roomCtx.isInPip ? 50 : 80))
                                )
                                .frame(maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fill)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(maxHeight: .infinity)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: roomCtx.isInPip ? 40 : 64)
                        .layoutPriority(1)
                    }
                    .padding(.vertical, roomCtx.isInPip ? 12 : 30)
                    .frame(height: roomCtx.isInPip ? 40 : 64)
                    .frame(maxWidth: .infinity)
                }
                .frame(height: roomCtx.isInPip ? 64 : 124)
                .frame(minWidth: 0, maxWidth: .infinity)
                .padding(.horizontal, roomCtx.isInPip ? 8 : 16)
            }
            .padding(5)
            .background(Color.black.opacity(0.2))
            .cornerRadius(8.0)
            
            participantsView()
        }
    }
    
    func participantsView() -> some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Spacer()
                
                let height: CGFloat = CGFloat(min((76 + 64 * room.participantCount), 500))
                
                ZStack() {
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            Text(room.participantCount == 1 ? ("\(room.participantCount)  Participant") : ("\(room.participantCount)  Participants"))
                                .foregroundColor(Color(UIColor.Sphinx.Text))
                                .font(Font(UIFont(name: "Roboto-Bold", size: 18.0)!))
                            Spacer()
                            Button {
                                publishParticipantsView = false
                            } label: {
                                Image(systemSymbol: .xmark)
                                    .font(.system(size: 18))
                                    .foregroundColor(Color(UIColor.Sphinx.PlaceholderText))
                            }
                            .buttonStyle(.borderless)
                        }.frame(
                            minWidth: 0,
                            maxWidth: .infinity
                        ).frame(
                            height: 76
                        )
                        .padding(.trailing, 23)
                        .padding(.leading, 30)
                        
                        ScrollViewReader { scrollView in
                            ScrollView(.vertical, showsIndicators: true) {
                                LazyVStack(alignment: .leading, spacing: 0) {
                                    ForEach(sortedParticipants()) { participant in
                                        participantView(participant)
                                    }
                                }
                            }
                            .onAppear(perform: {
                                scrollToTop(scrollView)
                            })
                            .onChange(of: room.participantCount, perform: { _ in
                                scrollToTop(scrollView)
                            })
                            .frame(
                                minWidth: 0,
                                maxWidth: .infinity,
                                minHeight: 0,
                                maxHeight: .infinity,
                                alignment: .leading
                            )
                        }
                        .padding(.trailing, 23)
                        .padding(.leading, 30)
                    }
                    .frame(height: height + 100)
                    .frame(maxWidth: .infinity)
                    .background(Color(UIColor.Sphinx.HeaderBG).opacity(0.3))
                    .background(Blur(style: .prominent))
                    .cornerRadius(8.0)
                }
                .frame(height: height)
                .frame(maxWidth: .infinity)
            }
            .offset(y: publishParticipantsView ? 0 : UIScreen.main.bounds.height) // Start off-screen
            .animation(.easeInOut(duration: 0.5), value: publishParticipantsView)
        }
    }
    
    func participantView(_ participant: Participant) -> some View {
        return VStack {
            Rectangle()
                .fill(Color.clear)
                .frame(height: 1)
                .frame(maxWidth: .infinity)
            
            HStack(spacing: 8) {
                if let profilePictureUrl = participant.profilePictureUrl, let url = URL(string: profilePictureUrl) {
                    WebImage(url: url)
                        .onSuccess { _,_,_ in
                            print("success")
                        }
                        .onFailure { error in
                            print("error")
                        }
                        .resizable()
                        .scaledToFill()
                        .frame(width: 32.0, height: 32.0)
                        .clipped()
                        .cornerRadius(16.0)
                } else {
                    ZStack(alignment: .center) {
                        Circle()
                            .fill(roomCtx.getColorForParticipan(participantId: participant.sid?.stringValue) ?? Color(UIColor.random()))
                            .frame(maxWidth: 32.0, maxHeight: 32.0)

                        Text((participant.name ?? "Unknow").getInitialsFromName())
                            .font(Font(UIFont(name: "Roboto-Medium", size: 14.0)!))
                            .foregroundColor(Color.white)
                            .frame(width: 32.0, height: 32.0)
                    }
                }
                
                Text((participant.name ?? "Unknow"))
                    .padding(.leading, 8)
                    .font(Font(UIFont(name: "Roboto-Regular", size: 15.0)!))
                    .foregroundColor(Color(UIColor.Sphinx.Text))
                
                Spacer()
                
                ZStack(alignment: .center) {
                    if let publication = participant.mainVideoPublication,
                       !publication.isMuted,
                       appCtx.videoViewVisible
                    {
                        if let publication = participant.mainVideoPublication,
                           !publication.isMuted
                        {
                            if let remotePub = publication as? RemoteTrackPublication {
                                Menu {
                                    if case .subscribed = remotePub.subscriptionState {
                                        Button {
                                            Task {
                                                try await remotePub.set(subscribed: false)
                                            }
                                        } label: {
                                            Text("Unsubscribe")
                                        }
                                    } else if case .unsubscribed = remotePub.subscriptionState {
                                        Button {
                                            Task {
                                                try await remotePub.set(subscribed: true)
                                            }
                                        } label: {
                                            Text("Subscribe")
                                        }
                                    }
                                } label: {
                                    if case .subscribed = remotePub.subscriptionState {
                                        Image(systemSymbol: .videoFill)
                                            .foregroundColor(Color(UIColor.Sphinx.Text))
                                            .font(.system(size: 18))
                                    } else if case .notAllowed = remotePub.subscriptionState {
                                        Image(systemSymbol: .exclamationmarkCircle)
                                            .foregroundColor(Color(UIColor.Sphinx.BadgeRed))
                                            .font(.system(size: 18))
                                    } else {
                                        Image(systemSymbol: .videoSlashFill)
                                            .foregroundColor(Color(UIColor.Sphinx.Text))
                                            .font(.system(size: 18))
                                    }
                                }
                                .menuStyle(BorderlessButtonMenuStyle())
                                .fixedSize()
                                .frame(width: 32, height: 32)
                                .background(Color(UIColor.Sphinx.MainBottomIcons).opacity(0.2))
                                .cornerRadius(6.0)
                            } else {
                                Image(systemSymbol: .videoFill)
                                    .foregroundColor(Color(UIColor.Sphinx.Text))
                                    .font(.system(size: 18))
                            }

                        } else {
                            Image(systemSymbol: .videoFill)
                                .foregroundColor(Color.white)
                                .font(.system(size: 18))
                        }
                    }
                }.frame(width: 32.0, height: 32.0)
                
                ZStack(alignment: .center) {
                    if let publication = participant.firstAudioPublication,
                       !publication.isMuted
                    {
                        if let remotePub = publication as? RemoteTrackPublication {
                            Menu {
                                if case .subscribed = remotePub.subscriptionState {
                                    Button {
                                        Task {
                                            try await remotePub.set(subscribed: false)
                                            updateAudioSubscriptionStatus()
                                        }
                                    } label: {
                                        Text("Unsubscribe")
                                    }
                                } else if case .unsubscribed = remotePub.subscriptionState {
                                    Button {
                                        Task {
                                            try await remotePub.set(subscribed: true)
                                            updateAudioSubscriptionStatus()
                                        }
                                    } label: {
                                        Text("Subscribe")
                                    }
                                }
                            } label: {
                                if case .subscribed = remotePub.subscriptionState {
                                    Image(systemSymbol: .micFill)
                                        .foregroundColor(Color.white)
                                        .font(.system(size: 18))
                                } else if case .notAllowed = remotePub.subscriptionState {
                                    Image(systemSymbol: .exclamationmarkCircle)
                                        .foregroundColor(Color(UIColor.Sphinx.BadgeRed))
                                        .font(.system(size: 18))
                                } else {
                                    Image(systemSymbol: .micSlashFill)
                                        .foregroundColor(Color(UIColor.Sphinx.BadgeRed))
                                        .font(.system(size: 18))
                                }
                            }
                            .menuStyle(BorderlessButtonMenuStyle())
                            .fixedSize()
                            .frame(width: 32, height: 32)
                            .background(Color(UIColor.Sphinx.MainBottomIcons).opacity(0.2))
                            .cornerRadius(6.0)
                        } else {
                            Image(systemSymbol: .micFill)
                                .foregroundColor(Color.white)
                                .font(.system(size: 18))
                        }

                    } else {
                        Image(systemSymbol: .micSlashFill)
                            .foregroundColor(Color(UIColor.Sphinx.BadgeRed))
                            .font(.system(size: 18))
                    }
                }.frame(width: 32.0, height: 32.0)
            }
            .frame(height: 62)
            .frame(minWidth: 0, maxWidth: .infinity)
            
            Rectangle()
                .fill(Color.black.opacity(0.35))
                .frame(height: 1)
                .frame(maxWidth: .infinity)
        }
    }

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack(alignment: .top) {
                    content(geometry: geometry)

                    // Participant join alert (full width at top)
                    if !roomCtx.isInPip {
                        VStack {
                            participantJoinAlertView()
                                .padding(.top, 70)
                            Spacer()
                        }
                    }
                }
            }
        }.onAppear {
            Task { @MainActor in
                canSwitchCameraPosition = try await CameraCapturer.canSwitchPosition()

                // Start call timer if already connected
                if room.connectionState == .connected {
                    startCallTimer()
                }

                // Initialize participant tracking
                previousParticipantIds = Set(room.allParticipants.values.compactMap { $0.sid?.stringValue })
            }
            Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { _ in
                Task { @MainActor in
                    withAnimation {
                        showConnectionTime = false
                    }
                }
            }
        }.onChange(of: room.isRecording) { newValue in
            self.newMessageBubbleHelper.showGenericMessageView(
                text: newValue ? "Recording in progress.\nPlease be aware this call is being recorded." : "Recording ended.\nThis call is no longer being recorded.",
                delay: 5,
                textColor: UIColor.white,
                backColor: UIColor.Sphinx.BadgeRed,
                backAlpha: 1.0
            )
            
            self.roomCtx.shouldAnimate = newValue
            
            if newValue {
                roomCtx.startAnimation()
            } else {
                roomCtx.stopAnimation()
                roomCtx.didStartRecording = false
            }
        }.onChange(of: room.connectionState) { newValue in
            if newValue == .connected {
                Task { @MainActor in
                    // Start call timer when connected
                    startCallTimer()

                    // Initialize participant tracking when connected
                    previousParticipantIds = Set(room.allParticipants.values.compactMap { $0.sid?.stringValue })

                    if roomCtx.shouldStartRecording {
                        toggleRecording()
                    }
                }
            } else if newValue == .disconnected {
                stopCallTimer()
            }
        }
        .onChange(of: room.remoteParticipants.count) { _ in
            // Check for new participants when count changes
            checkForNewParticipants()
        }
        .onDisappear {
            stopCallTimer()
        }
    }
}

struct ParticipantLayout<Content: View>: View {
    let views: [AnyView]
    let spacing: CGFloat

    init<Data: RandomAccessCollection>(
        _ data: Data,
        id: KeyPath<Data.Element, Data.Element> = \.self,
        spacing: CGFloat,
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.spacing = spacing
        views = data.map { AnyView(content($0[keyPath: id])) }
    }

    func computeColumn(with geometry: GeometryProxy) -> (x: Int, y: Int) {
        let sqr = Double(views.count).squareRoot()
        let r: [Int] = [Int(sqr.rounded()), Int(sqr.rounded(.up))]
        let c = geometry.isTall ? r : r.reversed()
        return (x: c[0], y: c[1])
    }

    func grid(axis: Axis, geometry: GeometryProxy) -> some View {
        ScrollView([axis == .vertical ? .vertical : .horizontal]) {
            HorVGrid(axis: axis, columns: [GridItem(.flexible())], spacing: spacing) {
                ForEach(0 ..< views.count, id: \.self) { i in
                    views[i]
                        .aspectRatio(1, contentMode: .fill)
                }
            }
            .padding(axis == .horizontal ? [.leading, .trailing] : [.top, .bottom],
                     max(0, ((axis == .horizontal ? geometry.size.width : geometry.size.height)
                             - ((axis == .horizontal ? geometry.size.height : geometry.size.width) * CGFloat(views.count)) - (spacing * CGFloat(views.count - 1))) / 2))
        }
    }

    var body: some View {
        GeometryReader { geometry in
            if views.isEmpty {
                EmptyView()
            } else if geometry.size.width <= 300 {
                grid(axis: .vertical, geometry: geometry)
            } else if geometry.size.height <= 300 {
                grid(axis: .horizontal, geometry: geometry)
            } else {
                let verticalWhenTall: Axis = geometry.isTall ? .vertical : .horizontal
                let horizontalWhenTall: Axis = geometry.isTall ? .horizontal : .vertical

                switch views.count {
                // simply return first view
                case 1: views[0]
                case 3: HorVStack(axis: verticalWhenTall, spacing: spacing) {
                        views[0]
                        HorVStack(axis: horizontalWhenTall, spacing: spacing) {
                            views[1]
                            views[2]
                        }
                    }
                case 5: HorVStack(axis: verticalWhenTall, spacing: spacing) {
                        views[0]
                        if geometry.isTall {
                            HStack(spacing: spacing) {
                                views[1]
                                views[2]
                            }
                            HStack(spacing: spacing) {
                                views[3]
                                views[4]
                            }
                        } else {
                            VStack(spacing: spacing) {
                                views[1]
                                views[3]
                            }
                            VStack(spacing: spacing) {
                                views[2]
                                views[4]
                            }
                        }
                    }
                case 6:
                    if geometry.isTall {
                        VStack {
                            HStack {
                                views[0]
                                views[1]
                            }
                            HStack {
                                views[2]
                                views[3]
                            }
                            HStack {
                                views[4]
                                views[5]
                            }
                        }
                    } else {
                        VStack {
                            HStack {
                                views[0]
                                views[1]
                                views[2]
                            }
                            HStack {
                                views[3]
                                views[4]
                                views[5]
                            }
                        }
                    }
                default:
                    let c = computeColumn(with: geometry)
                    VStack(spacing: spacing) {
                        ForEach(0 ... (c.y - 1), id: \.self) { y in
                            HStack(spacing: spacing) {
                                ForEach(0 ... (c.x - 1), id: \.self) { x in
                                    let index = (y * c.x) + x
                                    if index < views.count {
                                        views[index]
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

struct HorVStack<Content: View>: View {
    let axis: Axis
    let horizontalAlignment: SwiftUI.HorizontalAlignment
    let verticalAlignment: SwiftUI.VerticalAlignment
    let spacing: CGFloat?
    let content: () -> Content

    init(axis: Axis = .horizontal,
         horizontalAlignment: SwiftUI.HorizontalAlignment = .center,
         verticalAlignment: SwiftUI.VerticalAlignment = .center,
         spacing: CGFloat? = nil,
         @ViewBuilder content: @escaping () -> Content)
    {
        self.axis = axis
        self.horizontalAlignment = horizontalAlignment
        self.verticalAlignment = verticalAlignment
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        Group {
            if axis == .vertical {
                VStack(alignment: horizontalAlignment, spacing: spacing, content: content)
            } else {
                HStack(alignment: verticalAlignment, spacing: spacing, content: content)
            }
        }
    }
}

struct HorVGrid<Content: View>: View {
    let axis: Axis
    let spacing: CGFloat?
    let content: () -> Content
    let columns: [GridItem]

    init(axis: Axis = .horizontal,
         columns: [GridItem],
         spacing: CGFloat? = nil,
         @ViewBuilder content: @escaping () -> Content)
    {
        self.axis = axis
        self.spacing = spacing
        self.columns = columns
        self.content = content
    }

    var body: some View {
        Group {
            if axis == .vertical {
                LazyVGrid(columns: columns, spacing: spacing, content: content)
            } else {
                LazyHGrid(rows: columns, spacing: spacing, content: content)
            }
        }
    }
}

extension GeometryProxy {
    public var isTall: Bool {
        size.height > size.width
    }

    var isWide: Bool {
        size.width > size.height
    }
}

struct Blur: UIViewRepresentable {
    var style: UIBlurEffect.Style = .systemMaterial

    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: style))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}
