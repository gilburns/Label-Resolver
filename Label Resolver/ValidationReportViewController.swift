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

    override func viewDidLoad() {
        super.viewDidLoad()
        updateReport()
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        // Make OK button the first responder
        self.view.window?.makeFirstResponder(okButton)
    }

    @IBAction func closeReport(_ sender: NSButton) {
        self.dismiss(self)
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
