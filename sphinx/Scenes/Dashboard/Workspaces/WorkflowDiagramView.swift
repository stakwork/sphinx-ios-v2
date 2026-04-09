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

    // Node sizing
    static let nodeWidth: CGFloat      = 160
    static let nodeHeight: CGFloat     = 80
    static let conditionWidth: CGFloat = 90   // diamond bounding-box width
    static let conditionHeight: CGFloat = 70  // diamond bounding-box height

    // Diamond shape layer (condition only)
    private var diamondLayer: CAShapeLayer?

    init(step: WorkflowStep) {
        self.step = step
        super.init(frame: .zero)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: Helpers

    private func nodeTypeColor() -> UIColor {
        switch step.nodeType {
        case .automated: return UIColor.Sphinx.PrimaryGreen
        case .human:     return UIColor.Sphinx.PrimaryBlue
        case .api:       return .systemCyan
        case .condition: return .systemOrange
        case .loop:      return .systemPurple
        }
    }

    private func iconAssetName(for type: WorkflowNodeType) -> String {
        switch type {
        case .human: return "human"
        case .api:   return "api"
        default:     return "automated"
        }
    }

    private func typeString(for type: WorkflowNodeType) -> String {
        switch type {
        case .automated: return "Automated"
        case .human:     return "Human"
        case .api:       return "API"
        case .condition: return "Condition"
        case .loop:      return "Loop"
        }
    }

    // MARK: Setup

    private func setup() {
        // NO transform is ever applied to WorkflowStepNodeView — keeps frame-based layout sane.

        if step.nodeType == .condition {
            setupConditionNode()
        } else {
            setupRegularNode()
        }

        // Status ring (on top of any existing border)
        if let state = step.stepState {
            let ringColor: UIColor
            switch state {
            case "finished":    ringColor = .systemGreen
            case "in_progress": ringColor = .systemBlue
            case "error":       ringColor = .systemRed
            case "skipped":     ringColor = .systemGray
            default:            ringColor = .clear
            }
            if ringColor != .clear {
                layer.borderWidth = 2
                layer.borderColor = ringColor.cgColor
                if state == "in_progress" { addPulseAnimation() }
            }
        }
    }

    // MARK: Regular node

    private func setupRegularNode() {
        backgroundColor = .white
        layer.cornerRadius = 8
        layer.borderWidth  = 1.5
        layer.borderColor  = UIColor.Sphinx.SecondaryText.cgColor

        let accent = nodeTypeColor()

        // ── Top row: icon + type label ──
        let iconView = UIImageView()
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = UIImage(named: iconAssetName(for: step.nodeType))?.withRenderingMode(.alwaysTemplate)
        iconView.tintColor = accent

        let typeLabel = UILabel()
        typeLabel.text = typeString(for: step.nodeType)
        typeLabel.textColor = accent
        typeLabel.font = UIFont(name: "Roboto-Regular", size: 10) ?? UIFont.systemFont(ofSize: 10)
        typeLabel.numberOfLines = 1
        typeLabel.lineBreakMode = .byTruncatingTail

        let iconRow = UIStackView(arrangedSubviews: [iconView, typeLabel])
        iconRow.axis = .horizontal
        iconRow.alignment = .center
        iconRow.spacing = 4

        // ── Middle row: alias ──
        let aliasLabel = UILabel()
        aliasLabel.text = step.displayId ?? step.id
        aliasLabel.textColor = UIColor.Sphinx.SecondaryText
        aliasLabel.font = UIFont(name: "Roboto-Regular", size: 11) ?? UIFont.systemFont(ofSize: 11)
        aliasLabel.numberOfLines = 1
        aliasLabel.lineBreakMode = .byTruncatingTail

        // ── Bottom row: display name ──
        let nameLabel = UILabel()
        nameLabel.text = step.displayName ?? step.name
        nameLabel.textColor = UIColor.Sphinx.Text
        nameLabel.font = UIFont(name: "Roboto-Medium", size: 12) ?? UIFont.systemFont(ofSize: 12, weight: .medium)
        nameLabel.numberOfLines = 2
        nameLabel.lineBreakMode = .byTruncatingTail

        let stack = UIStackView(arrangedSubviews: [iconRow, aliasLabel, nameLabel])
        stack.axis = .vertical
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),

            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    // MARK: Condition (diamond) node
    // Uses a CAShapeLayer diamond drawn inside a plain view — no CGAffineTransform on the view.

    private func setupConditionNode() {
        backgroundColor = .clear   // diamond shape will paint itself
        layer.cornerRadius = 0

        // Diamond CAShapeLayer — drawn in layoutSublayers / sizeToFit
        let dl = CAShapeLayer()
        dl.fillColor   = UIColor.white.cgColor
        dl.strokeColor = UIColor.Sphinx.SecondaryText.cgColor
        dl.lineWidth   = 1.5
        layer.addSublayer(dl)
        diamondLayer = dl

        // Label centred in the view
        let nameLabel = UILabel()
        nameLabel.text = step.displayName ?? step.name
        nameLabel.textColor = UIColor.Sphinx.Text
        nameLabel.font = UIFont(name: "Roboto-Medium", size: 10) ?? UIFont.systemFont(ofSize: 10, weight: .medium)
        nameLabel.textAlignment = .center
        nameLabel.numberOfLines = 3
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(nameLabel)

        // Keep label inside the "inner" diamond area (approx 50% of each dimension)
        let insetX = Self.conditionWidth  * 0.25
        let insetY = Self.conditionHeight * 0.25
        NSLayoutConstraint.activate([
            nameLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            nameLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            nameLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: insetX),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -insetX),
            nameLabel.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: insetY),
            nameLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -insetY)
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Redraw diamond whenever bounds change
        if let dl = diamondLayer {
            let w = bounds.width, h = bounds.height
            let path = UIBezierPath()
            path.move(to: CGPoint(x: w / 2, y: 0))
            path.addLine(to: CGPoint(x: w, y: h / 2))
            path.addLine(to: CGPoint(x: w / 2, y: h))
            path.addLine(to: CGPoint(x: 0, y: h / 2))
            path.close()
            dl.path = path.cgPath
            dl.frame = bounds
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

    // MARK: Edge connection points (in parent coordinate space)

    var rightEdgeMid: CGPoint { CGPoint(x: frame.maxX, y: frame.midY) }
    var leftEdgeMid:  CGPoint { CGPoint(x: frame.minX, y: frame.midY) }
}

// MARK: - Diagram View

class WorkflowDiagramView: UIView, UIScrollViewDelegate {

    // MARK: Public
    var onStepTapped: ((WorkflowStep) -> Void)?

    // MARK: Private
    private let scrollView = UIScrollView()
    private let canvasView = UIView()
    private var nodeViews:  [String: WorkflowStepNodeView] = [:]
    private var edgeLayers: [CAShapeLayer] = []
    private var edgeLabels: [UILabel] = []

    private var didPerformInitialZoom = false
    private var startNodeFrame: CGRect = .zero

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

    // MARK: - UIScrollViewDelegate

    func viewForZooming(in scrollView: UIScrollView) -> UIView? { canvasView }

    // MARK: - Zoom-to-fit

    /// Called from both configure() (deferred) and layoutSubviews() to handle either ordering.
    private func zoomToFitIfReady() {
        guard !didPerformInitialZoom,
              canvasView.frame.width  > 0,
              scrollView.bounds.width > 0,
              scrollView.bounds.height > 0 else { return }
        didPerformInitialZoom = true
        zoomToFit()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        zoomToFitIfReady()
    }

    private func zoomToFit() {
        guard scrollView.bounds.width  > 0,
              scrollView.bounds.height > 0,
              canvasView.frame.width   > 0,
              canvasView.frame.height  > 0 else { return }

        // Scale so full canvas fits in the visible area
        let scaleX = scrollView.bounds.width  / canvasView.frame.width
        let scaleY = scrollView.bounds.height / canvasView.frame.height
        let scale  = max(min(scaleX, scaleY), scrollView.minimumZoomScale)
        scrollView.setZoomScale(scale, animated: false)

        // After setZoomScale, contentSize = original canvas size × scale.
        // Centre viewport on the START pill so it's the first thing the user sees.
        if startNodeFrame != .zero {
            let scaledMidX = startNodeFrame.midX * scale
            let scaledMidY = startNodeFrame.midY * scale
            let rawOffX = scaledMidX - scrollView.bounds.width  / 2
            let rawOffY = scaledMidY - scrollView.bounds.height / 2
            let maxOffX = max(scrollView.contentSize.width  - scrollView.bounds.width,  0)
            let maxOffY = max(scrollView.contentSize.height - scrollView.bounds.height, 0)
            scrollView.contentOffset = CGPoint(
                x: min(max(rawOffX, 0), maxOffX),
                y: min(max(rawOffY, 0), maxOffY)
            )
        } else {
            let offsetX = max((scrollView.contentSize.width  - scrollView.bounds.width)  / 2, 0)
            let offsetY = max((scrollView.contentSize.height - scrollView.bounds.height) / 2, 0)
            scrollView.contentOffset = CGPoint(x: offsetX, y: offsetY)
        }
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

        let hPadding: CGFloat  = 60
        let vPadding: CGFloat  = 80   // space above/below nodes
        let positionScale: CGFloat = 0.5

        // ---- Place step node views ----
        for (key, step) in diagram.steps {
            let nodeView = WorkflowStepNodeView(step: step)

            let w: CGFloat = step.nodeType == .condition
                ? WorkflowStepNodeView.conditionWidth
                : WorkflowStepNodeView.nodeWidth
            let h: CGFloat = step.nodeType == .condition
                ? WorkflowStepNodeView.conditionHeight
                : WorkflowStepNodeView.nodeHeight

            nodeView.frame = CGRect(
                x: step.positionX * positionScale + hPadding,
                y: step.positionY * positionScale + vPadding,
                width: w,
                height: h
            )

            canvasView.addSubview(nodeView)
            nodeViews[key] = nodeView

            let tap = UITapGestureRecognizer(target: self, action: #selector(nodeTapped(_:)))
            nodeView.addGestureRecognizer(tap)
            nodeView.isUserInteractionEnabled = true
        }

        // ---- Compute bounds of placed nodes ----
        let sortedByX      = nodeViews.values.sorted { $0.frame.midX < $1.frame.midX }
        let allNodesMinX   = nodeViews.values.map { $0.frame.minX }.min() ?? hPadding
        let allNodesMaxX   = nodeViews.values.map { $0.frame.maxX }.max() ?? 400
        let firstNodeMidY  = sortedByX.first?.frame.midY ?? vPadding
        let lastNodeMidY   = sortedByX.last?.frame.midY  ?? vPadding
        let allNodesMaxY   = nodeViews.values.map { $0.frame.maxY }.max() ?? 400

        // ---- Inject terminal pill nodes ----
        let terminalW: CGFloat = 80
        let terminalH: CGFloat = 32
        let terminalGrey = UIColor.gray

        // START — PrimaryGreen, Y-aligned with the first (leftmost) step
        let startView = WorkflowTerminalNodeView(text: "START", color: UIColor.Sphinx.PrimaryGreen)
        startView.frame = CGRect(
            x: max(allNodesMinX - terminalW - 20, 4),
            y: firstNodeMidY - terminalH / 2,
            width: terminalW, height: terminalH
        )
        startView.layer.cornerRadius = terminalH / 2
        canvasView.addSubview(startView)
        startNodeFrame = startView.frame

        // END — grey, Y-aligned with the last (rightmost) step
        let endView = WorkflowTerminalNodeView(text: "END", color: terminalGrey)
        endView.frame = CGRect(
            x: allNodesMaxX + 20,
            y: lastNodeMidY - terminalH / 2,
            width: terminalW, height: terminalH
        )
        endView.layer.cornerRadius = terminalH / 2
        canvasView.addSubview(endView)

        // HALTED — grey, below END
        let haltedView = WorkflowTerminalNodeView(text: "HALTED", color: terminalGrey)
        haltedView.frame = CGRect(
            x: allNodesMaxX + 20,
            y: endView.frame.maxY + 16,
            width: terminalW, height: terminalH
        )
        haltedView.layer.cornerRadius = terminalH / 2
        canvasView.addSubview(haltedView)

        // ---- Set canvas size ----
        let canvasMaxX = haltedView.frame.maxX + hPadding
        let canvasMaxY = max(allNodesMaxY, haltedView.frame.maxY) + vPadding
        canvasView.frame = CGRect(x: 0, y: 0, width: canvasMaxX, height: canvasMaxY)
        scrollView.contentSize = canvasView.frame.size

        // ---- Draw edges ----
        canvasView.layoutIfNeeded()
        drawEdges(diagram: diagram)

        let edgeColor = UIColor.Sphinx.WashedOutReceivedText.cgColor

        // START → leftmost node
        if let first = sortedByX.first {
            let arrow = makeArrowLayer(
                from: CGPoint(x: startView.frame.maxX, y: startView.frame.midY),
                to:   first.leftEdgeMid,
                color: edgeColor
            )
            canvasView.layer.insertSublayer(arrow, at: 0)
            edgeLayers.append(arrow)
        }

        // Rightmost node → END and HALTED
        if let last = sortedByX.last {
            for term in [endView, haltedView] {
                let arrow = makeArrowLayer(
                    from: last.rightEdgeMid,
                    to:   CGPoint(x: term.frame.minX, y: term.frame.midY),
                    color: edgeColor
                )
                canvasView.layer.insertSublayer(arrow, at: 0)
                edgeLayers.append(arrow)
            }
        }

        // ---- Attempt zoom now if bounds already valid; layoutSubviews is the fallback ----
        DispatchQueue.main.async { [weak self] in
            self?.zoomToFitIfReady()
        }
    }

    // MARK: - Draw step-to-step edges

    private func drawEdges(diagram: WorkflowDiagramData) {
        let edgeColor = UIColor.Sphinx.WashedOutReceivedText.cgColor

        for edge in diagram.edges {
            guard let from = nodeViews[edge.fromId],
                  let to   = nodeViews[edge.toId] else { continue }

            let layer = makeArrowLayer(from: from.rightEdgeMid, to: to.leftEdgeMid, color: edgeColor)
            canvasView.layer.insertSublayer(layer, at: 0)
            edgeLayers.append(layer)

            if let label = edge.label, !label.isEmpty {
                let lbl = UILabel()
                lbl.text = label
                lbl.font = UIFont(name: "Roboto-Regular", size: 10) ?? UIFont.systemFont(ofSize: 10)
                lbl.textColor = UIColor.Sphinx.SecondaryText
                lbl.sizeToFit()
                let midX = (from.rightEdgeMid.x + to.leftEdgeMid.x) / 2 - lbl.frame.width / 2
                let midY = (from.rightEdgeMid.y + to.leftEdgeMid.y) / 2 - lbl.frame.height - 2
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
        path.addCurve(to: end,
                      controlPoint1: CGPoint(x: midX, y: start.y),
                      controlPoint2: CGPoint(x: midX, y: end.y))

        let dx = end.x - start.x
        let dy = end.y - start.y
        let angle = atan2(dy, dx)
        let aLen: CGFloat = 8
        let aAng: CGFloat = .pi / 6

        path.move(to: end)
        path.addLine(to: CGPoint(x: end.x - aLen * cos(angle - aAng),
                                  y: end.y - aLen * sin(angle - aAng)))
        path.move(to: end)
        path.addLine(to: CGPoint(x: end.x - aLen * cos(angle + aAng),
                                  y: end.y - aLen * sin(angle + aAng)))

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
