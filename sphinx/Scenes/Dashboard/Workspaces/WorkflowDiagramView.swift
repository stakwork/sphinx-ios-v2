//
//  WorkflowDiagramView.swift
//  sphinx
//
//  Zoomable, pannable workflow diagram canvas.
//

import UIKit

// MARK: - Node View

private class WorkflowStepNodeView: UIView {
    private let nameLabel = UILabel()
    let step: WorkflowStep

    // Node sizing constants
    static let nodeWidth: CGFloat  = 120
    static let nodeHeight: CGFloat = 44
    static let conditionSize: CGFloat = 54  // diamond — rotated square

    init(step: WorkflowStep) {
        self.step = step
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

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
            // Diamond: rotate 45°, equal W×H
            layer.cornerRadius = 4
            transform = CGAffineTransform(rotationAngle: .pi / 4)
        } else {
            layer.cornerRadius = 8
        }

        // Status ring
        if let state = step.stepState {
            let ringColor: UIColor
            switch state {
            case "finished":   ringColor = .systemGreen
            case "in_progress": ringColor = .systemBlue
            case "error":       ringColor = .systemRed
            case "skipped":     ringColor = .systemGray
            default:            ringColor = .clear
            }
            layer.borderWidth  = 2
            layer.borderColor  = ringColor.cgColor

            if state == "in_progress" {
                addPulseAnimation()
            }
        }

        // Label (un-rotated for condition)
        nameLabel.text = step.displayName ?? step.name
        nameLabel.textColor = .white
        nameLabel.font = UIFont(name: "Roboto-Medium", size: 12) ?? UIFont.systemFont(ofSize: 12, weight: .medium)
        nameLabel.textAlignment = .center
        nameLabel.numberOfLines = 2
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        // For condition we add the label un-transformed by embedding in a sub-view
        if step.nodeType == .condition {
            let labelHost = UIView()
            labelHost.translatesAutoresizingMaskIntoConstraints = false
            labelHost.transform = CGAffineTransform(rotationAngle: -.pi / 4)
            labelHost.isUserInteractionEnabled = false
            addSubview(labelHost)
            labelHost.addSubview(nameLabel)
            NSLayoutConstraint.activate([
                labelHost.centerXAnchor.constraint(equalTo: centerXAnchor),
                labelHost.centerYAnchor.constraint(equalTo: centerYAnchor),
                labelHost.widthAnchor.constraint(equalTo: widthAnchor),
                labelHost.heightAnchor.constraint(equalTo: heightAnchor),
                nameLabel.leadingAnchor.constraint(equalTo: labelHost.leadingAnchor, constant: 4),
                nameLabel.trailingAnchor.constraint(equalTo: labelHost.trailingAnchor, constant: -4),
                nameLabel.centerYAnchor.constraint(equalTo: labelHost.centerYAnchor)
            ])
        } else {
            addSubview(nameLabel)
            NSLayoutConstraint.activate([
                nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
                nameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
                nameLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
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

    /// Returns the visual centre in its parent's coordinate space (accounts for rotation).
    var visualCenter: CGPoint {
        return CGPoint(x: frame.midX, y: frame.midY)
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

        // Scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.minimumZoomScale = 0.3
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

        // Canvas view
        canvasView.translatesAutoresizingMaskIntoConstraints = false
        canvasView.backgroundColor = .clear
        scrollView.addSubview(canvasView)
    }

    // MARK: - UIScrollViewDelegate

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return canvasView
    }

    // MARK: - Configure

    func configure(with diagram: WorkflowDiagramData) {
        // Clear previous content
        canvasView.subviews.forEach { $0.removeFromSuperview() }
        edgeLayers.forEach { $0.removeFromSuperlayer() }
        edgeLabels.forEach { $0.removeFromSuperview() }
        edgeLayers.removeAll()
        edgeLabels.removeAll()
        nodeViews.removeAll()

        guard !diagram.steps.isEmpty else { return }

        let padding: CGFloat = 60

        // ---- Place node views ----
        for (key, step) in diagram.steps {
            let nodeView = WorkflowStepNodeView(step: step)
            nodeView.translatesAutoresizingMaskIntoConstraints = false

            let w: CGFloat = step.nodeType == .condition
                ? WorkflowStepNodeView.conditionSize
                : WorkflowStepNodeView.nodeWidth
            let h: CGFloat = step.nodeType == .condition
                ? WorkflowStepNodeView.conditionSize
                : WorkflowStepNodeView.nodeHeight

            nodeView.frame = CGRect(
                x: step.positionX + padding,
                y: step.positionY + padding,
                width: w,
                height: h
            )

            canvasView.addSubview(nodeView)
            nodeViews[key] = nodeView

            let tap = UITapGestureRecognizer(target: self, action: #selector(nodeTapped(_:)))
            nodeView.addGestureRecognizer(tap)
            nodeView.isUserInteractionEnabled = true
        }

        // ---- Set canvas size ----
        let maxX = (nodeViews.values.map { $0.frame.maxX }.max() ?? 400) + padding
        let maxY = (nodeViews.values.map { $0.frame.maxY }.max() ?? 400) + padding
        canvasView.frame = CGRect(x: 0, y: 0, width: maxX, height: maxY)
        scrollView.contentSize = canvasView.frame.size

        // ---- Draw edges ----
        DispatchQueue.main.async { [weak self] in
            self?.drawEdges(diagram: diagram)
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

    // MARK: - Arrow layer (mirrors TaskDependencyDiagramView pattern)

    private func makeArrowLayer(from start: CGPoint, to end: CGPoint, color: CGColor) -> CAShapeLayer {
        let path = UIBezierPath()
        let midX = (start.x + end.x) / 2
        path.move(to: start)
        path.addCurve(
            to: end,
            controlPoint1: CGPoint(x: midX, y: start.y),
            controlPoint2: CGPoint(x: midX, y: end.y)
        )

        // Arrowhead — compute actual angle of arrival
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
