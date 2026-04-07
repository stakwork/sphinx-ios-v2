//
//  TaskDependencyDiagramCell.swift
//  sphinx
//
//  Created on 2025-04-07.
//  Copyright © 2025 sphinx. All rights reserved.
//

import UIKit

class TaskDependencyDiagramCell: UITableViewCell {

    static let reuseID = "TaskDependencyDiagramCell"

    // MARK: - Subviews
    private let headerLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Dependencies"
        label.font = UIFont(name: "Roboto-Medium", size: 16) ?? UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = .Sphinx.Text
        return label
    }()

    private let diagramView: TaskDependencyDiagramView = {
        let view = TaskDependencyDiagramView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    // MARK: - Init
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCell()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCell()
    }

    // MARK: - Setup
    private func setupCell() {
        backgroundColor = .Sphinx.Body
        contentView.backgroundColor = .Sphinx.Body
        selectionStyle = .none

        contentView.addSubview(headerLabel)
        contentView.addSubview(diagramView)

        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            headerLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            headerLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            diagramView.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 8),
            diagramView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            diagramView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            diagramView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])
    }

    // MARK: - Public API
    func configure(tasks: [WorkspaceTask]) {
        diagramView.configure(tasks: tasks)
    }
}
