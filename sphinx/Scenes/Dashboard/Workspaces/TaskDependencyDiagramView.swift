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

    private let columnStack: UIStackView = {
        let sv = UIStackView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.axis = .horizontal
        sv.alignment = .top
        sv.distribution = .fill
        return sv
    }()

    /// Transparent overlay for drawing arrows
    private let arrowOverlay: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = .clear
        v.isUserInteractionEnabled = false
        return v
    }()

    // MARK: - State
    private var tasks: [WorkspaceTask] = []
    /// column index for each task id
    private var taskColumns: [String: Int] = [:]
    /// ordered columns
    private var columns: [[WorkspaceTask]] = []
    /// node view for each task id (used for arrow drawing)
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
        scrollView.addSubview(columnStack)
        scrollView.addSubview(arrowOverlay)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            columnStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: verticalPadding),
            columnStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            columnStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -verticalPadding),
            columnStack.heightAnchor.constraint(equalTo: scrollView.heightAnchor, constant: -(verticalPadding * 2)),

            arrowOverlay.topAnchor.constraint(equalTo: scrollView.topAnchor),
            arrowOverlay.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            arrowOverlay.widthAnchor.constraint(equalTo: columnStack.widthAnchor, constant: 32),
            arrowOverlay.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])
    }

    // MARK: - Public API
    func configure(tasks: [WorkspaceTask]) {
        self.tasks = tasks
        computeColumns()
        buildLayout()
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    // MARK: - Column computation (topological sort)
    /// Exposed as `internal` so it can be unit-tested.
    func computeColumnAssignments(for tasks: [WorkspaceTask]) -> [String: Int] {
        var columns: [String: Int] = [:]
        // Initialise all to 0
        for task in tasks { columns[task.id] = 0 }

        // Iterate until stable
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
        // Remove previous column subviews
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

            // Add spacing after each column except last
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
        drawArrows()
    }

    private func drawArrows() {
        // Remove old layers
        arrowLayers.forEach { $0.removeFromSuperlayer() }
        arrowLayers.removeAll()

        let arrowColor = UIColor.Sphinx.SecondaryText.cgColor

        for task in tasks {
            guard !task.dependsOnTaskIds.isEmpty,
                  let dependentNode = nodeViews[task.id] else { continue }

            for sourceId in task.dependsOnTaskIds {
                guard let sourceNode = nodeViews[sourceId] else { continue }

                // Convert frames to arrowOverlay coordinate space
                let sourceFrameInOverlay = sourceNode.convert(sourceNode.bounds, to: arrowOverlay)
                let dependentFrameInOverlay = dependentNode.convert(dependentNode.bounds, to: arrowOverlay)

                let startPoint = CGPoint(
                    x: sourceFrameInOverlay.maxX,
                    y: sourceFrameInOverlay.midY
                )
                let endPoint = CGPoint(
                    x: dependentFrameInOverlay.minX,
                    y: dependentFrameInOverlay.midY
                )

                let layer = makeArrowLayer(from: startPoint, to: endPoint, color: arrowColor)
                arrowOverlay.layer.addSublayer(layer)
                arrowLayers.append(layer)
            }
        }
    }

    private func makeArrowLayer(from start: CGPoint, to end: CGPoint, color: CGColor) -> CAShapeLayer {
        let path = UIBezierPath()

        // Draw line
        let midX = (start.x + end.x) / 2
        path.move(to: start)
        path.addCurve(
            to: end,
            controlPoint1: CGPoint(x: midX, y: start.y),
            controlPoint2: CGPoint(x: midX, y: end.y)
        )

        // Arrowhead
        let arrowLength: CGFloat = 8
        let arrowAngle: CGFloat = .pi / 6 // 30°
        let angle = atan2(end.y - start.y, end.x - start.x)

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
