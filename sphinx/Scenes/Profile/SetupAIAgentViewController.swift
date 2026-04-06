//
//  SetupAIAgentViewController.swift
//  sphinx
//
//  Created on 06/04/2025.
//  Copyright © 2025 Sphinx. All rights reserved.
//

import UIKit

class SetupAIAgentViewController: UIViewController {
    
    // MARK: - Views (built programmatically)
    
    private var scrollView: UIScrollView!
    private var contentView: UIView!
    
    private var providerContainerView: UIView!
    private var providerTextField: UITextField!
    
    private var apiKeyContainerView: UIView!
    private var apiKeyTextField: UITextField!
    
    private var agentNameContainerView: UIView!
    private var agentNameTextField: UITextField!
    
    private var confirmButton: UIButton!
    
    // MARK: - Dependencies
    
    let userData = UserData.sharedInstance
    
    // MARK: - Instantiate
    
    static func instantiate() -> SetupAIAgentViewController {
        return StoryboardScene.Profile.setupAIAgentViewController.instantiate()
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Configure AI Agent"
        view.backgroundColor = UIColor.Sphinx.Body
        buildUI()
        configureView()
    }
    
    // MARK: - UI Construction
    
    private func buildUI() {
        // Scroll view
        scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
        
        contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
        
        // Build field rows
        providerContainerView = buildFieldRow(
            headerText: "Provider",
            textField: buildTextField(placeholder: "Anthropic", isEditable: false),
            storeTextField: &providerTextField
        )
        
        apiKeyContainerView = buildFieldRow(
            headerText: "API Key",
            textField: buildTextField(placeholder: "Enter your API key", isEditable: true),
            storeTextField: &apiKeyTextField
        )
        
        agentNameContainerView = buildFieldRow(
            headerText: "Agent Name",
            textField: buildTextField(placeholder: "Sphinx Agent", isEditable: true),
            storeTextField: &agentNameTextField
        )
        
        contentView.addSubview(providerContainerView)
        contentView.addSubview(apiKeyContainerView)
        contentView.addSubview(agentNameContainerView)
        
        // Confirm button
        confirmButton = UIButton(type: .system)
        confirmButton.translatesAutoresizingMaskIntoConstraints = false
        confirmButton.setTitle("Confirm", for: .normal)
        confirmButton.setTitleColor(.white, for: .normal)
        confirmButton.backgroundColor = UIColor.Sphinx.PrimaryBlue
        confirmButton.titleLabel?.font = UIFont(name: "Roboto-Medium", size: 16) ?? UIFont.systemFont(ofSize: 16, weight: .medium)
        confirmButton.layer.cornerRadius = 9.0
        confirmButton.clipsToBounds = true
        confirmButton.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)
        contentView.addSubview(confirmButton)
        
        let margin: CGFloat = 20
        
        NSLayoutConstraint.activate([
            providerContainerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            providerContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: margin),
            providerContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -margin),
            
            apiKeyContainerView.topAnchor.constraint(equalTo: providerContainerView.bottomAnchor, constant: 16),
            apiKeyContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: margin),
            apiKeyContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -margin),
            
            agentNameContainerView.topAnchor.constraint(equalTo: apiKeyContainerView.bottomAnchor, constant: 16),
            agentNameContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: margin),
            agentNameContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -margin),
            
            confirmButton.topAnchor.constraint(equalTo: agentNameContainerView.bottomAnchor, constant: 32),
            confirmButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: margin),
            confirmButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -margin),
            confirmButton.heightAnchor.constraint(equalToConstant: 50),
            confirmButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32)
        ])
        
        // Add shadows after layout
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.providerContainerView.addShadow(location: VerticalLocation.center, color: UIColor.black, opacity: 0.2, radius: 2.0)
            self.apiKeyContainerView.addShadow(location: VerticalLocation.center, color: UIColor.black, opacity: 0.2, radius: 2.0)
            self.agentNameContainerView.addShadow(location: VerticalLocation.center, color: UIColor.black, opacity: 0.2, radius: 2.0)
        }
    }
    
    private func buildFieldRow(
        headerText: String,
        textField: UITextField,
        storeTextField: inout UITextField!
    ) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = UIColor.Sphinx.Body
        container.layer.cornerRadius = 9.0
        container.clipsToBounds = false
        
        let header = UILabel()
        header.translatesAutoresizingMaskIntoConstraints = false
        header.text = headerText
        header.font = UIFont(name: "Roboto-Regular", size: 12) ?? UIFont.systemFont(ofSize: 12)
        header.textColor = UIColor.Sphinx.SecondaryText
        
        container.addSubview(header)
        container.addSubview(textField)
        storeTextField = textField
        
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 80),
            
            header.topAnchor.constraint(equalTo: container.topAnchor, constant: 14),
            header.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            header.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            
            textField.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 4),
            textField.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            textField.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            textField.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -10)
        ])
        
        return container
    }
    
    private func buildTextField(placeholder: String, isEditable: Bool) -> UITextField {
        let tf = UITextField()
        tf.translatesAutoresizingMaskIntoConstraints = false
        tf.placeholder = placeholder
        tf.font = UIFont(name: "Roboto-Medium", size: 14) ?? UIFont.systemFont(ofSize: 14, weight: .medium)
        tf.textColor = UIColor.Sphinx.PrimaryText
        tf.borderStyle = .none
        tf.isUserInteractionEnabled = isEditable
        return tf
    }
    
    // MARK: - Configuration
    
    private func configureView() {
        // Pre-populate fields from stored values
        providerTextField.text = userData.getAIAgentValue(with: .aiAgentProvider)
            ?? AIAgentManager.AIProvider.anthropic.rawValue
        apiKeyTextField.text = userData.getAIAgentValue(with: .aiAgentApiKey) ?? ""
        agentNameTextField.text = UserContact.getContactWith(id: AIAgentManager.agentLocalId)?.nickname
            ?? "Sphinx Agent"
        
        // Provider tap gesture on entire row
        let tap = UITapGestureRecognizer(target: self, action: #selector(providerFieldTapped))
        providerContainerView.addGestureRecognizer(tap)
        providerContainerView.isUserInteractionEnabled = true
        
        // API key change monitoring
        apiKeyTextField.addTarget(self, action: #selector(textFieldChanged), for: .editingChanged)
        
        updateConfirmButton()
    }
    
    // MARK: - Actions
    
    @objc private func providerFieldTapped() {
        let alert = UIAlertController(title: "Select Provider", message: nil, preferredStyle: .actionSheet)
        for provider in AIAgentManager.AIProvider.allCases {
            alert.addAction(UIAlertAction(title: provider.rawValue, style: .default) { [weak self] _ in
                self?.providerTextField.text = provider.rawValue
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    @objc private func textFieldChanged() {
        updateConfirmButton()
    }
    
    private func updateConfirmButton() {
        let hasApiKey = !(apiKeyTextField.text?.trimmingCharacters(in: .whitespaces).isEmpty ?? true)
        confirmButton.isEnabled = hasApiKey
        confirmButton.alpha = hasApiKey ? 1.0 : 0.5
    }
    
    @objc private func confirmTapped() {
        let provider = providerTextField.text?.isEmpty == false
            ? providerTextField.text!
            : AIAgentManager.AIProvider.anthropic.rawValue
        let apiKey = apiKeyTextField.text ?? ""
        let agentName = agentNameTextField.text?.isEmpty == false
            ? agentNameTextField.text!
            : "Sphinx Agent"
        
        userData.save(aiAgentValue: provider, for: .aiAgentProvider)
        userData.save(aiAgentValue: apiKey, for: .aiAgentApiKey)
        AIAgentManager.sharedInstance.reconfigure()
        
        if let contact = UserContact.getContactWith(id: AIAgentManager.agentLocalId) {
            contact.nickname = agentName
            CoreDataManager.sharedManager.saveContext()
        }
        
        navigationController?.popViewController(animated: true)
    }
}
