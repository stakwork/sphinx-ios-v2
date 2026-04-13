//
//  BiometricLockViewController.swift
//  sphinx
//

import UIKit

class BiometricLockViewController: UIViewController {

    let authHelper = BiometricAuthenticationHelper()
    var loggingCompletion: (() -> ())? = nil

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.Sphinx.Body
        setupLockIcon()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        triggerBiometric()
    }

    private func setupLockIcon() {
        let imageView = UIImageView(image: UIImage(systemName: "lock.fill"))
        imageView.tintColor = UIColor.Sphinx.PrimaryText
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 80),
            imageView.heightAnchor.constraint(equalToConstant: 80)
        ])
    }

    func triggerBiometric() {
        // Use .deviceOwnerAuthentication so that when biometrics fail and the user
        // taps "Enter Passcode", iOS handles device passcode entry natively and
        // still calls back with success = true on correct entry.
        authHelper.authenticationAction(policy: .deviceOwnerAuthentication) { [weak self] success in
            guard let self = self else { return }
            if success {
                self.loggingCompletion?()
                WindowsManager.sharedInstance.removeCoveringWindow()
            }
            // On failure or cancel: stay on lock screen, user must re-attempt or leave
        }
    }
}
