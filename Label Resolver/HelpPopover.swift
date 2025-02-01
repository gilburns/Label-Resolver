//
//  HelpPopover.swift
//  Label Resolver
//
//  Created by Gil Burns on 1/31/25.
//

import Cocoa

class HelpPopover {

    // The popover instance
    private let popover: NSPopover

    init() {
        self.popover = NSPopover()
        self.popover.behavior = .transient // Automatically dismisses when clicking outside
    }

    func showHelp(anchorView: NSView, helpText: NSAttributedString) {
        // Create an NSTextView for rich text with hyperlinks
        let helpTextView = NSTextView()
        helpTextView.isEditable = false
        helpTextView.isSelectable = true
        helpTextView.drawsBackground = false
        helpTextView.textContainerInset = NSSize(width: 10, height: 10)
        helpTextView.textStorage?.setAttributedString(helpText)
        helpTextView.textContainer?.lineBreakMode = .byWordWrapping
        helpTextView.textContainer?.widthTracksTextView = true

        // Create a container view for the NSTextView
        let contentView = NSView()
        contentView.addSubview(helpTextView)
        helpTextView.translatesAutoresizingMaskIntoConstraints = false

        // Define the maximum width and calculate required height
        let maxWidth: CGFloat = 300
        helpTextView.textContainer?.containerSize = NSSize(width: maxWidth, height: CGFloat.greatestFiniteMagnitude)

        // Force layout calculation
        helpTextView.layoutManager?.ensureLayout(for: helpTextView.textContainer!)

        // Calculate the size required for the text, adding a buffer for the last line
        let calculatedHeight = helpTextView.layoutManager?.usedRect(for: helpTextView.textContainer!).height ?? 150
        let popoverHeight = min(calculatedHeight + 30, 500) // Add a 10px buffer for the last line

        // Set constraints for the NSTextView
        NSLayoutConstraint.activate([
            helpTextView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            helpTextView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            helpTextView.topAnchor.constraint(equalTo: contentView.topAnchor),
            helpTextView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            helpTextView.widthAnchor.constraint(equalToConstant: maxWidth),
            helpTextView.heightAnchor.constraint(equalToConstant: popoverHeight)
        ])

        // Set the content view controller
        let contentViewController = NSViewController()
        contentViewController.view = contentView
        popover.contentViewController = contentViewController

        // Set popover size
        popover.contentSize = NSSize(width: maxWidth, height: popoverHeight)

        // Show the popover, anchored to the given view
        popover.show(relativeTo: anchorView.bounds, of: anchorView, preferredEdge: .maxX)
    }

    func close() {
        popover.close()
    }
}
