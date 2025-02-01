//
//  CopyInterceptingTextView.swift
//  Label Resolver
//
//  Created by Gil Burns on 1/31/25.
//

import Cocoa

class CopyInterceptingTextView: NSTextView {
    // Store the real text to copy
    var originalText: String = ""

    override func awakeFromNib() {
        super.awakeFromNib()

        // Ensure monospaced font
        let monospacedFont = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        self.typingAttributes = [.font: monospacedFont]

        // Apply font to existing text
        let range = NSRange(location: 0, length: textStorage?.length ?? 0)
        textStorage?.addAttribute(.font, value: monospacedFont, range: range)

        // Allow horizontal scrolling & prevent word wrapping
        isHorizontallyResizable = true
        textContainer?.widthTracksTextView = false
        textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        // Allow vertical scrolling by enabling height tracking
        isVerticallyResizable = true
        textContainer?.heightTracksTextView = false  // **Fixes vertical scrolling**
        
        // Ensure text does not wrap but scrolls instead
        textContainer?.lineBreakMode = .byClipping

        // Ensure `NSScrollView` allows scrolling
        if let scrollView = self.enclosingScrollView {
            print("scrollView found")
            scrollView.hasVerticalScroller = true
            scrollView.hasHorizontalScroller = true
            scrollView.autohidesScrollers = false
//            scrollView.automaticallyAdjustsContentInsets = true
        }
    }

    
    override func copy(_ sender: Any?) {
        print("Intercepted Copy Command") // Debugging

        guard !originalText.isEmpty else {
            print("No original text to copy")
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(originalText, forType: .string)

        print("Copied Original Text:\n\(originalText)")
    }
}
