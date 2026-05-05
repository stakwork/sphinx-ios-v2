//
//  DiagnosticsViewController.swift
//  sphinx
//
//  Created by Sphinx on 2026-05-05.
//  Copyright © 2026 Sphinx. All rights reserved.
//

import UIKit

class DiagnosticsViewController: UIViewController {

    // MARK: - UI

    private let textView: UITextView = {
        let tv = UITextView()
        tv.isEditable = false
        tv.isSelectable = true
        tv.backgroundColor = UIColor.Sphinx.Body
        tv.textColor = UIColor.Sphinx.Text
        tv.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    // MARK: - Factory

    static func instantiate() -> DiagnosticsViewController {
        return DiagnosticsViewController()
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadExistingEntries()
        subscribeToNewEntries()
    }

    // MARK: - Setup

    private func setupUI() {
        title = "diagnostics.title".localized
        view.backgroundColor = UIColor.Sphinx.Body

        // Export button (right)
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "diagnostics.export-button".localized,
            style: .plain,
            target: self,
            action: #selector(exportTapped)
        )

        // Clear button (left)
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "diagnostics.clear-button".localized,
            style: .plain,
            target: self,
            action: #selector(clearTapped)
        )

        view.addSubview(textView)
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }

    private func loadExistingEntries() {
        let lines = AppLogger.shared.entries.map { formattedLine($0) }.joined(separator: "\n")
        textView.text = lines.isEmpty ? "" : lines + "\n"
        scrollToBottom(animated: false)
    }

    private func subscribeToNewEntries() {
        AppLogger.shared.onNewEntry = { [weak self] entry in
            guard let self else { return }
            DispatchQueue.main.async {
                self.appendLine(self.formattedLine(entry))
            }
        }
    }

    // MARK: - Helpers

    private func formattedLine(_ entry: LogEntry) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let ts = formatter.string(from: entry.timestamp)
        return "[\(ts)] [\(entry.level.rawValue)] \(entry.message)"
    }

    private func appendLine(_ line: String) {
        let current = textView.text ?? ""
        textView.text = current + line + "\n"
        scrollToBottom(animated: true)
    }

    private func scrollToBottom(animated: Bool) {
        guard !textView.text.isEmpty else { return }
        let range = NSRange(location: textView.text.utf16.count - 1, length: 1)
        textView.scrollRangeToVisible(range)
    }

    // MARK: - Actions

    @objc private func exportTapped() {
        guard let url = AppLogger.shared.exportedFileURL() else {
            let alert = UIAlertController(
                title: "Export Failed",
                message: "Could not write log file.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        activityVC.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItem
        present(activityVC, animated: true)
    }

    @objc private func clearTapped() {
        AppLogger.shared.clear()
        textView.text = ""
    }
}
