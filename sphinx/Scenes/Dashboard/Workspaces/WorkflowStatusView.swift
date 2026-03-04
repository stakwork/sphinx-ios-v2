//
//  WorkflowStatusView.swift
//  sphinx
//
//  Created on 2025-03-04.
//  Copyright © 2025 sphinx. All rights reserved.
//

import UIKit

class WorkflowStatusView: UIView {

    // MARK: - Subviews

    private let stackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.alignment = .center
        sv.spacing = 8
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    /// Circle indicator (used for PENDING, IN_PROGRESS, COMPLETED)
    private let circleView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.layer.cornerRadius = 4
        v.clipsToBounds = false          // allow ring to overflow
        return v
    }()

    /// Pulsing ring layer (IN_PROGRESS only)
    private var pulseLayer: CAShapeLayer?

    /// Icon indicator (ERROR, HALTED, FAILED)
    private let iconView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        iv.widthAnchor.constraint(equalToConstant: 16).isActive = true
        iv.heightAnchor.constraint(equalToConstant: 16).isActive = true
        return iv
    }()

    private let statusLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = UIFont(name: "Roboto-Regular", size: 12) ?? UIFont.systemFont(ofSize: 12)
        lbl.textColor = UIColor.Sphinx.SecondaryText
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()

    // MARK: - State

    var status: WorkflowStatus = .PENDING {
        didSet { updateAppearance() }
    }

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    // MARK: - Setup

    private func setupView() {
        isHidden = true
        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false

        addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        // Circle fixed size
        NSLayoutConstraint.activate([
            circleView.widthAnchor.constraint(equalToConstant: 8),
            circleView.heightAnchor.constraint(equalToConstant: 8)
        ])

        stackView.addArrangedSubview(circleView)
        stackView.addArrangedSubview(iconView)
        stackView.addArrangedSubview(statusLabel)

        updateAppearance()
    }

    // MARK: - Appearance

    private func updateAppearance() {
        removePulseAnimation()

        switch status {
        case .PENDING:
            showCircle(color: UIColor.lightGray)
            hideIcon()
            statusLabel.text = nil
            statusLabel.isHidden = true

        case .IN_PROGRESS:
            showCircle(color: UIColor.Sphinx.PrimaryBlue)
            hideIcon()
            statusLabel.text = "Working…"
            statusLabel.isHidden = false
            addPulseAnimation()

        case .COMPLETED:
            showCircle(color: UIColor.Sphinx.PrimaryGreen)
            hideIcon()
            statusLabel.text = nil
            statusLabel.isHidden = true

        case .ERROR:
            hideCircle()
            showIcon(systemName: "exclamationmark.circle.fill", color: UIColor.Sphinx.SphinxOrange)
            statusLabel.text = "Error"
            statusLabel.isHidden = false

        case .HALTED:
            hideCircle()
            showIcon(systemName: "pause.circle.fill", color: UIColor.Sphinx.SphinxOrange)
            statusLabel.text = "Halted"
            statusLabel.isHidden = false

        case .FAILED:
            hideCircle()
            showIcon(systemName: "xmark.circle.fill", color: UIColor.Sphinx.SphinxOrange)
            statusLabel.text = "Failed"
            statusLabel.isHidden = false
        }
    }

    private func showCircle(color: UIColor) {
        circleView.isHidden = false
        circleView.backgroundColor = color
        circleView.layer.cornerRadius = 4
    }

    private func hideCircle() {
        circleView.isHidden = true
    }

    private func showIcon(systemName: String, color: UIColor) {
        iconView.isHidden = false
        iconView.image = UIImage(systemName: systemName)
        iconView.tintColor = color
    }

    private func hideIcon() {
        iconView.isHidden = true
    }

    // MARK: - Pulse Animation

    private func addPulseAnimation() {
        removePulseAnimation()

        let ring = CAShapeLayer()
        let diameter: CGFloat = 8
        let path = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: diameter, height: diameter))
        ring.path = path.cgPath
        ring.fillColor = UIColor.Sphinx.PrimaryBlue.cgColor
        ring.opacity = 1

        // Centre the ring on the circleView
        ring.frame = circleView.bounds
        circleView.layer.addSublayer(ring)
        pulseLayer = ring

        let scaleAnim = CABasicAnimation(keyPath: "transform.scale")
        scaleAnim.fromValue = 1.0
        scaleAnim.toValue = 1.5

        let opacityAnim = CABasicAnimation(keyPath: "opacity")
        opacityAnim.fromValue = 1.0
        opacityAnim.toValue = 0.0

        let group = CAAnimationGroup()
        group.animations = [scaleAnim, opacityAnim]
        group.duration = 1.5
        group.repeatCount = .infinity
        group.isRemovedOnCompletion = false

        ring.add(group, forKey: "pulse")
    }

    private func removePulseAnimation() {
        pulseLayer?.removeAllAnimations()
        pulseLayer?.removeFromSuperlayer()
        pulseLayer = nil
    }

    // MARK: - Show / Hide

    func show(animated: Bool) {
        guard isHidden else { return }
        if animated {
            alpha = 0
            isHidden = false
            UIView.animate(withDuration: 0.2) { self.alpha = 1 }
        } else {
            alpha = 1
            isHidden = false
        }
    }

    func hide(animated: Bool) {
        guard !isHidden else { return }
        if animated {
            UIView.animate(withDuration: 0.2, animations: {
                self.alpha = 0
            }, completion: { _ in
                self.isHidden = true
                self.alpha = 1
            })
        } else {
            isHidden = true
        }
    }
}
