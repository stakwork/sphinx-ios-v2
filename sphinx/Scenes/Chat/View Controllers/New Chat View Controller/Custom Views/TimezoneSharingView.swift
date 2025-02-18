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
}

class TimezoneSharingView: UIView {
    
    weak var delegate: TimezoneSharingViewDelegate?
    
    @IBOutlet private var contentView: UIView!
    @IBOutlet weak var shareTimezoneSwitch: UISwitch!
    @IBOutlet weak var timezoneField: UITextField!
    
    public static let kDefaultValue = "Use Computer Settings"
    
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
    }
    
    @IBAction func timezoneButtonTouched() {
        delegate?.shouldPresentPickerViewWith(delegate: self)
    }
}

extension TimezoneSharingView : PickerViewDelegate {
    func didSelectValue(value: String) {
        timezoneField.text = value
    }
}
