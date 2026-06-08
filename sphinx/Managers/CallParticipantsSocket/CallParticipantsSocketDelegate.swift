//
//  CallParticipantsSocketDelegate.swift
//  sphinx
//
//  Created on 2026-06-08.
//  Copyright © 2026 sphinx. All rights reserved.
//

import Foundation

protocol CallParticipantsSocketDelegate: AnyObject {
    func didReceiveCurrentParticipants(roomName: String, participants: [BubbleMessageLayoutState.CallParticipantInfo])
    func participantJoined(roomName: String, participant: BubbleMessageLayoutState.CallParticipantInfo)
    func participantLeft(roomName: String, identity: String)
    func roomFinished(roomName: String)
}
