//
//  UITapGestureRecognizer.swift
//  sphinx
//
//  Created by Tomas Timinskas on 06/01/2020.
//  Copyright © 2020 Sphinx. All rights reserved.
//

import UIKit

extension UITapGestureRecognizer {
    func didTapAttributedTextInLabel(
        _ label: UILabel,
        inRange targetRange: NSRange
    ) -> Bool {
        guard let attributedString = label.attributedText else { return false }
        
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: CGSize.zero)
        
        let mutableAttribString = NSMutableAttributedString(attributedString: attributedString)
        let textStorage = NSTextStorage(attributedString: mutableAttribString)

        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)

        textContainer.lineFragmentPadding = 0.0
        textContainer.lineBreakMode = label.lineBreakMode
        textContainer.maximumNumberOfLines = label.numberOfLines
        let labelSize = label.bounds.size
        textContainer.size = labelSize

        let locationOfTouchInLabel = self.location(in: label)
        let textBoundingBox = layoutManager.usedRect(for: textContainer)

        let textContainerOffset = CGPoint(
            x: (labelSize.width - textBoundingBox.size.width) * 0.5 - textBoundingBox.origin.x,
            y: (labelSize.height - textBoundingBox.size.height) * 0.5 - textBoundingBox.origin.y
        )

        let locationOfTouchInTextContainer = CGPoint(
            x: locationOfTouchInLabel.x - textContainerOffset.x,
            y: locationOfTouchInLabel.y - textContainerOffset.y
        )
        
        let indexOfCharacter = layoutManager.characterIndex(
            for: locationOfTouchInTextContainer,
            in: textContainer,
            fractionOfDistanceBetweenInsertionPoints: nil
        )
        
        return NSLocationInRange(indexOfCharacter, targetRange)
    }
}
