//
//  HiveConfigurationViewController.swift
//  sphinx
//
//  Created on 2025-02-25.
//  Copyright © 2025 sphinx. All rights reserved.
//

import UIKit

class HiveConfigurationViewController: UIViewController {

    private var viewTitle: UILabel!
    private var closeButton: UIButton!
    private var closeIconLabel: UILabel!
    private var promptLabel: UILabel!
    private var promptFieldContainer: UIView!
    private var promptFieldView: UIView!
    private var promptTextView: UITextView!
    private var saveButton: UIButton!
    private var loadingWheel: UIActivityIndicatorView!

    let kCharacterLimit = 500
    let kTextViewColor = UIColor.Sphinx.Text

    var loading = false {
        didSet {
            LoadingWheelHelper.toggleLoadingWheel(
                loading: loading,
                loadingWheel: loadingWheel,
                loadingWheelColor: UIColor.Sphinx.Text,
                view: view
            )
        }
    }

    static func instantiate() -> HiveConfigurationViewController {
        return HiveConfigurationViewController()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        configureView()
        loadSavedPrompt()
    }

    private func setupViews() {
        view.backgroundColor = UIColor.Sphinx.Body

        // Header View
        let headerView = UIView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.backgroundColor = .clear
        view.addSubview(headerView)

        // Title Label
        viewTitle = UILabel()
        viewTitle.translatesAutoresizingMaskIntoConstraints = false
        viewTitle.text = "HIVE CONFIGURATION"
        viewTitle.textAlignment = .center
        viewTitle.font = UIFont(name: "Montserrat-SemiBold", size: 14)
        viewTitle.textColor = UIColor.Sphinx.Text
        headerView.addSubview(viewTitle)

        // Close Icon Label (Material Icons)
        closeIconLabel = UILabel()
        closeIconLabel.translatesAutoresizingMaskIntoConstraints = false
        closeIconLabel.text = ""
        closeIconLabel.font = UIFont(name: "MaterialIcons-Regular", size: 20)
        closeIconLabel.textColor = UIColor.Sphinx.PrimaryRed
        headerView.addSubview(closeIconLabel)

        // Close Button
        closeButton = UIButton()
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closeButtonTouched), for: .touchUpInside)
        headerView.addSubview(closeButton)

        // Prompt Field Container
        promptFieldContainer = UIView()
        promptFieldContainer.translatesAutoresizingMaskIntoConstraints = false
        promptFieldContainer.backgroundColor = .clear
        view.addSubview(promptFieldContainer)

        // Prompt Label
        promptLabel = UILabel()
        promptLabel.translatesAutoresizingMaskIntoConstraints = false
        promptLabel.text = "Add a prompt for your Hive notifications preferences"
        promptLabel.textAlignment = .center
        promptLabel.font = UIFont(name: "Roboto-Regular", size: 15)
        promptLabel.textColor = UIColor.Sphinx.Text
        promptLabel.numberOfLines = 0
        promptFieldContainer.addSubview(promptLabel)

        // Prompt Field View (container with border)
        promptFieldView = UIView()
        promptFieldView.translatesAutoresizingMaskIntoConstraints = false
        promptFieldView.backgroundColor = UIColor.Sphinx.ProfileBG
        promptFieldContainer.addSubview(promptFieldView)

        // Prompt Text View
        promptTextView = UITextView()
        promptTextView.translatesAutoresizingMaskIntoConstraints = false
        promptTextView.backgroundColor = .clear
        promptTextView.textColor = UIColor.Sphinx.Text
        promptTextView.font = UIFont(name: "Roboto-Regular", size: 17)
        promptTextView.delegate = self
        promptFieldView.addSubview(promptTextView)

        // Bottom Container
        let bottomContainer = UIView()
        bottomContainer.translatesAutoresizingMaskIntoConstraints = false
        bottomContainer.backgroundColor = .clear
        view.addSubview(bottomContainer)

        // Save Button
        saveButton = UIButton()
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.setTitle("SAVE", for: .normal)
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.titleLabel?.font = UIFont(name: "Roboto-Regular", size: 17)
        saveButton.backgroundColor = UIColor.Sphinx.PrimaryGreen
        saveButton.addTarget(self, action: #selector(saveButtonTouched), for: .touchUpInside)
        bottomContainer.addSubview(saveButton)

        // Loading Wheel
        loadingWheel = UIActivityIndicatorView(style: .medium)
        loadingWheel.translatesAutoresizingMaskIntoConstraints = false
        loadingWheel.hidesWhenStopped = true
        bottomContainer.addSubview(loadingWheel)

        // Layout Constraints
        NSLayoutConstraint.activate([
            // Header View
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 50),

            // Title Label
            viewTitle.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            viewTitle.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            // Close Button
            closeButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            closeButton.topAnchor.constraint(equalTo: headerView.topAnchor),
            closeButton.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 50),

            // Close Icon
            closeIconLabel.centerXAnchor.constraint(equalTo: closeButton.centerXAnchor),
            closeIconLabel.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),

            // Prompt Field Container
            promptFieldContainer.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 26),
            promptFieldContainer.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            promptFieldContainer.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),

            // Prompt Label
            promptLabel.topAnchor.constraint(equalTo: promptFieldContainer.topAnchor, constant: 18.5),
            promptLabel.leadingAnchor.constraint(equalTo: promptFieldContainer.leadingAnchor, constant: 15),
            promptLabel.trailingAnchor.constraint(equalTo: promptFieldContainer.trailingAnchor, constant: -15),

            // Prompt Field View
            promptFieldView.topAnchor.constraint(equalTo: promptLabel.bottomAnchor, constant: 12),
            promptFieldView.leadingAnchor.constraint(equalTo: promptFieldContainer.leadingAnchor, constant: 15),
            promptFieldView.trailingAnchor.constraint(equalTo: promptFieldContainer.trailingAnchor, constant: -15),
            promptFieldView.heightAnchor.constraint(equalToConstant: 220),
            promptFieldView.bottomAnchor.constraint(equalTo: promptFieldContainer.bottomAnchor),

            // Prompt Text View
            promptTextView.topAnchor.constraint(equalTo: promptFieldView.topAnchor, constant: 8),
            promptTextView.leadingAnchor.constraint(equalTo: promptFieldView.leadingAnchor, constant: 8),
            promptTextView.trailingAnchor.constraint(equalTo: promptFieldView.trailingAnchor, constant: -8),
            promptTextView.bottomAnchor.constraint(equalTo: promptFieldView.bottomAnchor, constant: -8),

            // Bottom Container
            bottomContainer.topAnchor.constraint(equalTo: promptFieldContainer.bottomAnchor),
            bottomContainer.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 15),
            bottomContainer.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -15),
            bottomContainer.heightAnchor.constraint(equalToConstant: 100),

            // Save Button
            saveButton.trailingAnchor.constraint(equalTo: bottomContainer.trailingAnchor),
            saveButton.centerYAnchor.constraint(equalTo: bottomContainer.centerYAnchor),
            saveButton.widthAnchor.constraint(equalToConstant: 175),
            saveButton.heightAnchor.constraint(equalToConstant: 50),

            // Loading Wheel
            loadingWheel.centerYAnchor.constraint(equalTo: saveButton.centerYAnchor),
            loadingWheel.trailingAnchor.constraint(equalTo: saveButton.leadingAnchor, constant: -20),
        ])
    }

    func configureView() {
        viewTitle.addTextSpacing(value: 2)
        promptLabel.addTextSpacing(value: 2)

        promptFieldView.layer.cornerRadius = 5
        promptFieldView.layer.borderWidth = 1
        promptFieldView.layer.borderColor = UIColor.Sphinx.LightDivider.resolvedCGColor(with: self.view)

        saveButton.layer.cornerRadius = 25
        saveButton.clipsToBounds = true
        saveButton.addShadow(
            location: VerticalLocation.bottom,
            color: UIColor.Sphinx.GreenBorder,
            opacity: 1,
            radius: 0.5,
            bottomhHeight: 1.5
        )
    }

    func loadSavedPrompt() {
        if let savedPrompt: String = UserDefaults.Keys.hiveNotificationPrompt.get() {
            promptTextView.text = savedPrompt
        }
    }

    @objc func saveButtonTouched() {
        view.endEditing(true)

        let promptText = promptTextView.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        UserDefaults.Keys.hiveNotificationPrompt.set(promptText)

        closeButtonTouched()
    }

    @objc func closeButtonTouched() {
        self.dismiss(animated: true, completion: nil)
    }
}

extension HiveConfigurationViewController: UITextViewDelegate {
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        let currentString = textView.text! as NSString
        let currentChangedString = currentString.replacingCharacters(in: range, with: text)

        if currentChangedString.count <= kCharacterLimit {
            return true
        } else {
            return false
        }
    }
}
