//
//  DiagnosticsViewController.swift
//  sphinx
//
//  Created by Sphinx on 2026-05-05.
//  Copyright © 2026 Sphinx. All rights reserved.
//

import UIKit

class DiagnosticsViewController: UIViewController {

    // MARK: - IBOutlets

    @IBOutlet weak var headerView: UIView!
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var exportButton: UIButton!

    // MARK: - Factory

    static func instantiate() -> DiagnosticsViewController {
        return StoryboardScene.Profile.diagnosticsViewController.instantiate()
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        loadExistingEntries()
        subscribeToNewEntries()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scrollToBottom(animated: false)
    }

    // MARK: - IBActions

    @IBAction func backButtonTouched() {
        navigationController?.popViewController(animated: true)
    }

    @IBAction func exportTapped() {
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
        activityVC.popoverPresentationController?.sourceView = exportButton
        present(activityVC, animated: true)
    }

    // MARK: - Private helpers

    private func loadExistingEntries() {
        let attrStr = NSMutableAttributedString()
        for entry in AppLogger.shared.entries {
            attrStr.append(attributedLine(for: entry))
        }
        textView.attributedText = attrStr
    }

    private func subscribeToNewEntries() {
        AppLogger.shared.onNewEntry = { [weak self] entry in
            guard let self else { return }
            DispatchQueue.main.async {
                let current = NSMutableAttributedString(attributedString: self.textView.attributedText ?? NSAttributedString())
                current.append(self.attributedLine(for: entry))
                self.textView.attributedText = current
                self.scrollToBottom(animated: true)
            }
        }
    }

    private func attributedLine(for entry: LogEntry) -> NSAttributedString {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        let ts = formatter.string(from: entry.timestamp)

        let mono = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)

        // Timestamp part – always Sphinx.Text colour
        let tsAttr = NSAttributedString(
            string: "[\(ts)] ",
            attributes: [
                .font: mono,
                .foregroundColor: UIColor.Sphinx.Text
            ]
        )

        // Level + message – coloured by level
        let levelColor: UIColor
        switch entry.level {
        case .debug:   levelColor = UIColor.Sphinx.SecondaryText
        case .info:    levelColor = UIColor.Sphinx.PrimaryBlue
        case .warning: levelColor = UIColor.Sphinx.SphinxOrange
        case .error:   levelColor = UIColor.Sphinx.PrimaryRed
        }

        let body = NSAttributedString(
            string: "[\(entry.level.rawValue)] \(entry.message)\n",
            attributes: [
                .font: mono,
                .foregroundColor: levelColor
            ]
        )

        let line = NSMutableAttributedString(attributedString: tsAttr)
        line.append(body)
        return line
    }

    private func scrollToBottom(animated: Bool) {
        guard let text = textView.text, !text.isEmpty else { return }
        let bottom = NSRange(location: textView.text.utf16.count - 1, length: 1)
        textView.scrollRangeToVisible(bottom)
    }
}
