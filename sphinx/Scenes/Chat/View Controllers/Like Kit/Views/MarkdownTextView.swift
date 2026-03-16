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
        // Allow the text view to shrink-wrap its content instead of expanding to fill available width
        textView.setContentHuggingPriority(.required, for: .horizontal)
        textView.setContentHuggingPriority(.required, for: .vertical)
        textView.setContentCompressionResistancePriority(.required, for: .vertical)
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.attributedText = attributedText
    }

    // Provide an intrinsic size so SwiftUI wraps the view tightly around the text
    @available(iOS 16.0, *)
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? UIScreen.main.bounds.width
        let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return size
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
