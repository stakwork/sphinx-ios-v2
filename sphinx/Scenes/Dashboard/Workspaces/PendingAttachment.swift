//
//  PendingAttachment.swift
//  sphinx
//
//  Model representing an image selected by the user but not yet sent.
//

import UIKit

enum PendingAttachmentState {
    case uploading
    case done
    case failed
}

struct PendingAttachment {
    let id: UUID
    let image: UIImage
    let filename: String
    let mimeType: String
    let size: Int
    var state: PendingAttachmentState
    var s3Path: String? // populated after successful upload
}
