//
//  PaginationControlView.swift
//  sphinx
//
//  Copyright © 2025 Sphinx. All rights reserved.
//

import UIKit

// MARK: - Delegate Protocol

protocol PaginationControlViewDelegate: AnyObject {
    func paginationControlView(_ view: PaginationControlView, didSelectPage page: Int)
}

// MARK: - PaginationControlView

class PaginationControlView: UIView {

    // MARK: - Public API

    weak var delegate: PaginationControlViewDelegate?

    private(set) var currentPage: Int = 1
    private(set) var totalPages: Int = 1

    /// Call to update the control state. Hides itself when `totalPages <= 1`.
    func configure(currentPage: Int, totalPages: Int) {
        self.currentPage = max(1, currentPage)
        self.totalPages  = max(1, totalPages)
        isHidden = (totalPages <= 1)
        guard !isHidden else { return }
        rebuildPageButtons()
        updateArrowStates()
    }

    // MARK: - Subviews

    private let stackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.alignment = .center
        sv.distribution = .fill
        sv.spacing = 4
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private lazy var firstButton  = makeArrowButton(symbolName: "chevron.left.2",  tag: -2)
    private lazy var prevButton   = makeArrowButton(symbolName: "chevron.left",     tag: -1)
    private lazy var nextButton   = makeArrowButton(symbolName: "chevron.right",    tag: -3)
    private lazy var lastButton   = makeArrowButton(symbolName: "chevron.right.2",  tag: -4)

    /// Reusable pool of up to 5 page-number buttons.
    private var pageButtons: [UIButton] = []

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        backgroundColor = .Sphinx.Body
        translatesAutoresizingMaskIntoConstraints = false

        // Build 5 page buttons up front and hide unused ones
        for _ in 0..<5 {
            let btn = makePageButton()
            pageButtons.append(btn)
        }

        addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        // Populate stack (page buttons will be inserted between arrows)
        stackView.addArrangedSubview(firstButton)
        stackView.addArrangedSubview(prevButton)
        pageButtons.forEach { stackView.addArrangedSubview($0) }
        stackView.addArrangedSubview(nextButton)
        stackView.addArrangedSubview(lastButton)
    }

    // MARK: - Layout helpers

    private func makeArrowButton(symbolName: String, tag: Int) -> UIButton {
        let btn = UIButton(type: .system)
        btn.tag = tag
        let config = UIImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        btn.setImage(UIImage(systemName: symbolName, withConfiguration: config), for: .normal)
        btn.tintColor = .Sphinx.Text
        btn.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            btn.widthAnchor.constraint(equalToConstant: 32),
            btn.heightAnchor.constraint(equalToConstant: 32)
        ])
        btn.addTarget(self, action: #selector(arrowButtonTapped(_:)), for: .touchUpInside)
        return btn
    }

    private func makePageButton() -> UIButton {
        let btn = UIButton(type: .custom)
        btn.titleLabel?.font = UIFont(name: "Roboto-Medium", size: 14) ?? UIFont.systemFont(ofSize: 14, weight: .medium)
        btn.layer.cornerRadius = 16
        btn.layer.masksToBounds = true
        btn.layer.borderWidth = 1
        btn.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            btn.widthAnchor.constraint(equalToConstant: 32),
            btn.heightAnchor.constraint(equalToConstant: 32)
        ])
        btn.addTarget(self, action: #selector(pageButtonTapped(_:)), for: .touchUpInside)
        return btn
    }

    // MARK: - State update

    private func rebuildPageButtons() {
        let window = pageWindow(currentPage: currentPage, totalPages: totalPages)

        for (index, btn) in pageButtons.enumerated() {
            if index < window.count {
                let pageNum = window[index]
                btn.setTitle("\(pageNum)", for: .normal)
                btn.tag = pageNum
                btn.isHidden = false
                let isSelected = (pageNum == currentPage)
                if isSelected {
                    btn.backgroundColor = .Sphinx.PrimaryBlue
                    btn.setTitleColor(.white, for: .normal)
                    btn.layer.borderColor = UIColor.Sphinx.PrimaryBlue.cgColor
                } else {
                    btn.backgroundColor = .clear
                    btn.setTitleColor(.Sphinx.Text, for: .normal)
                    btn.layer.borderColor = UIColor.Sphinx.SecondaryText.withAlphaComponent(0.4).cgColor
                }
            } else {
                btn.isHidden = true
            }
        }
    }

    private func updateArrowStates() {
        let onFirst = (currentPage <= 1)
        let onLast  = (currentPage >= totalPages)

        firstButton.isEnabled = !onFirst
        prevButton.isEnabled  = !onFirst
        nextButton.isEnabled  = !onLast
        lastButton.isEnabled  = !onLast

        firstButton.alpha = onFirst ? 0.3 : 1.0
        prevButton.alpha  = onFirst ? 0.3 : 1.0
        nextButton.alpha  = onLast  ? 0.3 : 1.0
        lastButton.alpha  = onLast  ? 0.3 : 1.0
    }

    // MARK: - Page window calculation

    /// Returns an array of up to 5 page numbers centred around `currentPage`.
    func pageWindow(currentPage: Int, totalPages: Int) -> [Int] {
        guard totalPages > 1 else { return [] }
        let maxVisible = min(5, totalPages)
        var start = currentPage - maxVisible / 2
        start = max(1, start)
        start = min(start, totalPages - maxVisible + 1)
        return Array(start ..< (start + maxVisible))
    }

    // MARK: - Actions

    @objc private func arrowButtonTapped(_ sender: UIButton) {
        let target: Int
        switch sender.tag {
        case -2: target = 1                  // first
        case -1: target = currentPage - 1    // prev
        case -3: target = currentPage + 1    // next
        case -4: target = totalPages         // last
        default: return
        }
        let clamped = max(1, min(totalPages, target))
        configure(currentPage: clamped, totalPages: totalPages)
        delegate?.paginationControlView(self, didSelectPage: clamped)
    }

    @objc private func pageButtonTapped(_ sender: UIButton) {
        let page = sender.tag
        guard page >= 1, page <= totalPages else { return }
        configure(currentPage: page, totalPages: totalPages)
        delegate?.paginationControlView(self, didSelectPage: page)
    }
}
