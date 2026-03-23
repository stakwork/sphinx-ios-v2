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

    /// Outer vertical stack (topRowStack + detailLabel)
    private let outerStackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.alignment = .leading
        sv.spacing = 2
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    /// Top row: circle / icon / label / retry
    private let topRowStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.alignment = .center
        sv.spacing = 4
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    /// Second line — real-time agent activity detail
    private let detailLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = UIFont(name: "Roboto-Regular", size: 11) ?? UIFont.systemFont(ofSize: 11)
        lbl.textColor = UIColor.Sphinx.SecondaryText
        lbl.numberOfLines = 1
        lbl.lineBreakMode = .byTruncatingTail
        lbl.isHidden = true
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()
    
    private let circleContainerView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.clipsToBounds = false          // allow ring to overflow
        return v
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

    private let retryButton: UIButton = {
        let btn = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        btn.setImage(UIImage(systemName: "arrow.counterclockwise.circle.fill", withConfiguration: config), for: .normal)
        btn.tintColor = UIColor.Sphinx.SphinxOrange
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.widthAnchor.constraint(equalToConstant: 20).isActive = true
        btn.heightAnchor.constraint(equalToConstant: 20).isActive = true
        btn.isHidden = true
        return btn
    }()

    // MARK: - Callbacks

    var onRetryTapped: (() -> Void)?

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

        addSubview(outerStackView)
        // top/bottom pin the stack so it expands the view when a second line appears.
        // The bottomAnchor uses .defaultHigh (< required) so the height=0 "hidden" state
        // from the VC's height constraint can win without an unsatisfiable-constraint warning.
        let bottomPin = outerStackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        bottomPin.priority = .defaultHigh
        NSLayoutConstraint.activate([
            outerStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            outerStackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16),
            outerStackView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            bottomPin
        ])

        // Circle fixed size
        NSLayoutConstraint.activate([
            circleView.widthAnchor.constraint(equalToConstant: 8),
            circleView.heightAnchor.constraint(equalToConstant: 8)
        ])
        
        NSLayoutConstraint.activate([
            circleContainerView.widthAnchor.constraint(equalToConstant: 14),
            circleContainerView.heightAnchor.constraint(equalToConstant: 14)
        ])
        
        circleContainerView.addSubview(circleView)
        
        circleContainerView.centerYAnchor.constraint(equalTo: circleView.centerYAnchor).isActive = true
        circleContainerView.centerXAnchor.constraint(equalTo: circleView.centerXAnchor).isActive = true

        topRowStack.addArrangedSubview(circleContainerView)
        topRowStack.addArrangedSubview(iconView)
        topRowStack.addArrangedSubview(statusLabel)
        topRowStack.addArrangedSubview(retryButton)

        outerStackView.addArrangedSubview(topRowStack)
        outerStackView.addArrangedSubview(detailLabel)

        retryButton.addTarget(self, action: #selector(retryButtonTapped), for: .touchUpInside)

        updateAppearance()
    }

    // MARK: - Appearance

    private func updateAppearance() {
        removePulseAnimation()

        retryButton.isHidden = (status != .HALTED)

        switch status {
        case .PENDING:
            hideCircle()
            hideIcon()
            statusLabel.isHidden = true
            clearDetailLabel()

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
            clearDetailLabel()

        case .ERROR:
            hideCircle()
            showIcon(systemName: "exclamationmark.circle.fill", color: UIColor.Sphinx.SphinxOrange)
            statusLabel.text = "Error"
            statusLabel.isHidden = false
            clearDetailLabel()

        case .HALTED:
            hideCircle()
            showIcon(systemName: "pause.circle.fill", color: UIColor.Sphinx.SphinxOrange)
            statusLabel.text = "Halted"
            statusLabel.isHidden = false
            clearDetailLabel()

        case .FAILED:
            hideCircle()
            showIcon(systemName: "xmark.circle.fill", color: UIColor.Sphinx.SphinxOrange)
            statusLabel.text = "Failed"
            statusLabel.isHidden = false
            clearDetailLabel()
        }
    }

    // MARK: - Status / Detail Text

    /// Whether the second-line detail label is currently visible.
    var hasDetailText: Bool { !detailLabel.isHidden }

    /// Unconditionally hides and clears the detail label (used on terminal states).
    private func clearDetailLabel() {
        detailLabel.isHidden = true
        detailLabel.text = nil
        detailLabel.layer.removeAnimation(forKey: "detailPulse")
    }

    /// Update the first-line status label (e.g. from `workflowStepTextReceived`).
    /// Falls back to "Working…" when `text` is nil. Only effective while IN_PROGRESS.
    func setStatusText(_ text: String?) {
        guard status == .IN_PROGRESS else { return }
        statusLabel.text = text ?? "Working…"
    }

    /// Show real-time agent activity on the second line below the status label.
    /// Only shown while IN_PROGRESS; passing nil hides the label and clears its text.
    func setStepDetail(_ text: String?) {
        guard let text = text, status == .IN_PROGRESS else {
            detailLabel.isHidden = true
            detailLabel.text = nil
            detailLabel.layer.removeAnimation(forKey: "detailPulse")
            return
        }
        detailLabel.text = text
        detailLabel.isHidden = false
        let anim = CABasicAnimation(keyPath: "opacity")
        anim.fromValue = 0.6
        anim.toValue = 1.0
        anim.duration = 0.8
        anim.repeatCount = .infinity
        anim.autoreverses = true
        detailLabel.layer.add(anim, forKey: "detailPulse")
    }

    @objc private func retryButtonTapped() {
        onRetryTapped?()
    }

    private func showCircle(color: UIColor) {
        circleContainerView.isHidden = false
        circleView.backgroundColor = color
        circleView.layer.cornerRadius = 4
    }

    private func hideCircle() {
        circleContainerView.isHidden = true
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

        // Centre the ring on the circleView using the fixed known size
        let dotSize: CGFloat = 8
        ring.frame = CGRect(x: 0, y: 0, width: dotSize, height: dotSize)
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

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        if let pulseLayer = pulseLayer {
            let dotSize: CGFloat = 8
            pulseLayer.frame = CGRect(x: 0, y: 0, width: dotSize, height: dotSize)
        }
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
