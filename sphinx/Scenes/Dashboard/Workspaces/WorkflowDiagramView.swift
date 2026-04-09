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

    private func nodeTypeColor() -> UIColor {
        switch step.nodeType {
        case .automated: return UIColor.Sphinx.PrimaryGreen
        case .human:     return UIColor.Sphinx.PrimaryBlue
        case .api:       return .systemCyan
        case .condition: return .systemOrange
        case .loop:      return .systemPurple
        }
    }

    private func iconAssetName(for nodeType: WorkflowNodeType) -> String {
        switch nodeType {
        case .human: return "human"
        case .api:   return "api"
        default:     return "automated"
        }
    }

    private func typeString(for nodeType: WorkflowNodeType) -> String {
        switch nodeType {
        case .automated: return "Automated"
        case .human:     return "Human"
        case .api:       return "API"
        case .condition: return "Condition"
        case .loop:      return "Loop"
        }
    }

    private func setup() {
        // White background with SecondaryText border
        backgroundColor = .white
        layer.borderWidth = 1.5
        layer.borderColor = UIColor.Sphinx.SecondaryText.cgColor

        if step.nodeType == .condition {
            // Diamond: rotate 45°, equal W×H
            layer.cornerRadius = 4
            transform = CGAffineTransform(rotationAngle: .pi / 4)
        } else {
            layer.cornerRadius = 8
        }

        // Status ring — overrides default border colour
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

        // Build content stack
        let contentStack = buildContentStack()

        // For condition nodes embed content in a counter-rotated host so text stays upright
        if step.nodeType == .condition {
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
                contentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
                contentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
                contentStack.centerYAnchor.constraint(equalTo: centerYAnchor)
            ])
        }
    }

    private func buildContentStack() -> UIStackView {
        let accent = nodeTypeColor()

        // Top row: icon + type label
        let iconImageView = UIImageView()
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.image = UIImage(named: iconAssetName(for: step.nodeType))?.withRenderingMode(.alwaysTemplate)
        iconImageView.tintColor = accent
        NSLayoutConstraint.activate([
            iconImageView.widthAnchor.constraint(equalToConstant: 16),
            iconImageView.heightAnchor.constraint(equalToConstant: 16)
        ])

        let typeLabel = UILabel()
        typeLabel.text = typeString(for: step.nodeType)
        typeLabel.textColor = accent
        typeLabel.font = UIFont(name: "Roboto-Regular", size: 10) ?? UIFont.systemFont(ofSize: 10)
        typeLabel.lineBreakMode = .byTruncatingTail
        typeLabel.numberOfLines = 1

        let topRow = UIStackView(arrangedSubviews: [iconImageView, typeLabel])
        topRow.axis = .horizontal
        topRow.alignment = .center
        topRow.spacing = 4

        // Middle row: alias
        let aliasLabel = UILabel()
        aliasLabel.text = step.displayId ?? step.id
        aliasLabel.textColor = UIColor.Sphinx.SecondaryText
        aliasLabel.font = UIFont(name: "Roboto-Regular", size: 11) ?? UIFont.systemFont(ofSize: 11)
        aliasLabel.numberOfLines = 1
        aliasLabel.lineBreakMode = .byTruncatingTail

        // Bottom row: display name
        let nameLabel = UILabel()
        nameLabel.text = step.displayName ?? step.name
        nameLabel.textColor = UIColor.Sphinx.Text
        nameLabel.font = UIFont(name: "Roboto-Medium", size: 12) ?? UIFont.systemFont(ofSize: 12, weight: .medium)
        nameLabel.textAlignment = .left
        nameLabel.numberOfLines = 2
        nameLabel.lineBreakMode = .byTruncatingTail

        let stack = UIStackView(arrangedSubviews: [topRow, aliasLabel, nameLabel])
        stack.axis = .vertical
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
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

    /// Right-edge midpoint in parent coordinate space (for outgoing edges).
    var rightEdgeMid: CGPoint {
        return CGPoint(x: frame.maxX, y: frame.midY)
    }

    /// Left-edge midpoint in parent coordinate space (for incoming edges).
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
    private var startNodeFrame: CGRect = .zero   // used to centre on START at first layout

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
        scrollView.minimumZoomScale = 0.1
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

    // MARK: - Layout (auto zoom-to-fit on first pass)

    override func layoutSubviews() {
        super.layoutSubviews()
        if !didPerformInitialZoom && canvasView.frame.width > 0 && scrollView.bounds.width > 0 {
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

        // Centre viewport on the START pill
        if startNodeFrame != .zero {
            let scaledStartX = startNodeFrame.midX * scale
            let scaledStartY = startNodeFrame.midY * scale
            let rawOffX = scaledStartX - scrollView.bounds.width  / 2
            let rawOffY = scaledStartY - scrollView.bounds.height / 2
            let maxOffX = max(canvasView.frame.width  * scale - scrollView.bounds.width,  0)
            let maxOffY = max(canvasView.frame.height * scale - scrollView.bounds.height, 0)
            scrollView.contentOffset = CGPoint(
                x: min(max(rawOffX, 0), maxOffX),
                y: min(max(rawOffY, 0), maxOffY)
            )
        } else {
            // Fallback: show full canvas centred
            let offsetX = max((canvasView.frame.width  * scale - scrollView.bounds.width)  / 2, 0)
            let offsetY = max((canvasView.frame.height * scale - scrollView.bounds.height) / 2, 0)
            scrollView.contentOffset = CGPoint(x: offsetX, y: offsetY)
        }
    }

    // MARK: - UIScrollViewDelegate

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return canvasView
    }

    // MARK: - Configure

    func configure(with diagram: WorkflowDiagramData) {
        didPerformInitialZoom = false
        startNodeFrame = .zero

        canvasView.subviews.forEach { $0.removeFromSuperview() }
        edgeLayers.forEach { $0.removeFromSuperlayer() }
        edgeLabels.forEach { $0.removeFromSuperview() }
        edgeLayers.removeAll()
        edgeLabels.removeAll()
        nodeViews.removeAll()

        guard !diagram.steps.isEmpty else { return }

        let hPadding: CGFloat = 60   // horizontal canvas padding
        let vPadding: CGFloat = 100  // vertical canvas padding (extra space top/bottom)
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

            let cx = step.positionX * positionScale + hPadding + w / 2
            let cy = step.positionY * positionScale + vPadding + h / 2

            if step.nodeType == .condition {
                // MUST use bounds + center for rotated views — setting frame is undefined
                nodeView.bounds = CGRect(origin: .zero, size: CGSize(width: w, height: h))
                nodeView.center = CGPoint(x: cx, y: cy)
            } else {
                nodeView.frame = CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h)
            }

            canvasView.addSubview(nodeView)
            nodeViews[key] = nodeView

            let tap = UITapGestureRecognizer(target: self, action: #selector(nodeTapped(_:)))
            nodeView.addGestureRecognizer(tap)
            nodeView.isUserInteractionEnabled = true
        }

        // ---- Compute layout bounds from placed nodes ----
        // Use center-based computation to handle rotated condition nodes correctly
        let allCentersX = nodeViews.values.map { $0.frame.midX }
        let allCentersY = nodeViews.values.map { $0.frame.midY }
        let allNodesMinX = nodeViews.values.map { $0.frame.minX }.min() ?? hPadding
        let allNodesMaxX = nodeViews.values.map { $0.frame.maxX }.max() ?? 400
        let allNodesMinY = allCentersY.min() ?? 0
        let allNodesMaxY = allCentersY.max() ?? 400

        // Terminal nodes are placed relative to the first/last step by midY
        let sortedByX = nodeViews.values.sorted { $0.frame.midX < $1.frame.midX }
        let firstNodeMidY = sortedByX.first?.frame.midY ?? ((allNodesMinY + allNodesMaxY) / 2)
        let lastNodeMidY  = sortedByX.last?.frame.midY  ?? ((allNodesMinY + allNodesMaxY) / 2)

        // ---- Inject terminal nodes ----
        let terminalW: CGFloat = 80
        let terminalH: CGFloat = 32
        let terminalGrey = UIColor.gray

        // START — PrimaryGreen pill, vertically aligned with first step
        let startView = WorkflowTerminalNodeView(text: "START", color: UIColor.Sphinx.PrimaryGreen)
        startView.frame = CGRect(
            x: max(allNodesMinX - terminalW - 20, 4),
            y: firstNodeMidY - terminalH / 2,
            width: terminalW, height: terminalH
        )
        startView.layer.cornerRadius = terminalH / 2
        canvasView.addSubview(startView)
        startNodeFrame = startView.frame  // save for initial centring

        // END — grey pill, vertically aligned with last step
        let endView = WorkflowTerminalNodeView(text: "END", color: terminalGrey)
        endView.frame = CGRect(
            x: allNodesMaxX + 20,
            y: lastNodeMidY - terminalH / 2,
            width: terminalW, height: terminalH
        )
        endView.layer.cornerRadius = terminalH / 2
        canvasView.addSubview(endView)

        // HALTED — grey pill below END
        let haltedView = WorkflowTerminalNodeView(text: "HALTED", color: terminalGrey)
        haltedView.frame = CGRect(
            x: allNodesMaxX + 20,
            y: endView.frame.maxY + 16,
            width: terminalW, height: terminalH
        )
        haltedView.layer.cornerRadius = terminalH / 2
        canvasView.addSubview(haltedView)

        // ---- Expand canvas to fit everything ----
        let canvasMaxX = haltedView.frame.maxX + hPadding
        let canvasMaxY = max(allNodesMaxY + (WorkflowStepNodeView.nodeHeight / 2),
                             haltedView.frame.maxY) + vPadding
        canvasView.frame = CGRect(x: 0, y: 0, width: canvasMaxX, height: canvasMaxY)
        scrollView.contentSize = canvasView.frame.size

        // ---- Draw step-to-step edges ----
        canvasView.layoutIfNeeded()
        drawEdges(diagram: diagram)

        // ---- Draw terminal edges ----
        let edgeColor = UIColor.Sphinx.WashedOutReceivedText.cgColor

        // START → leftmost node
        if let firstNode = sortedByX.first {
            let arrow = makeArrowLayer(
                from: CGPoint(x: startView.frame.maxX, y: startView.frame.midY),
                to: firstNode.leftEdgeMid,
                color: edgeColor
            )
            canvasView.layer.insertSublayer(arrow, at: 0)
            edgeLayers.append(arrow)
        }

        // Rightmost node → END and HALTED
        if let lastNode = sortedByX.last {
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
