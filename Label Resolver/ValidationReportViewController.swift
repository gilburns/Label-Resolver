//
//  ValidationReportViewController.swift
//  Label Resolver
//
//  Created by Gil Burns on 2/1/25.
//

import Cocoa

class ValidationReportViewController: NSViewController {
    @IBOutlet weak var issuesTextView: NSTextView!
    @IBOutlet weak var warningsTextView: NSTextView!

    @IBOutlet weak var okButton: NSButton!

    var issues: [String] = []
    var warnings: [String] = []

    /// True when the issues/warnings arrays contain real findings (not just placeholder text).
    var hasRealIssues: Bool = false
    var hasRealWarnings: Bool = false

    /// Set to true before presentation when there are auto-fixable formatting problems.
    var canFix: Bool = false

    /// Called (after the sheet is dismissed) when the user confirms they want fixes applied.
    var onFixRequested: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        updateReport()
        if hasRealIssues || hasRealWarnings {
            addCopyButton()
        }
        if canFix {
            addFixButton()
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        // Make OK button the first responder
        self.view.window?.makeFirstResponder(okButton)
    }

    @IBAction func closeReport(_ sender: NSButton) {
        self.dismiss(self)
    }

    private func addCopyButton() {
        let copyButton = NSButton(title: "Copy Report", target: self, action: #selector(copyReportClicked(_:)))
        copyButton.bezelStyle = .rounded
        copyButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(copyButton)

        NSLayoutConstraint.activate([
            copyButton.centerYAnchor.constraint(equalTo: okButton.centerYAnchor),
            copyButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
        ])
    }

    @objc private func copyReportClicked(_ sender: NSButton) {
        var sections: [String] = []

        if hasRealIssues {
            sections.append("**Issues:**\n\n" + issuesTextView.string.trimmingCharacters(in: .newlines))
        }
        if hasRealWarnings {
            sections.append("**Warnings:**\n\n" + warningsTextView.string.trimmingCharacters(in: .newlines))
        }

        let report = sections.joined(separator: "\n\n---\n\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(report, forType: .string)
    }

    private func addFixButton() {
        let fixButton = NSButton(title: "Fix Issues…", target: self, action: #selector(fixIssuesClicked(_:)))
        fixButton.bezelStyle = .rounded
        fixButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(fixButton)

        NSLayoutConstraint.activate([
            fixButton.centerYAnchor.constraint(equalTo: okButton.centerYAnchor),
            fixButton.trailingAnchor.constraint(equalTo: okButton.leadingAnchor, constant: -12),
        ])
    }

    @objc private func fixIssuesClicked(_ sender: NSButton) {
        dismiss(self)
        onFixRequested?()
    }

    func updateReport() {
        let issuesText = issues.isEmpty ? "No issues found." : issues.joined(separator: "\n")
        let warningsText = warnings.isEmpty ? "No warnings found." : warnings.joined(separator: "\n")

        issuesTextView.string = issuesText
        warningsTextView.string = warningsText

        issuesTextView.textColor = issues.isEmpty ? .gray : .red
        warningsTextView.textColor = warnings.isEmpty ? .gray : .orange
    }
}
