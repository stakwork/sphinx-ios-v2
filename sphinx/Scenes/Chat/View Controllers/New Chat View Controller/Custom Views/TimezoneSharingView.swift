//
//  TimezoneSharingView.swift
//  sphinx
//
//  Created by Tomas Timinskas on 17/02/2025.
//  Copyright © 2025 sphinx. All rights reserved.
//

import UIKit

protocol TimezoneSharingViewDelegate: class {
    func shouldPresentPickerViewWith(delegate: PickerViewDelegate)
    func timezoneSharingSettingsChanged(enabled: Bool, identifier: String?)
}

class TimezoneSharingView: UIView {
    
    weak var delegate: TimezoneSharingViewDelegate?
    
    @IBOutlet private var contentView: UIView!
    @IBOutlet weak var shareTimezoneSwitch: UISwitch!
    @IBOutlet weak var timezoneField: UITextField!
    
    public static let kDefaultValue = "Use Computer Settings"
    
    let newMessageBubbleHelper = NewMessageBubbleHelper()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }

    private func setup() {
        Bundle.main.loadNibNamed("TimezoneSharingView", owner: self, options: nil)
        addSubview(contentView)
        contentView.frame = self.bounds
        contentView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        
        shareTimezoneSwitch.onTintColor = UIColor.Sphinx.PrimaryBlue
        timezoneField.text = TimezoneSharingView.kDefaultValue
        
        shareTimezoneSwitch.addTarget(self, action: #selector(switchValueChanged), for: .valueChanged)
    }
    
    @objc func switchValueChanged() {
        notifyDelegate(showToast: false)
    }
    
    func configure(enabled: Bool, identifier: String?) {
        shareTimezoneSwitch.isOn = enabled
        timezoneField.text = identifier ?? TimezoneSharingView.kDefaultValue
    }
    
    func getTimezoneIdentifier() -> String? {
        let value = timezoneField.text ?? TimezoneSharingView.kDefaultValue
        return value == TimezoneSharingView.kDefaultValue ? nil : value
    }
    
    func isTimezoneEnabled() -> Bool {
        return shareTimezoneSwitch.isOn
    }
    
    private func notifyDelegate(
        showToast: Bool = false
    ) {
        if showToast {
            newMessageBubbleHelper.showGenericMessageView(
                text: "timezone.changed".localized,
                delay: 7,
                textColor: UIColor.white,
                backColor: UIColor.Sphinx.PrimaryGreen,
                backAlpha: 1.0
            )
        }
        
        delegate?.timezoneSharingSettingsChanged(
            enabled: isTimezoneEnabled(),
            identifier: getTimezoneIdentifier()
        )
    }
    
    @IBAction func timezoneButtonTouched() {
        delegate?.shouldPresentPickerViewWith(delegate: self)
    }
}

extension TimezoneSharingView : PickerViewDelegate {
    func didSelectValue(value: String) {
        timezoneField.text = value
        notifyDelegate(showToast: true)
    }
}
