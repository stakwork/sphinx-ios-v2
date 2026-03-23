//
//  SphinxToggleView.swift
//  sphinx
//
//  Created on 2025-03-22.
//  Copyright © 2025 sphinx. All rights reserved.
//

import UIKit

/// Compact 28×16 pt custom toggle styled with Sphinx brand colours.
final class SphinxToggleView: UIControl {

    var isOn: Bool = false {
        didSet { guard oldValue != isOn else { return }; updateAppearance(animated: true) }
    }

    override var isEnabled: Bool {
        didSet { alpha = isEnabled ? 1.0 : 0.4 }
    }

    private let trackLayer = CALayer()
    private let thumbLayer = CALayer()

    private let trackW: CGFloat = 58
    private let trackH: CGFloat = 33
    private let thumbDiameter: CGFloat = 27
    private let thumbInset: CGFloat = 3

    override init(frame: CGRect) { super.init(frame: frame); commonInit() }
    required init?(coder: NSCoder) { super.init(coder: coder); commonInit() }

    private func commonInit() {
        backgroundColor = .clear

        trackLayer.cornerRadius = trackH / 2
        layer.addSublayer(trackLayer)

        thumbLayer.cornerRadius = thumbDiameter / 2
        thumbLayer.backgroundColor = UIColor.white.cgColor
        thumbLayer.shadowColor = UIColor.black.cgColor
        thumbLayer.shadowOpacity = 0.15
        thumbLayer.shadowRadius = 1
        thumbLayer.shadowOffset = CGSize(width: 0, height: 1)
        layer.addSublayer(thumbLayer)

        updateAppearance(animated: false)

        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
    }

    @objc private func handleTap() {
        isOn.toggle()
        sendActions(for: .valueChanged)
    }

    private func updateAppearance(animated: Bool) {
        let onColor  = UIColor.Sphinx.PrimaryGreen.cgColor
        let offColor = UIColor.Sphinx.LightDivider.cgColor
        let thumbX   = isOn
            ? trackW - thumbInset - thumbDiameter
            : thumbInset
        let thumbFrame = CGRect(x: thumbX,
                                y: (trackH - thumbDiameter) / 2,
                                width: thumbDiameter,
                                height: thumbDiameter)
        if animated {
            UIView.animate(withDuration: 0.2) {
                self.trackLayer.backgroundColor = self.isOn ? onColor : offColor
                self.thumbLayer.frame = thumbFrame
            }
        } else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            trackLayer.backgroundColor = isOn ? onColor : offColor
            thumbLayer.frame = thumbFrame
            CATransaction.commit()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        trackLayer.frame = CGRect(x: 0, y: (bounds.height - trackH) / 2,
                                  width: trackW, height: trackH)
        updateAppearance(animated: false)
    }

    override var intrinsicContentSize: CGSize { CGSize(width: 58, height: 33) }
}
