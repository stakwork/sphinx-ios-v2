//
//  CreateFeatureViewController.swift
//  sphinx
//
//  Created on 2026-03-05.
//  Copyright © 2026 sphinx. All rights reserved.
//

import UIKit

// MARK: - Delegate Protocol

protocol CreateFeatureViewControllerDelegate: AnyObject {
    func didCreateFeature(_ feature: HiveFeature)
}

// MARK: - CreateFeatureViewController

class CreateFeatureViewController: UIViewController {

    // MARK: - Properties

    weak var delegate: CreateFeatureViewControllerDelegate?

    private var workspaceId: String = ""

    private var promptLabel: UILabel!
    private var closeIconLabel: UILabel!
    private var closeButton: UIButton!
    private var promptFieldView: UIView!
    private var messageTextView: UITextView!
    private var sendButton: UIButton!
    private var loadingWheel: UIActivityIndicatorView!

    private var promptFieldViewTopConstraint: NSLayoutConstraint!

    // MARK: - Instantiation

    static func instantiate(workspaceId: String) -> CreateFeatureViewController {
        let vc = StoryboardScene.Dashboard.createFeatureViewController.instantiate()
        vc.workspaceId = workspaceId
        vc.modalPresentationStyle = .automatic
        return vc
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        configureView()
        setupKeyboardObservers()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - View Setup

    private func setupViews() {
        view.backgroundColor = UIColor.Sphinx.Body

        // Header View
        let headerView = UIView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.backgroundColor = .clear
        view.addSubview(headerView)

        // Close Icon Label (Material Icons)
        closeIconLabel = UILabel()
        closeIconLabel.translatesAutoresizingMaskIntoConstraints = false
        closeIconLabel.text = "\u{E5CD}"
        closeIconLabel.font = UIFont(name: "MaterialIcons-Regular", size: 20)
        closeIconLabel.textColor = UIColor.Sphinx.WashedOutReceivedText
        headerView.addSubview(closeIconLabel)

        // Close Button
        closeButton = UIButton()
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closeButtonTouched), for: .touchUpInside)
        headerView.addSubview(closeButton)

        // Prompt Label
        promptLabel = UILabel()
        promptLabel.translatesAutoresizingMaskIntoConstraints = false
        promptLabel.text = "What job are you trying to solve?"
        promptLabel.textAlignment = .center
        promptLabel.font = UIFont(name: "Roboto-Regular", size: 16)
        promptLabel.textColor = UIColor.Sphinx.Text
        promptLabel.numberOfLines = 0
        view.addSubview(promptLabel)

        // Prompt Field View (bordered container)
        promptFieldView = UIView()
        promptFieldView.translatesAutoresizingMaskIntoConstraints = false
        promptFieldView.backgroundColor = UIColor.Sphinx.ProfileBG
        view.addSubview(promptFieldView)

        // Message Text View
        messageTextView = UITextView()
        messageTextView.translatesAutoresizingMaskIntoConstraints = false
        messageTextView.backgroundColor = .clear
        messageTextView.textColor = UIColor.Sphinx.Text
        messageTextView.font = UIFont(name: "Roboto-Regular", size: 17)
        messageTextView.isScrollEnabled = true
        promptFieldView.addSubview(messageTextView)

        // Bottom Container
        let bottomContainer = UIView()
        bottomContainer.translatesAutoresizingMaskIntoConstraints = false
        bottomContainer.backgroundColor = .clear
        view.addSubview(bottomContainer)

        // Send Button
        sendButton = UIButton()
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        sendButton.setTitle("SEND", for: .normal)
        sendButton.setTitleColor(.white, for: .normal)
        sendButton.titleLabel?.font = UIFont(name: "Roboto-Regular", size: 17)
        sendButton.backgroundColor = UIColor.Sphinx.PrimaryBlue
        sendButton.addTarget(self, action: #selector(sendButtonTouched), for: .touchUpInside)
        bottomContainer.addSubview(sendButton)

        // Loading Wheel
        loadingWheel = UIActivityIndicatorView(style: .medium)
        loadingWheel.translatesAutoresizingMaskIntoConstraints = false
        loadingWheel.hidesWhenStopped = true
        bottomContainer.addSubview(loadingWheel)

        // Store the top constraint so we can adjust for keyboard
        promptFieldViewTopConstraint = promptFieldView.topAnchor.constraint(
            equalTo: promptLabel.bottomAnchor, constant: 16
        )

        // Layout Constraints
        NSLayoutConstraint.activate([
            // Header View
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 50),

            // Close Button (50×50 tap target, top-right)
            closeButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            closeButton.topAnchor.constraint(equalTo: headerView.topAnchor),
            closeButton.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 50),

            // Close Icon centred in close button
            closeIconLabel.centerXAnchor.constraint(equalTo: closeButton.centerXAnchor),
            closeIconLabel.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),

            // Prompt Label
            promptLabel.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 20),
            promptLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            promptLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            promptLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            // Prompt Field View
            promptFieldViewTopConstraint,
            promptFieldView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            promptFieldView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            promptFieldView.heightAnchor.constraint(lessThanOrEqualTo: view.heightAnchor, multiplier: 0.5),

            // Message Text View inside Prompt Field View
            messageTextView.topAnchor.constraint(equalTo: promptFieldView.topAnchor, constant: 8),
            messageTextView.leadingAnchor.constraint(equalTo: promptFieldView.leadingAnchor, constant: 16),
            messageTextView.trailingAnchor.constraint(equalTo: promptFieldView.trailingAnchor, constant: -16),
            messageTextView.bottomAnchor.constraint(equalTo: promptFieldView.bottomAnchor, constant: -8),
            messageTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 120),

            // Bottom Container
            bottomContainer.topAnchor.constraint(equalTo: promptFieldView.bottomAnchor),
            bottomContainer.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            bottomContainer.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            bottomContainer.heightAnchor.constraint(equalToConstant: 100),

            // Send Button — right-aligned, 175×50
            sendButton.trailingAnchor.constraint(equalTo: bottomContainer.trailingAnchor),
            sendButton.centerYAnchor.constraint(equalTo: bottomContainer.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 175),
            sendButton.heightAnchor.constraint(equalToConstant: 50),

            // Loading Wheel — left of send button
            loadingWheel.centerYAnchor.constraint(equalTo: sendButton.centerYAnchor),
            loadingWheel.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -20),
        ])
    }

    private func configureView() {
        promptFieldView.layer.cornerRadius = 5
        promptFieldView.layer.borderWidth = 1
        promptFieldView.layer.borderColor = UIColor.Sphinx.LightDivider.resolvedCGColor(with: self.view)

        sendButton.layer.cornerRadius = 25
        sendButton.clipsToBounds = true
        sendButton.addShadow(
            location: VerticalLocation.bottom,
            color: UIColor.Sphinx.PrimaryBlueBorder,
            opacity: 1,
            radius: 0.5,
            bottomhHeight: 1.5
        )
    }

    // MARK: - Keyboard Handling

    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    @objc private func keyboardWillShow(notification: NSNotification) {
        guard let userInfo = notification.userInfo,
              let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
            return
        }

        let keyboardHeight = keyboardFrame.height - view.safeAreaInsets.bottom
        promptFieldViewTopConstraint.constant = max(16 - keyboardHeight, -(keyboardHeight - 20))

        UIView.animate(withDuration: duration) {
            self.view.layoutIfNeeded()
        }
    }

    @objc private func keyboardWillHide(notification: NSNotification) {
        guard let userInfo = notification.userInfo,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
            return
        }

        promptFieldViewTopConstraint.constant = 16

        UIView.animate(withDuration: duration) {
            self.view.layoutIfNeeded()
        }
    }

    // MARK: - Actions

    @objc private func closeButtonTouched() {
        dismiss(animated: true, completion: nil)
    }

    @objc private func sendButtonTouched() {
        view.endEditing(true)

        let message = messageTextView.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !message.isEmpty else {
            AlertHelper.showAlert(
                title: "Error",
                message: "Please enter a message before sending."
            )
            return
        }

        // Disable button and start loading
        sendButton.isEnabled = false
        loadingWheel.startAnimating()

        let title = String(message.prefix(100))

        // Step 1: Create the feature
        API.sharedInstance.createFeatureWithAuth(
            workspaceId: workspaceId,
            title: title,
            callback: { [weak self] feature in
                guard let self = self else { return }

                guard let feature = feature else {
                    DispatchQueue.main.async {
                        self.sendButton.isEnabled = true
                        self.loadingWheel.stopAnimating()
                        AlertHelper.showAlert(
                            title: "Error",
                            message: "Failed to create feature. Please try again."
                        )
                    }
                    return
                }

                // Step 2: Send the first chat message (fire-and-forget)
                API.sharedInstance.sendFeatureChatMessageWithAuth(
                    featureId: feature.id,
                    message: message,
                    callback: { [weak self] _ in
                        DispatchQueue.main.async {
                            self?.finishCreation(feature: feature)
                        }
                    },
                    errorCallback: { [weak self] in
                        // Step 2 failed — proceed anyway (match web behaviour)
                        DispatchQueue.main.async {
                            self?.finishCreation(feature: feature)
                        }
                    }
                )
            },
            errorCallback: { [weak self] in
                DispatchQueue.main.async {
                    self?.sendButton.isEnabled = true
                    self?.loadingWheel.stopAnimating()
                    AlertHelper.showAlert(
                        title: "Error",
                        message: "Failed to create feature. Please try again."
                    )
                }
            }
        )
    }

    private func finishCreation(feature: HiveFeature) {
        delegate?.didCreateFeature(feature)
        dismiss(animated: true, completion: nil)
    }
}
