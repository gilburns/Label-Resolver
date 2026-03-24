# Label Resolver

A native macOS utility for developers who write and maintain labels for the [Installomator](https://github.com/Installomator/Installomator) open source project.

<img width="1180" alt="Label-Resolver-MainView" src="https://github.com/user-attachments/assets/871750b6-a04c-43a0-99ed-bcf2e25d4657" />

## Overview

When developing a new Installomator label, you need to confirm that the shell script variables are being parsed correctly, that the download URL is reachable, that the Team ID is the right length, and that the file follows the formatting conventions the project expects. Label Resolver automates that process — load your label file, and it parses, validates, and displays every variable in a structured interface.

## Features

**Loading labels**
- Drag and drop a label file onto the window
- Browse for a local file using the file picker
- Enter a direct HTTPS URL to load and inspect a label from the Installomator repository or any remote source

**Parsing and display**
- Runs the label through a bundled parser that extracts all defined variables (type, downloadURL, expectedTeamID, appName, archiveName, blockingProcesses, and more)
- Displays parsed values alongside the raw file content, with invisible characters visualized (spaces, tabs, newlines)
- Each field has a contextual help popover explaining valid values and linking to Installomator documentation

**Validation**
- Checks that required fields (name, type, download URL, expectedTeamID) are present and correctly formatted
- Performs a live HTTP HEAD request to confirm the download URL is reachable
- Detects formatting problems: tab indentation instead of 4-space, Windows-style line endings (CRLF), and extra trailing blank lines
- Color-codes each field border (green / orange / red) and presents a full validation report

**Fix Issues**
- When fixable formatting problems are found, a **Fix Issues…** button appears in the validation report
- For local files, applies fixes in place after confirmation
- For remote files, presents a Save dialog to write the corrected content locally

**Architecture toggle**
- Labels that detect CPU architecture (using `$(arch)` or `$(/usr/bin/arch)` to serve different download URLs for Apple Silicon vs Intel) can be re-parsed under Rosetta using the **Native / x86_64** toggle
- The toggle only appears when the loaded label actually contains architecture detection code

## Requirements

- macOS 15.2 (Sequoia) or later

## More information

See the [Wiki](https://github.com/gilburns/Label-Resolver/wiki) for additional details.
