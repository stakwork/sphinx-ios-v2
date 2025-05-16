//
//  ChatMessageTextFieldView+UITextViewDelegate.swift
//  sphinx
//
//  Created by Tomas Timinskas on 11/05/2023.
//  Copyright © 2023 sphinx. All rights reserved.
//

import UIKit

extension ChatMessageTextFieldView : UITextViewDelegate {
    
    var placeHolderText : String {
        get {
            switch(mode) {
            case .Chat:
                return kFieldPlaceHolder
            case .Attachment:
                return kAttchmentFieldPlaceHolder
            }
        }
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        togglePlaceHolder(editing: true)
        textViewDidChange(textView)
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        togglePlaceHolder(editing: false)
    }
    
    func togglePlaceHolder(editing: Bool) {
        if editing && (textView.text == placeHolderText) {
            textView.text = ""
            textView.textColor = UIColor.Sphinx.TextMessages
        } else if !editing && textView.text.isEmpty {
            textView.text = placeHolderText
            textView.textColor = kFieldPlaceHolderColor
        }
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        let currentString = textView.text! as NSString
        let currentChangedString = currentString.replacingCharacters(in: range, with: text)
        
        return delegate?.isMessageLengthValid?(
            text: currentChangedString,
            sendingAttachment: mode == .Attachment
        ) ?? true
    }
    
    func textViewDidChange(_ textView: UITextView) {
        animateElements(sendButtonVisible: !textView.text.isEmpty && textView.text != kFieldPlaceHolder)
        
        delegate?.didChangeText?(
            text: textView.text != kFieldPlaceHolder ? textView.text : ""
        )
        
        adjustTextViewHeight()
        
        let string = textView.text ?? ""
        let cursorPosition = textView.selectedRange.location
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.processMention(text: string, cursorPosition: cursorPosition)
            self.processMacro(text: string, cursorPosition: cursorPosition)
        }
    }
    
    func adjustTextViewHeight() {
        if textView.contentSize.height > 250 {
            if !textView.isScrollEnabled {
                textViewHeightConstraint?.isActive = false
                textViewHeightConstraint = textView.heightAnchor.constraint(equalToConstant: 250)
                textViewHeightConstraint?.isActive = true
                textView.isScrollEnabled = true
            }
        } else if textView.contentSize.height < 250 {
            if textView.isScrollEnabled {
                textViewHeightConstraint?.isActive = false
                textView.isScrollEnabled = false
                textView.invalidateIntrinsicContentSize()
            }
        }
    }
    
    func animateElements(
        sendButtonVisible: Bool
    ) {
        let forceSendButtonVisible = sendButtonVisible || (mode == .Attachment)
        
        attachmentButton.backgroundColor = forceSendButtonVisible ? UIColor.Sphinx.ReceivedMsgBG : UIColor.Sphinx.PrimaryBlue
        attachmentButton.setTitleColor(forceSendButtonVisible ? UIColor.Sphinx.MainBottomIcons : UIColor.white, for: .normal)
        
        sendButtonContainer.isHidden = !forceSendButtonVisible
        audioButtonContainer.isHidden = forceSendButtonVisible
        
        attachmentButtonContainer.isHidden = (mode == .Attachment)
    }
}

///Mentions
extension ChatMessageTextFieldView {
    
    func getAtMention(
        text: String,
        cursorPosition: Int
    ) -> String? {
        
        if text.trim().isEmpty {
            return nil
        }
        
        let relevantText = text[0..<cursorPosition]
        
        if let lastLetter = relevantText.last, lastLetter == " " {
            return nil
        }
        
        if let lastLine = relevantText.split(separator: "\n").last,
           let lastWord = lastLine.split(separator: " ").last {
            
            if let firstLetter = lastWord.first, firstLetter == "@" && lastWord != "@" {
                return String(lastWord)
            }
        }
        
        return nil
    }
    
    func populateMentionAutocomplete(
        mention: String
    ) {
        if let text = textView.text {
            let cursorPosition = textView.selectedRange.location
            
            if let typedMentionText = getAtMention(text: text, cursorPosition: cursorPosition) {
                
                let startIndex = text.index(text.startIndex, offsetBy: cursorPosition - typedMentionText.count)
                let safeOffset = min(text.count, cursorPosition)
                let endIndex = text.index(text.startIndex, offsetBy: safeOffset)
                
                textView.text = textView.text.replacingOccurrences(
                    of: typedMentionText,
                    with: "@\(mention) ",
                    options: [],
                    range: startIndex..<endIndex
                )
                

                let position = cursorPosition + (("@\(mention) ".count - typedMentionText.count))
                textView.selectedRange = NSRange(location: position, length: 0)
                
                textViewDidChange(textView)
            }
        }
    }
    
    func processMention(
        text: String,
        cursorPosition: Int
    ) {
        if let mention = getAtMention(text: text, cursorPosition: cursorPosition) {
            let mentionValue = String(mention).replacingOccurrences(of: "@", with: "").lowercased()
            self.delegate?.didDetectPossibleMention(mentionText: mentionValue)
        } else {
            self.delegate?.didDetectPossibleMention(mentionText: "")
        }
    }
    
    func getMacro(
        text: String,
        cursorPosition: Int?
    ) -> String? {
        let relevantText = text[0..<(cursorPosition ?? text.count)]
        
        if let firstLetter = relevantText.first, firstLetter == "/" {
            return relevantText
        }

        return nil
    }
    
    func processMacro(
        text: String,
        cursorPosition: Int?
    ) {
        if let macroText = getMacro(text: text, cursorPosition: cursorPosition) {
            self.delegate?.didDetectPossibleMacro(macro: macroText)
        }
    }
}
