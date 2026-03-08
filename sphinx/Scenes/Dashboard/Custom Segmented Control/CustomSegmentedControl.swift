//
// CustomSegmentedControl.swift
// sphinx


import UIKit


@objc protocol CustomSegmentedControlDelegate: AnyObject {
    
    func segmentedControlDidSwitch(
        _ control: CustomSegmentedControl,
        to index: Int
    )
}


class CustomSegmentedControl: UIView {
    private var buttonTitles: [String]!
    private var buttonSymbols: [String]?      // SF Symbol names, parallel to buttonTitles
    private var buttons: [UIButton]!
    private var buttonTitleBadges: [UIView]!
    private var selectorView: UIView!
    

    public var buttonBackgroundColor: UIColor = .Sphinx.DashboardHeader
    public var buttonTextColor: UIColor = .Sphinx.DashboardWashedOutText
    public var activeTextColor: UIColor = .Sphinx.PrimaryText
    public var buttonTitleFont = UIFont(
        name: "Roboto-Medium",
        size: UIDevice.current.isIpad ? 20.0 : 16.0
    )!
    
    public var selectorViewColor: UIColor = .Sphinx.PrimaryBlue
    public var selectorWidthRatio: CGFloat = 0.85

    /// Custom width ratios for each button. If nil, buttons will be distributed equally.
    public var buttonWidthRatios: [CGFloat]? = nil
    
    
    /// Indices for tabs that should have a circular badge displayed next to their title.
    public var indicesOfTitlesWithBadge: [Int] = [] {
        didSet {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.updateTitleBadges()
            }
        }
    }
    

    public weak var delegate: CustomSegmentedControlDelegate?
    
    private(set) var selectedIndex: Int = 0
    
    
    convenience init(
        frame: CGRect,
        buttonTitles: [String]
    ) {
        self.init(frame: frame)
        
        self.buttonTitles = buttonTitles
        
        setupInitialViews()
    }
}


// MARK: - Lifecycle
extension CustomSegmentedControl {
        
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        backgroundColor = buttonBackgroundColor
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        // Keep selector pinned to the bottom whenever the view is laid out
        guard selectorView != nil else { return }
        selectorView.frame = CGRect(
            x: selectorPosition,
            y: bounds.height - 2,
            width: selectorWidth,
            height: 2
        )
    }
}


// MARK: - Action Handling
extension CustomSegmentedControl {
    
    func selectTabWith(index: Int) {
        if index >= 0 && buttons.count > index {
            let button = buttons[index]
            buttonAction(sender: button)
        }
    }
    
    @objc func buttonAction(sender: UIButton) {
        for (buttonIndex, button) in buttons.enumerated() {
            if buttonSymbols != nil {
                button.tintColor = buttonTextColor
            } else {
                button.setTitleColor(buttonTextColor, for: .normal)
            }
            
            if button == sender {
                selectedIndex = buttonIndex

                delegate?.segmentedControlDidSwitch(self, to: selectedIndex)
                
                updateButtonsOnIndexChange()
            }
        }
    }
}


// MARK: - Public Methods
extension CustomSegmentedControl {

    public func configureFromOutlet(
        buttonTitles: [String],
        initialIndex: Int = 0,
        indicesOfTitlesWithBadge: [Int] = [],
        delegate: CustomSegmentedControlDelegate?
    ) {
        self.buttonTitles = buttonTitles
        self.buttonSymbols = nil
        self.selectedIndex = initialIndex
        self.delegate = delegate
        
        setupInitialViews()
        updateButtonsOnIndexChange()
    }

    /// Configure with SF Symbol names instead of text labels.
    public func configureWithSymbols(
        symbolNames: [String],
        placeholderTitles: [String],
        initialIndex: Int = 0,
        delegate: CustomSegmentedControlDelegate?
    ) {
        self.buttonTitles = placeholderTitles
        self.buttonSymbols = symbolNames
        self.selectedIndex = initialIndex
        self.delegate = delegate

        setupInitialViews()
        updateButtonsOnIndexChange()
    }
}


// MARK: -  View Configuration
extension CustomSegmentedControl {
    
    private func setupInitialViews() {
        createButtons()
        configureSelectorView()
        configureStackView()
    }
    
    
    private func configureStackView() {
        let stackView = UIStackView(arrangedSubviews: buttons)

        stackView.axis = .horizontal
        stackView.alignment = .fill

        if let ratios = buttonWidthRatios, ratios.count == buttons.count {
            stackView.distribution = .fill
            let totalWidth = UIScreen.main.bounds.width

            for (index, button) in buttons.enumerated() {
                button.widthAnchor.constraint(equalToConstant: totalWidth * ratios[index]).isActive = true
            }
        } else {
            stackView.distribution = .fillEqually
        }

        addSubview(stackView)

        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        stackView.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
        stackView.leftAnchor.constraint(equalTo: self.leftAnchor).isActive = true
        stackView.rightAnchor.constraint(equalTo: self.rightAnchor).isActive = true
    }


    private func buttonWidth(at index: Int) -> CGFloat {
        let totalWidth = UIScreen.main.bounds.width

        if let ratios = buttonWidthRatios, ratios.count == buttonTitles.count {
            return totalWidth * ratios[index]
        } else {
            return totalWidth / CGFloat(buttonTitles.count)
        }
    }


    private var selectorWidth: CGFloat {
        buttonWidth(at: selectedIndex) * selectorWidthRatio
    }


    private var selectorPosition: CGFloat {
        var position: CGFloat = 0

        for i in 0..<selectedIndex {
            position += buttonWidth(at: i)
        }

        let currentButtonWidth = buttonWidth(at: selectedIndex)
        let offset = (currentButtonWidth - selectorWidth) * 0.5

        return position + offset
    }
    
    
    private func configureSelectorView() {
        // Always place selector at the BOTTOM of the control
        selectorView = UIView(
            frame: CGRect(
                x: selectorPosition,
                y: self.frame.height - 2,
                width: selectorWidth,
                height: 2
            )
        )
        
        selectorView.backgroundColor = selectorViewColor

        addSubview(selectorView)
    }
    
    
    private func createButtons() {
        buttons = [UIButton]()
        buttons.removeAll()
        
        subviews.forEach({ $0.removeFromSuperview() })

        let symbols = buttonSymbols

        for (index, buttonTitle) in buttonTitles.enumerated() {
            let button = UIButton(type: .system)

            if let symbols = symbols, index < symbols.count {
                // SF Symbol mode
                let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
                let image = UIImage(systemName: symbols[index], withConfiguration: config)
                button.setImage(image, for: .normal)
                button.tintColor = buttonTextColor
                button.accessibilityLabel = buttonTitle
            } else {
                // Text mode
                button.setTitle(buttonTitle, for: .normal)
                button.setTitleColor(buttonTextColor, for: .normal)
                button.titleLabel?.font = buttonTitleFont
            }
            
            button.addTarget(
                self,
                action: #selector(CustomSegmentedControl.buttonAction(sender:)),
                for: .touchUpInside
            )
            
            buttons.append(button)
        }

        if symbols != nil {
            buttons[selectedIndex].tintColor = activeTextColor
        } else {
            buttons[selectedIndex].setTitleColor(activeTextColor, for: .normal)
        }
        
        createButtonTitleBadges()
    }
    
    
    func updateButtonsOnIndexChange() {
        UIView.animate(withDuration: 0.3) {
            if self.buttonSymbols != nil {
                for (i, btn) in self.buttons.enumerated() {
                    btn.tintColor = i == self.selectedIndex ? self.activeTextColor : self.buttonTextColor
                }
            } else {
                self.buttons[self.selectedIndex].setTitleColor(self.activeTextColor, for: .normal)
            }
            // Only animate x/width — y is managed by layoutSubviews (always bottom)
            self.selectorView.frame = CGRect(
                x: self.selectorPosition,
                y: self.bounds.height - 2,
                width: self.selectorWidth,
                height: 2
            )
        }
    }
    
    
    private func updateTitleBadges() {
        buttonTitleBadges.enumerated().forEach { (index, badge) in
            let button = buttons[index]
            // Use imageView frame for SF Symbol buttons, titleLabel frame for text buttons
            let contentFrame = button.imageView?.frame ?? button.titleLabel?.frame ?? .zero
            let badgeSize: CGFloat = 7.0
            badge.frame = CGRect(
                x: contentFrame.maxX - badgeSize / 2,
                y: contentFrame.minY - badgeSize / 2,
                width: badgeSize,
                height: badgeSize
            )
            badge.makeCircular()
            badge.isHidden = !indicesOfTitlesWithBadge.contains(index)
        }
    }
        
    
    private func createButtonTitleBadges() {
        buttonTitleBadges = buttons!.map { button in
            let badgeView = UIView()
            
            badgeView.isHidden = true
            badgeView.backgroundColor = .Sphinx.PrimaryBlue
                
            return badgeView
        }
        
        buttonTitleBadges.enumerated().forEach { (index, badge) in
            badge.isHidden = !indicesOfTitlesWithBadge.contains(index)
            buttons[index].addSubview(badge)
        }
    }
}
