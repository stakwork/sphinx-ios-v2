//
//  MarkdownTextView.swift
//  sphinx
//
//  UIViewRepresentable wrapping a non-editable UITextView for rendering
//  NSAttributedString markdown content with tappable link support.
//

import SwiftUI
import UIKit

struct MarkdownTextView: UIViewRepresentable {

    let attributedText: NSAttributedString

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.dataDetectorTypes = []
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.delegate = context.coordinator
        textView.linkTextAttributes = [
            .foregroundColor: UIColor.Sphinx.PrimaryBlue,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.attributedText = attributedText
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UITextViewDelegate {

        func textView(
            _ textView: UITextView,
            shouldInteractWith url: URL,
            in characterRange: NSRange,
            interaction: UITextItemInteraction
        ) -> Bool {
            let urlString = url.absoluteString
            if urlString.isHivePlanLink || urlString.isHiveTaskLink {
                if let topVC = UIApplication.shared.topMostViewController() {
                    HiveLinkNavigator.navigate(hiveLink: urlString, from: topVC)
                }
            } else {
                UIApplication.shared.open(url)
            }
            return false
        }
    }
}
