//
//  ProfileViewControllerExtensions.swift
//  sphinx
//
//  Created by Tomas Timinskas on 06/04/2020.
//  Copyright © 2020 Sphinx. All rights reserved.
//

import UIKit
import Photos

extension ProfileViewController {
    func shouldChangePIN() {
        let pinCodeVC = SetPinCodeViewController.instantiate(mode: SetPinCodeViewController.SetPinMode.Change)
        pinCodeVC.doneCompletion = { pin in
            pinCodeVC.dismiss(animated: true, completion: {
                AlertHelper.showTwoOptionsAlert(title: "pin.change".localized, message: "confirm.pin.change".localized, confirm: {
                    UserData.sharedInstance.save(pin: pin)
                    
                    self.newMessageBubbleHelper.showGenericMessageView(
                        text: "pin.changed".localized,
                        delay: 6,
                        textColor: UIColor.white,
                        backColor: UIColor.Sphinx.PrimaryGreen,
                        backAlpha: 1.0
                    )
                })
            })
        }
        self.present(pinCodeVC, animated: true)
    }
}

extension ProfileViewController : UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        currentField = textField
        previousFieldValue = textField.text
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if let text = textField.text {
            
            if textField.tag == ProfileFields.Name.rawValue {
                setFieldsAfterEdit()
                return true
            }
            
            if textField.tag == ProfileFields.MeetingPmtAmt.rawValue {
                if let value = Int(text) {
                    UserContact.kTipAmount = value
                }
                setFieldsAfterEdit()
                return true
            }
            
            if text.isValidURL {
                switch (textField.tag) {
                case ProfileFields.InvitesServer.rawValue:
                    API.kHUBServerUrl = text
                    break
                case ProfileFields.MemesServer.rawValue:
                    API.kAttachmentsServerUrl = text
                    break
                case ProfileFields.VideoCallServer.rawValue:
                    API.kVideoCallServer = text
                    break
                default:
                    break
                }
            }
        }
        setFieldsAfterEdit()
        return true
    }
    
    func setFieldsAfterEdit() {
        updateProfile()
        configureServers()
        view.endEditing(true)
    }
    
    func shouldRevertValue() {
        if let currentField = currentField, let previousFieldValue = previousFieldValue, previousFieldValue != "" {
            currentField.text = previousFieldValue
        }
    }
    
    func updateProfile(photoUrl: String? = nil) {
        if let profile = UserContact.getOwner() {
            let nickname = profile.nickname ?? ""
            let privatePhoto = profile.privatePhoto
            
            let updatedName = nameTextField.text ?? nickname
            let updatedPrivatePhoto = !sharePhotoSwitch.isOn
            
            profile.avatarUrl = photoUrl ?? profile.avatarUrl
            
            self.configureProfile()
        }
    }
}

extension ProfileViewController : UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let chosenImage = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
            if let asset = info[UIImagePickerController.InfoKey.phAsset] as? PHAsset {
                let requestOptions = PHImageRequestOptions()
                requestOptions.isSynchronous = true
                
                PHImageManager.default().requestImageDataAndOrientation(for: asset, options: requestOptions, resultHandler: { (imageData, _, _, _) in
                    self.dismiss(animated:true, completion: {
                        if let data = imageData, data.isAnimatedImage() {
                            self.uploadGif(data: data)
                        } else {
                            self.uploadImage(image: chosenImage)
                        }
                    })
                })
            } else {
                self.dismiss(animated:true, completion: {
                    self.uploadImage(image: chosenImage)
                })
            }
        }
    }
    
    func uploadGif(data: Data) {
        self.profileImageView.image = data.gifImageFromData()
        self.profileImageView.contentMode = .scaleAspectFill
        self.uploadImageData(data: data)
    }
    
    func uploadImage(image: UIImage) {
        if let data = image.jpegData(compressionQuality: 0.5) {
            self.profileImageView.image = image
            self.profileImageView.contentMode = .scaleAspectFill
            self.uploadImageData(data: data)
        }
    }
    
    func uploadImageData(data: Data) {
        if let profile = UserContact.getOwner() {
            
            uploading = true
            
            let attachmentsManager = AttachmentsManager.sharedInstance
            attachmentsManager.setDelegate(delegate: self)
            
            let fileType = data.isAnimatedImage() ? AttachmentsManager.AttachmentType.Gif : AttachmentsManager.AttachmentType.Photo
            let attachmentObject = AttachmentObject(data: data, type: fileType)
            attachmentsManager.uploadImage(attachmentObject: attachmentObject, route: "public")
        } else {
            configureProfile()
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
}

extension ProfileViewController : AttachmentsManagerDelegate {
    func didUpdateUploadProgress(progress: Int) {
        let uploadedMessage = String(format: "uploaded.progress".localized, progress)
        uploadingLabel.text = uploadedMessage
    }
    
    func didSuccessUploadingImage(url: String) {
        if let image = profileImageView.image {
            MediaLoader.storeImageInCache(img: image, url: url, message: nil)
        }
        updateProfile(photoUrl: url)
    }
}

extension ProfileViewController : AppearenceViewDelegate {
    func didChangeAppearance() {
        sizeView.setViewBorder()
        settingsTabView.setViewBorder()
    }
}

extension ProfileViewController : SettingsTabsDelegate {
    func didChangeSettingsTab(tag: Int) {
        for tab in tabContainers {
            tab.isHidden = tab.tag != tag
        }
    }
}

extension ProfileViewController : NotificationSoundDelegate {
    func didUpdateSound() {
        configureProfile()
    }
}
