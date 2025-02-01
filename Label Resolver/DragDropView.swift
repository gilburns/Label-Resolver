//
//  DragDropView.swift
//  Label Resolver
//
//  Created by Gil Burns on 1/31/25.
//

import Cocoa

class DragDropView: NSView {
    
    var onFileDropped: ((URL) -> Void)?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        registerForDraggedTypes([.fileURL]) // Register for file dragging
        wantsLayer = true
        layer?.borderWidth = 2.0
        layer?.borderColor = NSColor.clear.cgColor
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
//        print("Dragging Entered") // Debugging
        highlight()
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
//        print("Dragging Exited") // Debugging
        unhighlight()
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
//        print("File Dropped") // Debugging
        unhighlight()
        
        guard let fileURL = getDraggedFileURL(sender) else { return false }

        // Notify ViewController
        onFileDropped?(fileURL)
        
        return true
    }

    // Extract the file URL from the drag
    private func getDraggedFileURL(_ sender: NSDraggingInfo) -> URL? {
        let pasteboard = sender.draggingPasteboard
        guard let items = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], let fileURL = items.first else {
            return nil
        }
        return fileURL
    }

    // Highlight the border when dragging starts
    private func highlight() {
        layer?.borderColor = NSColor.controlAccentColor.cgColor
    }

    // Remove the highlight when dragging exits or completes
    private func unhighlight() {
        layer?.borderColor = NSColor.clear.cgColor
    }
}
