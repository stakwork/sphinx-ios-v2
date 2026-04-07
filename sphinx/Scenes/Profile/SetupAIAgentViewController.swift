//
//  SetupAIAgentViewController.swift
//  sphinx
//
//  Created on 06/04/2025.
//  Copyright © 2025 Sphinx. All rights reserved.
//

import UIKit

class SetupAIAgentViewController: UIViewController {
    
    @IBOutlet weak var fieldsContainerView: UIView!
    @IBOutlet weak var providerTextField: UITextField!
    @IBOutlet weak var apiKeyTextField: UITextField!
    @IBOutlet weak var agentNameTextField: UITextField!
    @IBOutlet weak var confirmButton: UIButton!
    
    let userData = UserData.sharedInstance
    
    static func instantiate() -> SetupAIAgentViewController {
        return StoryboardScene.Profile.setupAIAgentViewController.instantiate()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Configure AI Agent"
        configureView()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        confirmButton.layer.cornerRadius = 9.0
        confirmButton.clipsToBounds = true
        fieldsContainerView.addShadow(
            location: VerticalLocation.center,
            color: UIColor.black,
            opacity: 0.2,
            radius: 2.0
        )
    }
    
    private func configureView() {
        // Pre-populate fields
        providerTextField.text = userData.getAIAgentValue(with: .aiAgentProvider)
            ?? AIAgentManager.AIProvider.anthropic.rawValue
        apiKeyTextField.text = userData.getAIAgentValue(with: .aiAgentApiKey) ?? ""
        agentNameTextField.text = UserContact.getContactWith(id: AIAgentManager.agentLocalId)?.nickname
            ?? "Sphinx Agent"
        
        updateConfirmButton()
        
        // Provider field is read-only — tap the row to pick
        providerTextField.isUserInteractionEnabled = false
        let tap = UITapGestureRecognizer(target: self, action: #selector(providerFieldTapped))
        providerTextField.superview?.addGestureRecognizer(tap)
        providerTextField.superview?.isUserInteractionEnabled = true
        
        apiKeyTextField.addTarget(self, action: #selector(textFieldChanged), for: .editingChanged)
    }
    
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
    
    @IBAction func confirmTapped() {
        let provider = providerTextField.text?.isEmpty == false
            ? providerTextField.text!
            : AIAgentManager.AIProvider.anthropic.rawValue
        let apiKey = apiKeyTextField.text ?? ""
        let agentName = agentNameTextField.text?.isEmpty == false
            ? agentNameTextField.text!
            : "Sphinx Agent"
        
        userData.save(aiAgentValue: provider, for: .aiAgentProvider)
        userData.save(aiAgentValue: apiKey, for: .aiAgentApiKey)
        
        // Reconfigure the AI engine (updates provider + key)
        AIAgentManager.sharedInstance.reconfigure()
        
        // Create agent contact + chat if not already present
        if UserContact.getContactWith(id: AIAgentManager.agentLocalId) == nil {
            AIAgentManager.sharedInstance.createAgentContactAndChatIfNeeded()
        }
        
        // Apply any custom name change
        if let contact = UserContact.getContactWith(id: AIAgentManager.agentLocalId) {
            contact.nickname = agentName
            CoreDataManager.sharedManager.saveContext()
        }
        
        navigationController?.popViewController(animated: true)
    }
}
