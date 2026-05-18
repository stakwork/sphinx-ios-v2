//
//  SuggestionChipsView.swift
//  sphinx
//

import UIKit

class SuggestionChipsView: UIView {

    var onChipTapped: ((String) -> Void)?

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsHorizontalScrollIndicator = false
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let stackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.spacing = 8
        sv.alignment = .center
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        isHidden = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
        isHidden = true
    }

    private func setupViews() {
        translatesAutoresizingMaskIntoConstraints = false

        addSubview(scrollView)
        scrollView.addSubview(stackView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollView.heightAnchor.constraint(equalToConstant: 36),

            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])
    }

    func configure(with suggestions: [String]) {
        // Remove existing chips
        stackView.arrangedSubviews.forEach {
            stackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        for suggestion in suggestions {
            let button = makeChipButton(title: suggestion)
            stackView.addArrangedSubview(button)
        }

        isHidden = suggestions.isEmpty
    }

    func clear() {
        stackView.arrangedSubviews.forEach {
            stackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        isHidden = true
    }

    private func makeChipButton(title: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont(name: "Roboto-Regular", size: 14) ?? UIFont.systemFont(ofSize: 14)
        button.setTitleColor(UIColor.Sphinx.Text, for: .normal)
        button.backgroundColor = UIColor.Sphinx.HeaderBG
        button.layer.cornerRadius = 14
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.Sphinx.LightDivider.cgColor
        button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        button.translatesAutoresizingMaskIntoConstraints = false

        button.addTarget(self, action: #selector(chipTapped(_:)), for: .touchUpInside)
        return button
    }

    @objc private func chipTapped(_ sender: UIButton) {
        guard let title = sender.title(for: .normal) else { return }
        onChipTapped?(title)
    }
}
