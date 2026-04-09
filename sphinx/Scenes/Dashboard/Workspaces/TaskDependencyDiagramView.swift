//
//  TaskDependencyDiagramView.swift
//  sphinx
//
//  Created on 2025-04-07.
//  Copyright © 2025 sphinx. All rights reserved.
//

import UIKit

class TaskDependencyDiagramView: UIView {

    // MARK: - Constants
    private let nodeSize: CGFloat = 28
    private let nodeSpacing: CGFloat = 12
    private let columnSpacing: CGFloat = 48
    private let verticalPadding: CGFloat = 16

    // MARK: - Subviews
    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.showsVerticalScrollIndicator = false
        sv.showsHorizontalScrollIndicator = true
        return sv
    }()

    /// Container inside the scrollView that holds both the column stack and the arrow overlay
    private let contentContainer: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = .clear
        return v
    }()

    private let columnStack: UIStackView = {
        let sv = UIStackView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.axis = .horizontal
        sv.alignment = .top
        sv.distribution = .fill
        return sv
    }()

    /// Transparent overlay sitting on top of columnStack — same frame, same coordinate space
    private let arrowOverlay: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = .clear
        v.isUserInteractionEnabled = false
        return v
    }()

    // MARK: - State
    private var tasks: [WorkspaceTask] = []
    private var taskColumns: [String: Int] = [:]
    private var columns: [[WorkspaceTask]] = []
    private var nodeViews: [String: UIView] = [:]
    private var arrowLayers: [CAShapeLayer] = []

    // MARK: - Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        addSubview(scrollView)
        scrollView.addSubview(contentContainer)
        contentContainer.addSubview(columnStack)
        contentContainer.addSubview(arrowOverlay)

        NSLayoutConstraint.activate([
            // ScrollView fills the diagram view
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            // Content container fills scroll view content area (drives horizontal scrolling)
            contentContainer.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentContainer.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            // Height of content equals scroll view frame height
            contentContainer.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),

            // Column stack inside the container
            columnStack.topAnchor.constraint(equalTo: contentContainer.topAnchor, constant: verticalPadding),
            columnStack.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor, constant: 16),
            columnStack.bottomAnchor.constraint(lessThanOrEqualTo: contentContainer.bottomAnchor, constant: -verticalPadding),
            columnStack.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor, constant: -16),

            // Arrow overlay exactly matches the column stack so coordinate conversions are trivial
            arrowOverlay.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            arrowOverlay.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            arrowOverlay.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            arrowOverlay.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor)
        ])
    }

    // MARK: - Public API
    func configure(tasks: [WorkspaceTask]) {
        self.tasks = tasks
        computeColumns()
        buildLayout()
        invalidateIntrinsicContentSize()
        // Defer arrow drawing until after Auto Layout has resolved all frames
        setNeedsLayout()
    }

    // MARK: - Column computation (topological sort)
    func computeColumnAssignments(for tasks: [WorkspaceTask]) -> [String: Int] {
        var columns: [String: Int] = [:]
        for task in tasks { columns[task.id] = 0 }

        var changed = true
        while changed {
            changed = false
            for task in tasks {
                guard !task.dependsOnTaskIds.isEmpty else { continue }
                let maxPredCol = task.dependsOnTaskIds.compactMap { columns[$0] }.max() ?? -1
                let desired = maxPredCol + 1
                if desired > (columns[task.id] ?? 0) {
                    columns[task.id] = desired
                    changed = true
                }
            }
        }
        return columns
    }

    private func computeColumns() {
        taskColumns = computeColumnAssignments(for: tasks)
        let maxCol = taskColumns.values.max() ?? 0
        var cols = Array(repeating: [WorkspaceTask](), count: maxCol + 1)
        for task in tasks {
            let col = taskColumns[task.id] ?? 0
            cols[col].append(task)
        }
        columns = cols
    }

    // MARK: - Layout
    private func buildLayout() {
        columnStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        nodeViews.removeAll()

        for (colIdx, colTasks) in columns.enumerated() {
            let colStackView = UIStackView()
            colStackView.axis = .vertical
            colStackView.alignment = .center
            colStackView.distribution = .fill
            colStackView.spacing = nodeSpacing
            colStackView.translatesAutoresizingMaskIntoConstraints = false

            for task in colTasks {
                let globalIndex = (tasks.firstIndex(where: { $0.id == task.id }) ?? 0) + 1
                let node = makeNodeView(task: task, index: globalIndex)
                nodeViews[task.id] = node
                colStackView.addArrangedSubview(node)
            }

            columnStack.addArrangedSubview(colStackView)

            if colIdx < columns.count - 1 {
                let spacer = UIView()
                spacer.translatesAutoresizingMaskIntoConstraints = false
                spacer.widthAnchor.constraint(equalToConstant: columnSpacing).isActive = true
                columnStack.addArrangedSubview(spacer)
            }
        }
    }

    private func makeNodeView(task: WorkspaceTask, index: Int) -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "\(index)"
        label.textAlignment = .center
        label.textColor = .white
        label.font = UIFont(name: "Roboto-Medium", size: 12) ?? UIFont.systemFont(ofSize: 12, weight: .medium)
        label.backgroundColor = WorkspaceTaskTableViewCell().statusColor(for: task.status)
        label.layer.cornerRadius = nodeSize / 2
        label.clipsToBounds = true
        label.widthAnchor.constraint(equalToConstant: nodeSize).isActive = true
        label.heightAnchor.constraint(equalToConstant: nodeSize).isActive = true
        return label
    }

    // MARK: - Arrows

    override func layoutSubviews() {
        super.layoutSubviews()
        // Defer to next run-loop tick so all nested stack views have finished layout
        DispatchQueue.main.async { [weak self] in
            self?.drawArrows()
        }
    }

    private func drawArrows() {
        arrowLayers.forEach { $0.removeFromSuperlayer() }
        arrowLayers.removeAll()

        let arrowColor = UIColor.Sphinx.SecondaryText.cgColor

        for task in tasks {
            guard !task.dependsOnTaskIds.isEmpty,
                  let dependentNode = nodeViews[task.id] else { continue }

            for sourceId in task.dependsOnTaskIds {
                guard let sourceNode = nodeViews[sourceId] else { continue }

                // Both nodes and the arrowOverlay share the same contentContainer coordinate space
                let sourceFrame = sourceNode.convert(sourceNode.bounds, to: arrowOverlay)
                let dependentFrame = dependentNode.convert(dependentNode.bounds, to: arrowOverlay)

                let startPoint = CGPoint(x: sourceFrame.maxX, y: sourceFrame.midY)
                let endPoint   = CGPoint(x: dependentFrame.minX, y: dependentFrame.midY)

                let sourceCol = taskColumns[sourceId] ?? 0
                let destCol   = taskColumns[task.id]  ?? 0
                var verticalOffset: CGFloat = 0

                if abs(destCol - sourceCol) > 1 {
                    let minCol = min(sourceCol, destCol)
                    let maxCol = max(sourceCol, destCol)
                    let arrowMidY = (startPoint.y + endPoint.y) / 2

                    let obstructingYs: [CGFloat] = tasks
                        .filter { t in
                            let col = taskColumns[t.id] ?? 0
                            return col > minCol && col < maxCol
                        }
                        .compactMap { t -> CGFloat? in
                            guard let nv = nodeViews[t.id] else { return nil }
                            let f = nv.convert(nv.bounds, to: arrowOverlay)
                            return f.midY
                        }
                        .filter { abs($0 - arrowMidY) < nodeSize }

                    if !obstructingYs.isEmpty {
                        let clearance = nodeSize / 2 + nodeSpacing + 4
                        let avgObstructY = obstructingYs.reduce(0, +) / CGFloat(obstructingYs.count)
                        verticalOffset = avgObstructY >= arrowMidY ? -clearance : clearance
                    }
                }

                let layer = makeArrowLayer(from: startPoint, to: endPoint, color: arrowColor, verticalOffset: verticalOffset)
                arrowOverlay.layer.addSublayer(layer)
                arrowLayers.append(layer)
            }
        }
    }

    private func makeArrowLayer(from start: CGPoint, to end: CGPoint, color: CGColor, verticalOffset: CGFloat = 0) -> CAShapeLayer {
        let path = UIBezierPath()

        // Bezier curve from source right-edge to dependent left-edge
        let midX = (start.x + end.x) / 2
        path.move(to: start)
        path.addCurve(
            to: end,
            controlPoint1: CGPoint(x: midX, y: start.y + verticalOffset),
            controlPoint2: CGPoint(x: midX, y: end.y + verticalOffset)
        )

        // Arrowhead angle based on the curve's tangent at the endpoint (direction from cp2 → end)
        let arrowLength: CGFloat = 8
        let arrowAngle: CGFloat = .pi / 6
        let cp2 = CGPoint(x: midX, y: end.y + verticalOffset)
        let angle = atan2(end.y - cp2.y, end.x - cp2.x)

        let arrowPoint1 = CGPoint(
            x: end.x - arrowLength * cos(angle - arrowAngle),
            y: end.y - arrowLength * sin(angle - arrowAngle)
        )
        let arrowPoint2 = CGPoint(
            x: end.x - arrowLength * cos(angle + arrowAngle),
            y: end.y - arrowLength * sin(angle + arrowAngle)
        )
        path.move(to: end)
        path.addLine(to: arrowPoint1)
        path.move(to: end)
        path.addLine(to: arrowPoint2)

        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path.cgPath
        shapeLayer.strokeColor = color
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.lineWidth = 1.5
        shapeLayer.lineCap = .round
        return shapeLayer
    }

    // MARK: - Intrinsic size
    override var intrinsicContentSize: CGSize {
        let maxTasksInColumn = columns.map { $0.count }.max() ?? 1
        let height = CGFloat(maxTasksInColumn) * (nodeSize + nodeSpacing) - nodeSpacing + verticalPadding * 2
        return CGSize(width: UIView.noIntrinsicMetric, height: height)
    }
}
