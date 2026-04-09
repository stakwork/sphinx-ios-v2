//
//  WorkflowDiagramView.swift
//  sphinx
//
//  Zoomable, pannable workflow diagram canvas.
//

import UIKit

// MARK: - Terminal Node View (START / END / HALTED pills)

private class WorkflowTerminalNodeView: UIView {
    init(text: String, color: UIColor) {
        super.init(frame: .zero)
        backgroundColor = color
        let label = UILabel()
        label.text = text
        label.textColor = .white
        label.font = UIFont(name: "Roboto-Medium", size: 12) ?? UIFont.boldSystemFont(ofSize: 12)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8)
        ])
        isUserInteractionEnabled = false
    }
    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - Node View

private class WorkflowStepNodeView: UIView {
    let step: WorkflowStep

    // Node sizing constants
    static let nodeWidth: CGFloat     = 160
    static let nodeHeight: CGFloat    = 80
    static let conditionSize: CGFloat = 70  // diamond — rotated square

    init(step: WorkflowStep) {
        self.step = step
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Icon asset name helper

    private func iconAssetName(for nodeType: WorkflowNodeType) -> String {
        switch nodeType {
        case .human: return "human"
        case .api:   return "api"
        default:     return "automated"
        }
    }

    // MARK: - Type display string

    private func typeString(for nodeType: WorkflowNodeType) -> String {
        switch nodeType {
        case .automated: return "Automated"
        case .human:     return "Human"
        case .api:       return "API"
        case .condition: return "Condition"
        case .loop:      return "Loop"
        }
    }

    // MARK: - Setup

    private func setup() {
        // Background colour by nodeType
        let bg: UIColor
        switch step.nodeType {
        case .automated: bg = UIColor.Sphinx.PrimaryGreen
        case .human:     bg = UIColor.Sphinx.PrimaryBlue
        case .api:       bg = .systemCyan
        case .condition: bg = .systemOrange
        case .loop:      bg = .systemPurple
        }
        backgroundColor = bg

        if step.nodeType == .condition {
            layer.cornerRadius = 4
            transform = CGAffineTransform(rotationAngle: .pi / 4)
        } else {
            layer.cornerRadius = 8
        }

        // Status ring
        if let state = step.stepState {
            let ringColor: UIColor
            switch state {
            case "finished":    ringColor = .systemGreen
            case "in_progress": ringColor = .systemBlue
            case "error":       ringColor = .systemRed
            case "skipped":     ringColor = .systemGray
            default:            ringColor = .clear
            }
            layer.borderWidth = 2
            layer.borderColor = ringColor.cgColor

            if state == "in_progress" {
                addPulseAnimation()
            }
        }

        // Build the 3-row content stack
        buildContentStack()
    }

    private func buildContentStack() {
        // ---- Top row: icon + type label ----
        let iconImageView = UIImageView()
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.image = UIImage(named: iconAssetName(for: step.nodeType))?.withRenderingMode(.alwaysTemplate)
        iconImageView.tintColor = .white
        NSLayoutConstraint.activate([
            iconImageView.widthAnchor.constraint(equalToConstant: 14),
            iconImageView.heightAnchor.constraint(equalToConstant: 14)
        ])

        let typeLabel = UILabel()
        typeLabel.text = typeString(for: step.nodeType)
        typeLabel.textColor = UIColor.white.withAlphaComponent(0.85)
        typeLabel.font = UIFont(name: "Roboto-Regular", size: 10) ?? UIFont.systemFont(ofSize: 10)
        typeLabel.lineBreakMode = .byTruncatingTail
        typeLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let topRow = UIStackView(arrangedSubviews: [iconImageView, typeLabel])
        topRow.axis = .horizontal
        topRow.alignment = .center
        topRow.spacing = 4

        // ---- Middle row: alias ----
        let aliasLabel = UILabel()
        aliasLabel.text = step.displayId ?? step.id
        aliasLabel.textColor = UIColor.white.withAlphaComponent(0.7)
        aliasLabel.font = UIFont(name: "Roboto-Regular", size: 11) ?? UIFont.systemFont(ofSize: 11)
        aliasLabel.numberOfLines = 1
        aliasLabel.lineBreakMode = .byTruncatingTail

        // ---- Bottom row: display name ----
        let nameLabel = UILabel()
        nameLabel.text = step.displayName ?? step.name
        nameLabel.textColor = .white
        nameLabel.font = UIFont(name: "Roboto-Medium", size: 12) ?? UIFont.systemFont(ofSize: 12, weight: .medium)
        nameLabel.numberOfLines = 2
        nameLabel.lineBreakMode = .byTruncatingTail

        // ---- Compose vertical stack ----
        let contentStack = UIStackView(arrangedSubviews: [topRow, aliasLabel, nameLabel])
        contentStack.axis = .vertical
        contentStack.spacing = 2
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        if step.nodeType == .condition {
            // Embed in counter-rotated host so text is upright
            let labelHost = UIView()
            labelHost.translatesAutoresizingMaskIntoConstraints = false
            labelHost.transform = CGAffineTransform(rotationAngle: -.pi / 4)
            labelHost.isUserInteractionEnabled = false
            addSubview(labelHost)
            labelHost.addSubview(contentStack)
            NSLayoutConstraint.activate([
                labelHost.centerXAnchor.constraint(equalTo: centerXAnchor),
                labelHost.centerYAnchor.constraint(equalTo: centerYAnchor),
                labelHost.widthAnchor.constraint(equalTo: widthAnchor),
                labelHost.heightAnchor.constraint(equalTo: heightAnchor),
                contentStack.leadingAnchor.constraint(equalTo: labelHost.leadingAnchor, constant: 6),
                contentStack.trailingAnchor.constraint(equalTo: labelHost.trailingAnchor, constant: -6),
                contentStack.centerYAnchor.constraint(equalTo: labelHost.centerYAnchor)
            ])
        } else {
            addSubview(contentStack)
            NSLayoutConstraint.activate([
                contentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
                contentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
                contentStack.centerYAnchor.constraint(equalTo: centerYAnchor)
            ])
        }
    }

    private func addPulseAnimation() {
        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 1.0
        pulse.toValue   = 0.5
        pulse.duration  = 0.8
        pulse.autoreverses = true
        pulse.repeatCount  = .infinity
        layer.add(pulse, forKey: "pulse")
    }

    // MARK: - Edge connection points

    var rightEdgeMid: CGPoint {
        return CGPoint(x: frame.maxX, y: frame.midY)
    }

    var leftEdgeMid: CGPoint {
        return CGPoint(x: frame.minX, y: frame.midY)
    }
}

// MARK: - Diagram View

class WorkflowDiagramView: UIView, UIScrollViewDelegate {

    // MARK: Public API
    var onStepTapped: ((WorkflowStep) -> Void)?

    // MARK: Private
    private let scrollView  = UIScrollView()
    private let canvasView  = UIView()
    private var nodeViews: [String: WorkflowStepNodeView] = [:]
    private var edgeLayers: [CAShapeLayer] = []
    private var edgeLabels: [UILabel] = []
    private var didPerformInitialZoom = false

    // MARK: Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = UIColor.Sphinx.Body

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.minimumZoomScale = 0.2
        scrollView.maximumZoomScale = 3.0
        scrollView.showsHorizontalScrollIndicator = true
        scrollView.showsVerticalScrollIndicator   = true
        scrollView.delegate = self
        scrollView.backgroundColor = .clear
        addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        canvasView.backgroundColor = .clear
        scrollView.addSubview(canvasView)
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        if !didPerformInitialZoom && canvasView.frame.width > 0 {
            didPerformInitialZoom = true
            zoomToFit()
        }
    }

    private func zoomToFit() {
        guard scrollView.bounds.width > 0, scrollView.bounds.height > 0,
              canvasView.frame.width > 0, canvasView.frame.height > 0 else { return }
        let scaleX = scrollView.bounds.width  / canvasView.frame.width
        let scaleY = scrollView.bounds.height / canvasView.frame.height
        let scale  = max(min(scaleX, scaleY), scrollView.minimumZoomScale)
        scrollView.setZoomScale(scale, animated: false)
        let offsetX = max((canvasView.frame.width  * scale - scrollView.bounds.width)  / 2, 0)
        let offsetY = max((canvasView.frame.height * scale - scrollView.bounds.height) / 2, 0)
        scrollView.contentOffset = CGPoint(x: offsetX, y: offsetY)
    }

    // MARK: - UIScrollViewDelegate

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return canvasView
    }

    // MARK: - Configure

    func configure(with diagram: WorkflowDiagramData) {
        // Reset zoom trigger so new diagram auto-fits
        didPerformInitialZoom = false

        // Clear previous content
        canvasView.subviews.forEach { $0.removeFromSuperview() }
        edgeLayers.forEach { $0.removeFromSuperlayer() }
        edgeLabels.forEach { $0.removeFromSuperview() }
        edgeLayers.removeAll()
        edgeLabels.removeAll()
        nodeViews.removeAll()

        guard !diagram.steps.isEmpty else { return }

        let padding: CGFloat = 60
        let positionScale: CGFloat = 0.5

        // ---- Place node views ----
        for (key, step) in diagram.steps {
            let nodeView = WorkflowStepNodeView(step: step)

            let w: CGFloat = step.nodeType == .condition
                ? WorkflowStepNodeView.conditionSize
                : WorkflowStepNodeView.nodeWidth
            let h: CGFloat = step.nodeType == .condition
                ? WorkflowStepNodeView.conditionSize
                : WorkflowStepNodeView.nodeHeight

            nodeView.frame = CGRect(
                x: step.positionX * positionScale + padding,
                y: step.positionY * positionScale + padding,
                width: w,
                height: h
            )

            canvasView.addSubview(nodeView)
            nodeViews[key] = nodeView

            let tap = UITapGestureRecognizer(target: self, action: #selector(nodeTapped(_:)))
            nodeView.addGestureRecognizer(tap)
            nodeView.isUserInteractionEnabled = true
        }

        // ---- Compute bounds of step nodes ----
        let allMinX   = nodeViews.values.map { $0.frame.minX }.min() ?? padding
        let allMidY   = ((nodeViews.values.map { $0.frame.minY }.min() ?? 0) +
                         (nodeViews.values.map { $0.frame.maxY }.max() ?? 0)) / 2
        let allMaxX   = nodeViews.values.map { $0.frame.maxX }.max() ?? 400
        var maxY      = (nodeViews.values.map { $0.frame.maxY }.max() ?? 400)

        // ---- Terminal nodes ----
        let terminalW: CGFloat = 80
        let terminalH: CGFloat = 32

        // START
        let startView = WorkflowTerminalNodeView(text: "START", color: UIColor.darkGray)
        let startX = max(allMinX - terminalW - 24, 4)
        startView.frame = CGRect(x: startX,
                                 y: allMidY - terminalH / 2,
                                 width: terminalW, height: terminalH)
        startView.layer.cornerRadius = terminalH / 2
        canvasView.addSubview(startView)

        // END
        let endView = WorkflowTerminalNodeView(text: "END", color: UIColor.Sphinx.PrimaryGreen)
        endView.frame = CGRect(x: allMaxX + 24,
                               y: allMidY - terminalH / 2 - (terminalH / 2 + 8),
                               width: terminalW, height: terminalH)
        endView.layer.cornerRadius = terminalH / 2
        canvasView.addSubview(endView)

        // HALTED
        let haltedView = WorkflowTerminalNodeView(text: "HALTED", color: UIColor.Sphinx.SphinxOrange)
        haltedView.frame = CGRect(x: allMaxX + 24,
                                  y: endView.frame.maxY + 16,
                                  width: terminalW, height: terminalH)
        haltedView.layer.cornerRadius = terminalH / 2
        canvasView.addSubview(haltedView)

        // ---- Expand canvas to fit terminal nodes ----
        let expandedMaxX = haltedView.frame.maxX + padding
        maxY = max(maxY, haltedView.frame.maxY)
        let expandedMaxY = maxY + padding

        canvasView.frame = CGRect(x: 0, y: 0, width: expandedMaxX, height: expandedMaxY)
        scrollView.contentSize = canvasView.frame.size

        // ---- Draw step edges ----
        canvasView.layoutIfNeeded()
        drawEdges(diagram: diagram)

        // ---- Draw terminal arrows ----
        let edgeColor = UIColor.Sphinx.WashedOutReceivedText.cgColor

        // START → first node (smallest minX)
        if let firstNode = nodeViews.values.min(by: { $0.frame.minX < $1.frame.minX }) {
            let arrow = makeArrowLayer(
                from: CGPoint(x: startView.frame.maxX, y: startView.frame.midY),
                to: firstNode.leftEdgeMid,
                color: edgeColor
            )
            canvasView.layer.insertSublayer(arrow, at: 0)
            edgeLayers.append(arrow)
        }

        // Last node(s) → END and HALTED (largest maxX)
        if let lastNode = nodeViews.values.max(by: { $0.frame.maxX < $1.frame.maxX }) {
            for termView in [endView, haltedView] {
                let arrow = makeArrowLayer(
                    from: lastNode.rightEdgeMid,
                    to: CGPoint(x: termView.frame.minX, y: termView.frame.midY),
                    color: edgeColor
                )
                canvasView.layer.insertSublayer(arrow, at: 0)
                edgeLayers.append(arrow)
            }
        }
    }

    private func drawEdges(diagram: WorkflowDiagramData) {
        let edgeColor = UIColor.Sphinx.WashedOutReceivedText.cgColor

        for edge in diagram.edges {
            guard let fromNode = nodeViews[edge.fromId],
                  let toNode   = nodeViews[edge.toId] else { continue }

            let start = fromNode.rightEdgeMid
            let end   = toNode.leftEdgeMid

            let layer = makeArrowLayer(from: start, to: end, color: edgeColor)
            canvasView.layer.insertSublayer(layer, at: 0)
            edgeLayers.append(layer)

            // Branch label
            if let label = edge.label, !label.isEmpty {
                let lbl = UILabel()
                lbl.text = label
                lbl.font = UIFont(name: "Roboto-Regular", size: 10) ?? UIFont.systemFont(ofSize: 10)
                lbl.textColor = UIColor.Sphinx.SecondaryText
                lbl.sizeToFit()
                let midX = (start.x + end.x) / 2 - lbl.frame.width / 2
                let midY = (start.y + end.y) / 2 - lbl.frame.height - 2
                lbl.frame.origin = CGPoint(x: midX, y: midY)
                canvasView.addSubview(lbl)
                edgeLabels.append(lbl)
            }
        }
    }

    // MARK: - Arrow layer

    private func makeArrowLayer(from start: CGPoint, to end: CGPoint, color: CGColor) -> CAShapeLayer {
        let path = UIBezierPath()
        let midX = (start.x + end.x) / 2
        path.move(to: start)
        path.addCurve(
            to: end,
            controlPoint1: CGPoint(x: midX, y: start.y),
            controlPoint2: CGPoint(x: midX, y: end.y)
        )

        let dx = end.x - start.x
        let dy = end.y - start.y
        let angle = atan2(dy, dx)
        let arrowLength: CGFloat = 8
        let arrowAngle: CGFloat  = .pi / 6

        let p1 = CGPoint(
            x: end.x - arrowLength * cos(angle - arrowAngle),
            y: end.y - arrowLength * sin(angle - arrowAngle)
        )
        let p2 = CGPoint(
            x: end.x - arrowLength * cos(angle + arrowAngle),
            y: end.y - arrowLength * sin(angle + arrowAngle)
        )
        path.move(to: end)
        path.addLine(to: p1)
        path.move(to: end)
        path.addLine(to: p2)

        let layer = CAShapeLayer()
        layer.path        = path.cgPath
        layer.strokeColor = color
        layer.fillColor   = UIColor.clear.cgColor
        layer.lineWidth   = 1.5
        layer.lineCap     = .round
        return layer
    }

    // MARK: - Tap

    @objc private func nodeTapped(_ gesture: UITapGestureRecognizer) {
        guard let nodeView = gesture.view as? WorkflowStepNodeView else { return }
        onStepTapped?(nodeView.step)
    }
}
