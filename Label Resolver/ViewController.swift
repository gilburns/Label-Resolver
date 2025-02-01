//
//  ViewController.swift
//  Label Resolver
//
//  Created by Gil Burns on 1/31/25.
//

import Cocoa

class ViewController: NSViewController {

    @IBOutlet weak var labelTitleTextField: NSTextField!
    
    @IBOutlet weak var labelNameTextField: NSTextField!
    @IBOutlet weak var labelTypeTextField: NSTextField!
    @IBOutlet weak var labelDownloadURLTextField: NSTextField!
    @IBOutlet weak var labelExpectedTeamIdTextField: NSTextField!
    @IBOutlet weak var labelAppNewVersionTextField: NSTextField!
    @IBOutlet weak var labelVersionKeyTextField: NSTextField!
    @IBOutlet weak var labelPackageIDTextField: NSTextField!
    @IBOutlet weak var labelArchiveNameTextField: NSTextField!
    @IBOutlet weak var labelAppNameTextField: NSTextField!
    @IBOutlet weak var labelAppCustomVersionTextField: NSTextField!
    @IBOutlet weak var labelTargetDirTextField: NSTextField!
    @IBOutlet weak var labelBlockingProcessesTextField: NSTextField!
    @IBOutlet weak var labelPkgNameTextField: NSTextField!
    @IBOutlet weak var labelUpdateToolTextField: NSTextField!
    @IBOutlet weak var labelUpdateArgsToolTextField: NSTextField!
    @IBOutlet weak var labelUpdateToolRunAsTextField: NSTextField!
    @IBOutlet weak var labelCLIInstallTextField: NSTextField!
    @IBOutlet weak var labelCLIArgsTextField: NSTextField!
    @IBOutlet weak var labelInstallerToolTextField: NSTextField!
    @IBOutlet weak var labelCurlOptionsTextField: NSTextField!
    
    @IBOutlet weak var labelFileContents: CopyInterceptingTextView!

    @IBOutlet weak var dragDropView: DragDropView!

    @IBOutlet weak var reloadButton: NSButton!
    
    @IBOutlet weak var loadingLabel: NSProgressIndicator!
    
    // Create a reusable HelpPopover instance
    private let helpPopover = HelpPopover()

    // store the path to the label we are inspecting
    private var labelPath: String?

    // store the data from the resolved label variables
    var labelData: LabelInfo?

    // Can store a file path or a remote URL
    private var labelPathOrURL: String?

    // Stores the real text
    private var originalLabelFileText: String = ""

    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Disable reload button at startup
        reloadButton.isEnabled = false

        // Handle when a file is dropped
        dragDropView.onFileDropped = { fileURL in
            self.labelPath = fileURL.path
            let fileName = fileURL.lastPathComponent
            self.labelTitleTextField.stringValue = "Details for: \(fileName)"
            
            // Load the label file
            self.loadLabelFileAndRunScript()
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        
        // Ensure the window accepts drags
        self.view.window?.registerForDraggedTypes([.fileURL])
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


    // MARK: - Actions - Local Label
    
    @IBAction func openLabelFileMenuItemClicked(_ sender: NSMenuItem) {
        let dialog = NSOpenPanel()
        dialog.title = "Choose a Label File"
        dialog.canChooseDirectories = false
        dialog.canChooseFiles = true
        dialog.allowedContentTypes = [.plainText]
        dialog.isExtensionHidden = false
        dialog.allowsMultipleSelection = false

        if dialog.runModal() == .OK, let selectedURL = dialog.url {
            labelPath = selectedURL.path
            labelTitleTextField.stringValue = "Details for: \(selectedURL.lastPathComponent)"

            // Reuse the existing function that loads and processes the label file
            loadLabelFileAndRunScript()
        }
    }
    
    // MARK: - Actions - Remote Label
    @IBAction func openRemoteLabelFileClicked(_ sender: Any) {
        let alert = NSAlert()
        alert.messageText = "Enter URL for Remote Label.sh"
        alert.informativeText = "Provide the direct HTTP/HTTPS URL of the label.sh file to download and process."
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        textField.placeholderString = "https://example.com/label.sh"
        alert.accessoryView = textField

        let response = alert.runModal()
        if response == .alertFirstButtonReturn, let urlString = textField.stringValue.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: urlString), url.scheme?.hasPrefix("http") == true {
            
            downloadRemoteLabelFile(from: url)
        }
    }
    
    private func downloadRemoteLabelFile(from url: URL) {
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.showError(message: "Failed to download file: \(error.localizedDescription)")
                    return
                }

                guard let data = data, let fileContents = String(data: data, encoding: .utf8) else {
                    self.showError(message: "Invalid file format or empty content.")
                    return
                }

                // Store the remote URL as the loaded file
                self.labelPathOrURL = url.absoluteString

                // Save file to temp location for processing
                let tempFileURL = self.saveTemporaryLabelFile(contents: fileContents, filename: url.lastPathComponent)

                guard let tempFileURL = tempFileURL else {
                    self.showError(message: "Failed to save remote file for processing.")
                    return
                }

                // Store the downloaded content in the UI
                self.originalLabelFileText = fileContents
                self.labelFileContents.string = fileContents
                self.labelFileContents.toolTip = fileContents

                // Ensure invisible characters are shown (Fix)
                self.showInvisibleCharacters(in: fileContents)

                // Run `process_label.sh` on the temp file
                self.processLabelFile(at: tempFileURL)

                // Update UI
                self.labelTitleTextField.stringValue = "Details for: \(url.lastPathComponent)"
                self.reloadButton.isEnabled = true
            }
        }
        task.resume()
    }

    private func processLabelFile(at fileURL: URL) {
        do {
            // Run the script and get JSON output
            let jsonString = try runZshScript(withLabelPath: fileURL.path)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\r", with: "")

            // Decode JSON output
            guard let jsonData = jsonString.data(using: .utf8) else {
                showError(message: "Error converting JSON string to Data.")
                return
            }

            print(jsonData)
            
            let decoder = JSONDecoder()
            let labelInfo = try decoder.decode(LabelInfo.self, from: jsonData)
            print(labelInfo)

            // Populate UI fields with JSON data
            populateFields(with: labelInfo)

            // Perform full validation (fields + formatting)
            validateLabelFileContents()

        } catch {
            showError(message: "Error processing label file: \(error.localizedDescription)")
        }
    }

    private func saveTemporaryLabelFile(contents: String, filename: String) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFileURL = tempDir.appendingPathComponent(filename)

        // Trim extra blank lines at the end
        let trimmedContents = removeTrailingBlankLines(from: contents)

        do {
            try trimmedContents.write(to: tempFileURL, atomically: true, encoding: .utf8)
            return tempFileURL
        } catch {
            print("Error writing remote file to temp location: \(error.localizedDescription)")
            return nil
        }
    }

    private func removeTrailingBlankLines(from content: String) -> String {
        let lines = content.components(separatedBy: .newlines)

        // Trim only trailing blank lines
        var trimmedLines = lines
        while let last = trimmedLines.last, last.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            trimmedLines.removeLast()
        }

        return trimmedLines.joined(separator: "\n")
    }

    
    private func showError(message: String) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }


    // MARK: - Select File and Load
    @IBAction func selectLabelPathButtonClicked(_ sender: NSButton) {
        let dialog = NSOpenPanel()
        dialog.title = "Choose an Installomator label file…"
        dialog.canChooseDirectories = false
        dialog.canChooseFiles = true
        dialog.allowedContentTypes = [.text]
        dialog.isExtensionHidden = false
        dialog.allowsMultipleSelection = false

        if dialog.runModal() == .OK, let selectedURL = dialog.url {
            labelPath = selectedURL.path
            
            // Extract file name and set the label title
            let fileName = selectedURL.lastPathComponent
            labelTitleTextField.stringValue = "Details for: \(fileName)"

            // Load and process the file
            loadLabelFileAndRunScript()
        }
    }

    // MARK: - Refresh File and Reload
    @IBAction func refreshLabelPathButtonClicked(_ sender: NSButton) {
        guard let lastLoaded = labelPathOrURL else {
            print("No file to reload.")
            showError(message: "No file has been loaded to reload.")
            return
        }

        if lastLoaded.starts(with: "http") {
            // Reload the remote file
            print("Reloading remote file: \(lastLoaded)")
            if let url = URL(string: lastLoaded) {
                downloadRemoteLabelFile(from: url)
            } else {
                showError(message: "Invalid remote file URL.")
            }
        } else {
            // Reload the local file
            print("Reloading local file: \(lastLoaded)")
            labelPath = lastLoaded
            loadLabelFileAndRunScript()
        }
    }

    // MARK: - Load File & Run Script (Shared Function)
    private func loadLabelFileAndRunScript() {
        guard let labelPath = labelPath else {
            print("No label path found.")
            reloadButton.isEnabled = false
            return
        }

        // Store the loaded file path
        labelPathOrURL = labelPath

        loadingLabel.startAnimation(self)

        do {
            let fileContents = try String(contentsOfFile: labelPath, encoding: .utf8)

            // Store original file text for validation
            originalLabelFileText = fileContents

            // Store in NSTextView subclass for reference
            labelFileContents.string = fileContents
            labelFileContents.toolTip = fileContents

            // Display modified version with invisible characters
            showInvisibleCharacters(in: fileContents)

            // Run `process_label.sh` on the file
            let jsonString = try runZshScript(withLabelPath: labelPath)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\r", with: "")

            print(jsonString)
            // Decode JSON output
            guard let jsonData = jsonString.data(using: .utf8) else {
                print("Error converting JSON string to Data.")
                reloadButton.isEnabled = false
                return
            }

            let decoder = JSONDecoder()
            let labelInfo = try decoder.decode(LabelInfo.self, from: jsonData)
            print(labelInfo)

            // Populate UI fields with JSON data
            populateFields(with: labelInfo)

            // Perform full validation
            validateLabelFileContents()

            reloadButton.isEnabled = true

        } catch {
            print("Error loading label file: \(error.localizedDescription)")
            reloadButton.isEnabled = false
        }

        loadingLabel.stopAnimation(self)
    }

    
    // MARK: - Show Invisble Charaters
    private func highlightInvisibleCharacters() {
        guard let textStorage = labelFileContents.textStorage else { return }

        let fullRange = NSRange(location: 0, length: textStorage.length)
        
        // Remove existing highlights to refresh visibility
        textStorage.removeAttribute(.backgroundColor, range: fullRange)

        // Set a subtle gray color to make invisible characters visible
        let invisibleCharacterColor = NSColor.gray.withAlphaComponent(0.1)

        // Regex to find spaces, tabs, and newlines
        let regex = try! NSRegularExpression(pattern: "[ \\t\\n]", options: [])

        regex.enumerateMatches(in: labelFileContents.string, options: [], range: fullRange) { match, _, _ in
            if let matchRange = match?.range {
                textStorage.addAttribute(.backgroundColor, value: invisibleCharacterColor, range: matchRange)
            }
        }
    }

    
    private func showInvisibleCharacters(in text: String) {
        guard let textStorage = labelFileContents.textStorage else { return }

        let attributedString = NSMutableAttributedString(string: text)

        // Define character replacements
        let replacements: [(character: String, replacement: String, color: NSColor)] = [
            (" ", "␣", NSColor.gray.withAlphaComponent(0.5)),  // Space → ␣
            ("\t", "→", NSColor.blue.withAlphaComponent(0.5)), // Tab → →
            ("\n", "⏎\n", NSColor.red.withAlphaComponent(0.5)) // Newline → ⏎
        ]

        for (character, replacement, color) in replacements {
            let range = NSRange(location: 0, length: attributedString.length)
            attributedString.mutableString.replaceOccurrences(of: character, with: replacement, options: [], range: range)

            let regex = try! NSRegularExpression(pattern: NSRegularExpression.escapedPattern(for: replacement))
            regex.enumerateMatches(in: attributedString.string, options: [], range: range) { match, _, _ in
                if let matchRange = match?.range {
                    attributedString.addAttribute(.foregroundColor, value: color, range: matchRange)
                    attributedString.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular), range: matchRange)
                }
            }
        }

        // Fix: Ensure last two lines' `⏎` remain red
        let newlineRegex = try! NSRegularExpression(pattern: "⏎")
        let fullRange = NSRange(location: 0, length: attributedString.length)

        newlineRegex.enumerateMatches(in: attributedString.string, options: [], range: fullRange) { match, _, _ in
            if let matchRange = match?.range {
                attributedString.addAttribute(.foregroundColor, value: NSColor.red.withAlphaComponent(0.5), range: matchRange)
                attributedString.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular), range: matchRange)
            }
        }

        // Ensure the entire text is consistently monospaced
        let fullTextRange = NSRange(location: 0, length: attributedString.length)
        attributedString.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular), range: fullTextRange)

        // Update NSTextView with the corrected attributed text
        textStorage.setAttributedString(attributedString)
    }

    
    // MARK: - Label Processor
    func runZshScript(withLabelPath labelPath: String) throws -> String {
        guard let scriptPath = Bundle.main.path(forResource: "process_label", ofType: "sh") else {
            throw NSError(domain: "Script not found", code: 1)
        }

        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = [scriptPath, labelPath]
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "Failed to read script output", code: 2)
        }

        return output
    }
    

    // MARK: - Populate UI Fields
    private func populateFields(with labelInfo: LabelInfo) {
        labelNameTextField.stringValue = labelInfo.name
        labelTypeTextField.stringValue = labelInfo.type
        labelDownloadURLTextField.stringValue = labelInfo.downloadURL
        labelExpectedTeamIdTextField.stringValue = labelInfo.expectedTeamID
        labelAppNewVersionTextField.stringValue = labelInfo.appNewVersion
        labelVersionKeyTextField.stringValue = labelInfo.versionKey
        labelPackageIDTextField.stringValue = labelInfo.packageID
        labelArchiveNameTextField.stringValue = labelInfo.archiveName
        labelAppNameTextField.stringValue = labelInfo.appName
        labelAppCustomVersionTextField.stringValue = labelInfo.updateToolArguments
        labelTargetDirTextField.stringValue = labelInfo.targetDir
        labelBlockingProcessesTextField.stringValue = labelInfo.blockingProcesses
        labelPkgNameTextField.stringValue = labelInfo.pkgName
        labelUpdateToolTextField.stringValue = labelInfo.updateTool
        labelUpdateArgsToolTextField.stringValue = labelInfo.updateToolArguments
        labelUpdateToolRunAsTextField.stringValue = labelInfo.updateToolRunAsCurrentUser
        labelCLIInstallTextField.stringValue = labelInfo.CLIInstaller
        labelCLIArgsTextField.stringValue = labelInfo.CLIArguments
        labelInstallerToolTextField.stringValue = labelInfo.installerTool
        labelCurlOptionsTextField.stringValue = labelInfo.curlOptions
        
        labelNameTextField.toolTip = labelInfo.name
        labelTypeTextField.toolTip = labelInfo.type
        labelDownloadURLTextField.toolTip = labelInfo.downloadURL
        labelExpectedTeamIdTextField.toolTip = labelInfo.expectedTeamID
        labelAppNewVersionTextField.toolTip = labelInfo.appNewVersion
        labelVersionKeyTextField.toolTip = labelInfo.versionKey
        labelPackageIDTextField.toolTip = labelInfo.packageID
        labelArchiveNameTextField.toolTip = labelInfo.archiveName
        labelAppNameTextField.toolTip = labelInfo.appName
        labelAppCustomVersionTextField.toolTip = labelInfo.updateToolArguments
        labelTargetDirTextField.toolTip = labelInfo.targetDir
        labelBlockingProcessesTextField.toolTip = labelInfo.blockingProcesses
        labelPkgNameTextField.toolTip = labelInfo.pkgName
        labelUpdateToolTextField.toolTip = labelInfo.updateTool
        labelUpdateArgsToolTextField.toolTip = labelInfo.updateToolArguments
        labelUpdateToolRunAsTextField.toolTip = labelInfo.updateToolRunAsCurrentUser
        labelCLIInstallTextField.toolTip = labelInfo.CLIInstaller
        labelCLIArgsTextField.toolTip = labelInfo.CLIArguments
        labelInstallerToolTextField.toolTip = labelInfo.installerTool
        labelCurlOptionsTextField.toolTip = labelInfo.curlOptions

    }

    
    // MARK: - Helper Function to Set Text Field Borders
    private func setTextFieldBorder(_ textField: NSTextField, isValid: Bool, validColor: NSColor, invalidColor: NSColor) {
        textField.layer?.borderWidth = isValid ? 0 : 2
        textField.layer?.borderColor = isValid ? validColor.cgColor : invalidColor.cgColor
    }

    
    // Validate `labelFileContents`
    private func validateLabelFileContents() {
        var issues: [String] = []
        var warnings: [String] = []

        let lines = originalLabelFileText.components(separatedBy: .newlines)
        guard !lines.isEmpty else { return }

        // Run indentation check inside the validation process
        checkIndentationIssues(&issues)

        // Check for extra blank lines after `;;`
        checkTrailingBlankLines(&warnings)

        // Include field-level validation
        let fieldValidationResults = validateFields()
        issues.append(contentsOf: fieldValidationResults.issues)
        warnings.append(contentsOf: fieldValidationResults.warnings)

        // Set border color based on results
        setValidationBorderColor(issues: issues, warnings: warnings)

        // Show validation report
        presentValidationReport(issues: issues, warnings: warnings)
    }

    
    
    private func checkIndentationIssues(_ issues: inout [String]) {
        let lines = originalLabelFileText.components(separatedBy: .newlines)

        var insideCaseBlock = false

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            // Ignore blank lines and comments
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }

            // Detect when the case block starts (first `)`)
            if trimmed.hasSuffix(")") {
                insideCaseBlock = true
                continue
            }

            // Only check indentation after `)`
            if insideCaseBlock {
                let leadingWhitespace = line.prefix(while: { $0 == " " })
                let spaceCount = leadingWhitespace.count

                if line.hasPrefix("\t") {
                    issues.append("Line uses a tab instead of spaces: '\(trimmed)' (Line \(index + 1))")
                } else if spaceCount > 0 && spaceCount % 4 != 0 {
                    issues.append("Line indentation is incorrect (must be a multiple of 4 spaces, found \(spaceCount)): '\(trimmed)' (Line \(index + 1))")
                }
            }
        }
    }

    private func checkTrailingBlankLines(_ warnings: inout [String]) {
        let lines = originalLabelFileText.components(separatedBy: .newlines).reversed()

        var blankLineCount = 0
        var foundNonBlank = false

        for line in lines {
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                blankLineCount += 1
            } else {
                foundNonBlank = true
                break
            }
        }

        if blankLineCount > 1 {
            warnings.append("There are \(blankLineCount) extra blank lines at the end of the file.")
        }
    }

    private func checkFinalLines(_ issues: inout [String]) {
        let lines = originalLabelFileText.components(separatedBy: .newlines)
        
        // Ensure at least 3 meaningful lines (allows trailing blank lines)
        let nonEmptyLines = lines.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        if nonEmptyLines.count < 3 {
            issues.append("File is too short; missing required `;;` structure.")
            return
        }

        // Identify last two meaningful lines
        let lastMeaningfulLine = nonEmptyLines.last ?? ""
        let secondToLastMeaningfulLine = nonEmptyLines.dropLast().last ?? ""

        // Ensure last line is completely empty
        if !lastMeaningfulLine.isEmpty {
            issues.append("Last line should be empty, but found: '\(lastMeaningfulLine)'")
        }

        // Ensure second-to-last line is exactly "    ;;"
        if secondToLastMeaningfulLine != "    ;;" {
            issues.append("Second-to-last line must be exactly '    ;;' (4 spaces + ;;), but found: '\(secondToLastMeaningfulLine)'")
        }
    }

    
    private func validateFields() -> (issues: [String], warnings: [String]) {
        var issues: [String] = []
        var warnings: [String] = []

        // Reset all field borders to default before validation
        resetFieldBorders()

        func setFieldBorder(_ field: NSTextField, color: NSColor) {
            field.layer?.borderColor = color.cgColor
            field.layer?.borderWidth = 2.0
        }

        // Check Label Name
        if labelNameTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("Label Name is required.")
            setFieldBorder(labelNameTextField, color: .red)
        }

        // Check Label Type
        if labelTypeTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("Label Type is required.")
            setFieldBorder(labelTypeTextField, color: .red)
        } else {
            let validTypes = ["dmg", "zip", "bz2", "tbz", "appInDmgInZip", "pkg", "pkgInDmg", "pkgInZip", "pkgInZipInDmg"]
            if !validTypes.contains(labelTypeTextField.stringValue) {
                issues.append("Invalid Label Type: \(labelTypeTextField.stringValue)")
                setFieldBorder(labelTypeTextField, color: .red)
            }
        }

        // Check Download URL format
        let urlString = labelDownloadURLTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if urlString.isEmpty {
            issues.append("Download URL is required.")
            setFieldBorder(labelDownloadURLTextField, color: .red)
        } else if !urlString.lowercased().hasPrefix("http") {
            issues.append("Download URL must start with http or https.")
            setFieldBorder(labelDownloadURLTextField, color: .red)
        } else if let url = URL(string: urlString) {
            // Perform a HEAD request to check URL availability
            checkURLAvailability(url) { isAvailable in
                DispatchQueue.main.async {
                    if !isAvailable {
                        issues.append("Download URL is unreachable or does not return a valid response: \(urlString)")
                        setFieldBorder(self.labelDownloadURLTextField, color: .red)
                    }
                }
            }
        }

        // Check Expected Team ID
        if labelExpectedTeamIdTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("Expected Team ID is required.")
            setFieldBorder(labelExpectedTeamIdTextField, color: .red)
        } else if labelExpectedTeamIdTextField.stringValue.count != 10 {
            issues.append("Expected Team ID must be 10 characters long.")
            setFieldBorder(labelExpectedTeamIdTextField, color: .red)
        }

        // Check Package ID (optional warning)
        if !labelPackageIDTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            warnings.append("Package ID is set, ensure it is necessary.")
            setFieldBorder(labelPackageIDTextField, color: .yellow)
        }

        return (issues, warnings)
    }


    private func checkURLAvailability(_ url: URL, completion: @escaping (Bool) -> Void) {
        var request = URLRequest(url: url)
        
        // Only fetch headers, not the full file
        request.httpMethod = "HEAD"

        let task = URLSession.shared.dataTask(with: request) { _, response, error in
            if let httpResponse = response as? HTTPURLResponse {
                // Consider the URL valid if we get a 200 OK response
                completion(httpResponse.statusCode == 200)
            } else {
                // Invalid response (404, 403, etc.)
                completion(false)
            }
        }
        task.resume()
    }


    private func resetFieldBorders() {
        let fields: [NSTextField] = [
            labelNameTextField, labelTypeTextField, labelDownloadURLTextField,
            labelExpectedTeamIdTextField, labelPackageIDTextField
        ]

        for field in fields {
            field.layer?.borderColor = NSColor.clear.cgColor
            field.layer?.borderWidth = 0.0
        }
    }

    
    private func countTrailingBlankLines() -> Int {
        let lines = originalLabelFileText.components(separatedBy: .newlines)

        var blankLineCount = 0
        for line in lines.reversed() {
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                blankLineCount += 1
            } else {
                break // Stop counting once a non-blank line is found
            }
        }

        return blankLineCount
    }

    private func presentValidationReport(issues: [String], warnings: [String]) {
        DispatchQueue.main.async {
            guard let storyboard = self.storyboard else {
//                print("Error: Storyboard is nil.")
                return
            }

            guard let reportVC = storyboard.instantiateController(withIdentifier: "ValidationReportViewController") as? ValidationReportViewController else {
//                print("Error: Could not instantiate ValidationReportViewController.")
                return
            }

            // Format issues with two lines per issue + blank line separation
            let formattedIssues = issues.map { issue in
                let components = issue.split(separator: ":", maxSplits: 1).map { String($0) }
                if components.count == 2 {
                    return "\(components[0]):\n    \(components[1])\n"
                } else {
                    return issue + "\n"
                }
            }.joined(separator: "\n")

            // Format warnings similarly
            let formattedWarnings = warnings.map { warning in
                let components = warning.split(separator: ":", maxSplits: 1).map { String($0) }
                if components.count == 2 {
                    return "\(components[0]):\n    \(components[1])\n"
                } else {
                    return warning + "\n"
                }
            }.joined(separator: "\n")

            // Pass formatted data to the report view
            reportVC.issues = formattedIssues.isEmpty ? ["No issues found."] : [formattedIssues]
            reportVC.warnings = formattedWarnings.isEmpty ? ["No warnings found."] : [formattedWarnings]

//            print("Presenting Report - Issues: \(issues.count), Warnings: \(warnings.count)")

            // Show the report view as a sheet
            self.presentAsSheet(reportVC)
        }
    }

    private func setValidationBorderColor(issues: [String], warnings: [String]) {
        DispatchQueue.main.async {
            guard let scrollView = self.labelFileContents.enclosingScrollView else {
//                print("No enclosing NSScrollView found.")
                return
            }

            if !issues.isEmpty {
                scrollView.layer?.borderColor = NSColor.red.cgColor
            } else if !warnings.isEmpty {
                scrollView.layer?.borderColor = NSColor.orange.cgColor
            } else {
                scrollView.layer?.borderColor = NSColor.green.cgColor
            }
            
            scrollView.layer?.borderWidth = 2.0
            scrollView.layer?.cornerRadius = 4.0  // Optional: Rounded corners
            scrollView.wantsLayer = true  // Ensure the layer is active
        }
    }

    
    private func validateTrailingBlankLines() {
        guard let textStorage = labelFileContents.textStorage else { return }

        let fullText = originalLabelFileText // Use original text for validation
        let lines = fullText.components(separatedBy: .newlines)

        // Count blank lines at the end
        var blankLineCount = 0
        for line in lines.reversed() {
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                blankLineCount += 1
            } else {
                break // Stop counting once we hit a non-blank line
            }
        }

        if blankLineCount > 1 {
            print("Warning: More than one blank line at the end!")
            highlightExcessBlankLines(blankLineCount)
        }
    }

    
    private func highlightExcessBlankLines(_ count: Int) {
        guard let textStorage = labelFileContents.textStorage else { return }

        let fullText = labelFileContents.string
        let lines = fullText.components(separatedBy: .newlines)

        var blankLineStartIndex: Int?
        var blankLineCount = 0

        for (index, line) in lines.reversed().enumerated() {
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                blankLineCount += 1
                if blankLineCount > 1 {
                    blankLineStartIndex = lines.count - index - 1
                }
            } else {
                break
            }
        }

        guard let startIndex = blankLineStartIndex else { return } // No extra blank lines found

        // Calculate range for highlighting extra blank lines
        let extraBlankLines = lines[startIndex..<lines.count]
        let rangeStart = fullText.count - extraBlankLines.joined(separator: "\n").count
        let rangeLength = extraBlankLines.joined(separator: "\n").count
        let range = NSRange(location: rangeStart, length: rangeLength)

        print("Highlighting excess blank lines in range: \(range)")

        // Highlight in yellow
        textStorage.addAttribute(.backgroundColor, value: NSColor.yellow.withAlphaComponent(0.5), range: range)
    }


    
    // MARK: - Helper Function to Highlight a Line in NSTextView
    private func highlightLine(_ originalText: String, line: String, color: NSColor) {
        guard let textStorage = labelFileContents.textStorage else { return }

        let fullDisplayedText = labelFileContents.string // The modified text in NSTextView
        let modifiedLine = applyInvisibleCharacterReplacements(to: line) // Convert to displayed format

        if modifiedLine.isEmpty {
            print("Warning: Attempted to highlight an empty line.")
            return
        }

        let range = (fullDisplayedText as NSString).range(of: modifiedLine)

        if range.location != NSNotFound {
            textStorage.addAttribute(.backgroundColor, value: color.withAlphaComponent(0.5), range: range)
            print("Highlighted issue in range: \(range)")
        } else {
            print("Warning: Could not find modified text to highlight: '\(modifiedLine)'")
        }
    }

    private func applyInvisibleCharacterReplacements(to text: String) -> String {
        return text
            .replacingOccurrences(of: " ", with: "␣")  // Space → ␣
            .replacingOccurrences(of: "\t", with: "→") // Tab → →
            .replacingOccurrences(of: "\n", with: "⏎\n") // Newline → ⏎
            .trimmingCharacters(in: .whitespacesAndNewlines) // Ensure clean matching
    }

    
    // MARK: - Help Button Actions
    @IBAction func helpPopOverNameButtonClicked(_ sender: NSButton) {
        // Create the full string
        let helpText = NSMutableAttributedString(string: "The display name of the installed application without the .app extensions. For example, \"Firefox\" not \"Firefox.app\".")

        // Add custom styling for the rest of the text
        helpText.addAttributes([
            .foregroundColor: NSColor.textColor,
            .font: NSFont.systemFont(ofSize: 13)
        ], range: NSRange(location: 0, length: helpText.length))

        // Show the popover
        helpPopover.showHelp(anchorView: sender, helpText: helpText)

    }

    @IBAction func helpPopOverTypeButtonClicked(_ sender: NSButton) {
        // Create the full string
        let helpText = NSMutableAttributedString(string: "The type of installation. Possible values:\n\n* \"dmg\" application in disk image file\n    (drag'n drop installation)\n\n* \"zip\" application in zip archive\n    (zip extension)\n\n* \"tbz\" application in tbz archive\n    (tbz extension)\n\n* \"appInDmgInZip\" an app in a dmg file that has been zip'ed\n\n* \"pkg\" flat pkg download\n\n* \"pkgInDmg\" a pkg file inside a disk image\n\n* \"pkgInZip\" a pkg file inside a zip\n")
        
        // Add a hyperlink to page
        let hyperlinkRangeDMG = (helpText.string as NSString).range(of: "\"dmg\"")
        let hyperlinkRangeZIP = (helpText.string as NSString).range(of: "\"zip\"")
        let hyperlinkRangeTBZ = (helpText.string as NSString).range(of: "\"tbz\"")
        let hyperlinkRangeAppInDmgInZip = (helpText.string as NSString).range(of: "\"appInDmgInZip\"")
        let hyperlinkRangePkg = (helpText.string as NSString).range(of: "\"pkg\"")
        let hyperlinkRangePkgInDmg = (helpText.string as NSString).range(of: "\"pkgInDmg\"")
        let hyperlinkRangePkgInZip = (helpText.string as NSString).range(of: "\"pkgInZip\"")
        helpText.addAttribute(.link, value: "https://github.com/Installomator/Installomator/wiki/Label-Variables-Reference", range: hyperlinkRangeDMG)
        helpText.addAttribute(.link, value: "https://github.com/Installomator/Installomator/wiki/Label-Variables-Reference", range: hyperlinkRangeZIP)
        helpText.addAttribute(.link, value: "https://github.com/Installomator/Installomator/wiki/Label-Variables-Reference", range: hyperlinkRangeTBZ)
        helpText.addAttribute(.link, value: "https://github.com/Installomator/Installomator/wiki/Label-Variables-Reference", range: hyperlinkRangeAppInDmgInZip)
        helpText.addAttribute(.link, value: "https://github.com/Installomator/Installomator/wiki/Label-Variables-Reference", range: hyperlinkRangePkg)
        helpText.addAttribute(.link, value: "https://github.com/Installomator/Installomator/wiki/Label-Variables-Reference", range: hyperlinkRangePkgInDmg)
        helpText.addAttribute(.link, value: "https://github.com/Installomator/Installomator/wiki/Label-Variables-Reference", range: hyperlinkRangePkgInZip)
        helpText.addAttributes([
            .foregroundColor: NSColor.systemBlue,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ], range: hyperlinkRangeDMG)


        // Add custom styling for the rest of the text
        helpText.addAttributes([
            .foregroundColor: NSColor.textColor,
            .font: NSFont.systemFont(ofSize: 13)
        ], range: NSRange(location: 0, length: helpText.length))

        // Show the popover
        helpPopover.showHelp(anchorView: sender, helpText: helpText)

    }

    
    @IBAction func helpPopOverDownloadUrlButtonClicked(_ sender: NSButton) {
        // Create the full string
        let helpText = NSMutableAttributedString(string: "The URL from which to download the archive.\n\nThe URL can be generated by a series of commands, for example when you need to parse an xml file for the latest URL. (See labels bbedit, desktoppr, or omnigraffle for examples.)\n\nSometimes version differs between Intel and Apple Silicon versions. (See labels brave,  obsidian, omnidisksweeper, or notion.")
                                                 
        // Add custom styling for the rest of the text
        helpText.addAttributes([
            .foregroundColor: NSColor.textColor,
            .font: NSFont.systemFont(ofSize: 13)
        ], range: NSRange(location: 0, length: helpText.length))

        // Show the popover
        helpPopover.showHelp(anchorView: sender, helpText: helpText)

    }

    @IBAction func helpPopOverExpectedTeamIDButtonClicked(_ sender: NSButton) {
        // Create the full string
        let helpText = NSMutableAttributedString(string: "The 10-character Developer Team ID with which the application or pkg is signed and notarized.")
                                                 
        // Add custom styling for the rest of the text
        helpText.addAttributes([
            .foregroundColor: NSColor.textColor,
            .font: NSFont.systemFont(ofSize: 13)
        ], range: NSRange(location: 0, length: helpText.length))

        // Show the popover
        helpPopover.showHelp(anchorView: sender, helpText: helpText)

    }

    @IBAction func helpPopOverAppNewVersionButtonClicked(_ sender: NSButton) {
        // Create the full string
        let helpText = NSMutableAttributedString(string: "Version of the downloaded software.\n\nWhen given, it will be compared to installed version. This can prevent unnecessary downloads and installations.\n\nInstallomator does not compare the version for being greater or lesser, but only for being different.\n\nThe value must match a version that can be read from the installed app.\n\nWe want this variable for all applications and tools where it is possible. We will question new PRs without this field, and require a reason for not including it.")
                                                 
        // Add custom styling for the rest of the text
        helpText.addAttributes([
            .foregroundColor: NSColor.textColor,
            .font: NSFont.systemFont(ofSize: 13)
        ], range: NSRange(location: 0, length: helpText.length))

        // Show the popover
        helpPopover.showHelp(anchorView: sender, helpText: helpText)

    }

    @IBAction func helpPopOverVersionKeyButtonClicked(_ sender: NSButton) {
        // Create the full string
        let helpText = NSMutableAttributedString(string: "When the version is being compared to the locally installed app, sometimes we need another field than CFBundleShortVersionString.\n\nOften CFBundleVersion is the right one, but technically it could be another field. It's usually dependant on what number the web sites most easily returns.")
                                                 
        // Add custom styling for the rest of the text
        helpText.addAttributes([
            .foregroundColor: NSColor.textColor,
            .font: NSFont.systemFont(ofSize: 13)
        ], range: NSRange(location: 0, length: helpText.length))

        // Show the popover
        helpPopover.showHelp(anchorView: sender, helpText: helpText)

    }

    @IBAction func helpPopOverPackageIDButtonClicked(_ sender: NSButton) {
        // Create the full string
        let helpText = NSMutableAttributedString(string: "Only recommended for non-app installs.\n\nThis variable is for pkg bundle IDs. Very useful if a pkg only installs command line tools, or the app is not located in\n/Applications.")
                                                 
        // Add custom styling for the rest of the text
        helpText.addAttributes([
            .foregroundColor: NSColor.textColor,
            .font: NSFont.systemFont(ofSize: 13)
        ], range: NSRange(location: 0, length: helpText.length))

        // Show the popover
        helpPopover.showHelp(anchorView: sender, helpText: helpText)

    }

    @IBAction func helpPopOverArchiveNameButtonClicked(_ sender: NSButton) {
        // Create the full string
        let helpText = NSMutableAttributedString(string: "The name of the downloaded file. When not given the archiveName is set to $name.$type.")
                                                 
        // Add custom styling for the rest of the text
        helpText.addAttributes([
            .foregroundColor: NSColor.textColor,
            .font: NSFont.systemFont(ofSize: 13)
        ], range: NSRange(location: 0, length: helpText.length))

        // Show the popover
        helpPopover.showHelp(anchorView: sender, helpText: helpText)

    }

    @IBAction func helpPopOverAppNameButtonClicked(_ sender: NSButton) {
        // Create the full string
        let helpText = NSMutableAttributedString(string: "File name of the app bundle in the dmg to verify and copy (include the .app). When not given, the appName is set to $name.app.\n\nThis is also the name of the app that will get reopned, if we closed any blockingProcesses.")
                                                 
        // Add custom styling for the rest of the text
        helpText.addAttributes([
            .foregroundColor: NSColor.textColor,
            .font: NSFont.systemFont(ofSize: 13)
        ], range: NSRange(location: 0, length: helpText.length))

        // Show the popover
        helpPopover.showHelp(anchorView: sender, helpText: helpText)

    }

    @IBAction func helpPopOverAppCustomVersionButtonClicked(_ sender: NSButton) {
        // Create the full string
        let helpText = NSMutableAttributedString(string: "This function can be added to your label, if a specific custom mechanism has to be used for getting the installed version. (Instead of checking the .app version on disk, or checking a pkg receipt)\n\nCommonly used to check the output of a binary command, like /usr/bin/MyApp --version. Example: See labels zulujdk11, zulujdk13, zulujdk15")
                                                 
        // Add custom styling for the rest of the text
        helpText.addAttributes([
            .foregroundColor: NSColor.textColor,
            .font: NSFont.systemFont(ofSize: 13)
        ], range: NSRange(location: 0, length: helpText.length))

        // Show the popover
        helpPopover.showHelp(anchorView: sender, helpText: helpText)

    }

    @IBAction func helpPopOverTargetDirButtonClicked(_ sender: NSButton) {
        // Create the full string
        let helpText = NSMutableAttributedString(string: "dmg or zip: Applications will be copied to this directory. Default value is '/Applications' for dmg and zip installations. pkg: targetDir is used as the install-location. Default is '/'.")
                                                 
        // Add custom styling for the rest of the text
        helpText.addAttributes([
            .foregroundColor: NSColor.textColor,
            .font: NSFont.systemFont(ofSize: 13)
        ], range: NSRange(location: 0, length: helpText.length))

        // Show the popover
        helpPopover.showHelp(anchorView: sender, helpText: helpText)

    }

    @IBAction func helpPopOverBlockingProcessesButtonClicked(_ sender: NSButton) {
        // Create the full string
        let helpText = NSMutableAttributedString(string: "Array of process names that will block the installation or update. If no blockingProcesses array is given the default will be: blockingProcesses=( $name )\n\nWhen a package contains multiple applications, all should be listed, e.g: blockingProcesses=( \"Keynote\" \"Pages\" \"Numbers\" )\n\nWhen a workflow has no blocking processes or it should not be checked (if the pkg will handle this), use blockingProcesses=( NONE )")
                                                 
        // Add custom styling for the rest of the text
        helpText.addAttributes([
            .foregroundColor: NSColor.textColor,
            .font: NSFont.systemFont(ofSize: 13)
        ], range: NSRange(location: 0, length: helpText.length))

        // Show the popover
        helpPopover.showHelp(anchorView: sender, helpText: helpText)

    }

    @IBAction func helpPopOverPkgNameButtonClicked(_ sender: NSButton) {
        // Create the full string
        let helpText = NSMutableAttributedString(string: "Only used for dmgInPkg and dmgInZip) File name of the pkg file inside the dmg or zip. When not given the pkgName is set to $name.pkg.")
                                                 
        // Add custom styling for the rest of the text
        helpText.addAttributes([
            .foregroundColor: NSColor.textColor,
            .font: NSFont.systemFont(ofSize: 13)
        ], range: NSRange(location: 0, length: helpText.length))

        // Show the popover
        helpPopover.showHelp(anchorView: sender, helpText: helpText)

    }

    @IBAction func helpPopOverUpdateToolButtonClicked(_ sender: NSButton) {
        // Create the full string
        let helpText = NSMutableAttributedString(string: "When Installomator detects an existing installation of the application, and the updateTool variable is set then $updateTool $updateArguments Will be run instead of of downloading and installing a complete new version.\n\nUse this when the updateTool does differential and optimized downloads. e.g. msupdate (see various Microsoft labels).")
                                                 
        // Add custom styling for the rest of the text
        helpText.addAttributes([
            .foregroundColor: NSColor.textColor,
            .font: NSFont.systemFont(ofSize: 13)
        ], range: NSRange(location: 0, length: helpText.length))

        // Show the popover
        helpPopover.showHelp(anchorView: sender, helpText: helpText)

    }

    @IBAction func helpPopOverUpdateToolArgsButtonClicked(_ sender: NSButton) {
        // Create the full string
        let helpText = NSMutableAttributedString(string: "When Installomator detects an existing installation of the application, and the updateTool variable is set then $updateTool $updateArguments Will be run instead of of downloading and installing a complete new version.\n\nUse this when the updateTool does differential and optimized downloads. e.g. msupdate (see various Microsoft labels).")

        // Add custom styling for the rest of the text
        helpText.addAttributes([
            .foregroundColor: NSColor.textColor,
            .font: NSFont.systemFont(ofSize: 13)
        ], range: NSRange(location: 0, length: helpText.length))

        // Show the popover
        helpPopover.showHelp(anchorView: sender, helpText: helpText)

    }

    @IBAction func helpPopOverUpdateToolRunAsButtonClicked(_ sender: NSButton) {
        // Create the full string
        let helpText = NSMutableAttributedString(string: "When this variable is set (any value), $updateTool will be run as the current user. Default is unset.")
                                                 
        // Add custom styling for the rest of the text
        helpText.addAttributes([
            .foregroundColor: NSColor.textColor,
            .font: NSFont.systemFont(ofSize: 13)
        ], range: NSRange(location: 0, length: helpText.length))

        // Show the popover
        helpPopover.showHelp(anchorView: sender, helpText: helpText)

    }

    @IBAction func helpPopOverCliInstallerButtonClicked(_ sender: NSButton) {
        // Create the full string
        let helpText = NSMutableAttributedString(string: "If the downloaded dmg is actually an installer that we can call using CLI, we can use these two variables for what to call. We need to define name for the installed app (to be version checked), as well as installerTool for the installer app (if named differently that name. Installomator will add the path to the folder/disk image with the binary, and it will be called like this: $CLIInstaller $CLIArguments\n\nFor most installations CLIInstaller should contain the installerTool for the CLI call (if it’s the same).\n\nWe can support a whole range of other software titles by implementing this. (See label adobecreativeclouddesktop.)")
                                                 
        // Add custom styling for the rest of the text
        helpText.addAttributes([
            .foregroundColor: NSColor.textColor,
            .font: NSFont.systemFont(ofSize: 13)
        ], range: NSRange(location: 0, length: helpText.length))

        // Show the popover
        helpPopover.showHelp(anchorView: sender, helpText: helpText)

    }

    @IBAction func helpPopOverCliArgumentsButtonClicked(_ sender: NSButton) {
        // Create the full string
        let helpText = NSMutableAttributedString(string: "If the downloaded dmg is actually an installer that we can call using CLI, we can use these two variables for what to call. We need to define name for the installed app (to be version checked), as well as installerTool for the installer app (if named differently that name. Installomator will add the path to the folder/disk image with the binary, and it will be called like this: $CLIInstaller $CLIArguments\n\nFor most installations CLIInstaller should contain the installerTool for the CLI call (if it’s the same). We can support a whole range of other software titles by implementing this. (See label adobecreativeclouddesktop.)")

        // Add custom styling for the rest of the text
        helpText.addAttributes([
            .foregroundColor: NSColor.textColor,
            .font: NSFont.systemFont(ofSize: 13)
        ], range: NSRange(location: 0, length: helpText.length))

        // Show the popover
        helpPopover.showHelp(anchorView: sender, helpText: helpText)

    }

    @IBAction func helpPopOverInstallerToolButtonClicked(_ sender: NSButton) {
        // Create the full string
        let helpText = NSMutableAttributedString(string: "Introduced as part of CLIInstaller.\n\nIf the installer in the DMG or ZIP is named differently than the installed app, then this variable can be used to name the installer that should be located after mounting/expanding the downloaded archive. (See label adobecreativeclouddesktop.).")
                                                 
        // Add custom styling for the rest of the text
        helpText.addAttributes([
            .foregroundColor: NSColor.textColor,
            .font: NSFont.systemFont(ofSize: 13)
        ], range: NSRange(location: 0, length: helpText.length))

        // Show the popover
        helpPopover.showHelp(anchorView: sender, helpText: helpText)

    }

    @IBAction func helpPopOverCurlOptionsButtonClicked(_ sender: NSButton) {
        // Create the full string
        let helpText = NSMutableAttributedString(string: "If the downloadURL cannot work directly using curl-command, then we can usually add some options to that command, and the server will return what we need. For instance if the server automatically detects platform due to header fields, we might need to add a header field -H \"User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.1 Safari/605.1.15\".\n\nThis variable should be an array, so it should be surrounded by (). Se labels mmhmm and mochatelnet, or canva for even more headings in a curl request.")
                                                 
        // Add custom styling for the rest of the text
        helpText.addAttributes([
            .foregroundColor: NSColor.textColor,
            .font: NSFont.systemFont(ofSize: 13)
        ], range: NSRange(location: 0, length: helpText.length))

        // Show the popover
        helpPopover.showHelp(anchorView: sender, helpText: helpText)

    }

    
}

