//
//  AppDelegate.swift
//  Label Resolver
//
//  Created by Gil Burns on 1/31/25.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        if let helpMenu = NSApp.mainMenu?.items.first(where: { $0.title == "Help" })?.submenu {
            helpMenu.insertItem(NSMenuItem.separator(), at: 0)
            let wikiItem = NSMenuItem(title: "Label Resolver Wiki", action: #selector(openWiki(_:)), keyEquivalent: "")
            wikiItem.target = self
            helpMenu.insertItem(wikiItem, at: 1)

            let wikiItem2 = NSMenuItem(title: "Installomator Wiki", action: #selector(openInstallomatorWiki(_:)), keyEquivalent: "")
            wikiItem2.target = self
            helpMenu.insertItem(wikiItem2, at: 2)
            
            helpMenu.insertItem(NSMenuItem.separator(), at: 3)
        }
    }

    @objc private func openWiki(_ sender: NSMenuItem) {
        if let url = URL(string: "https://github.com/gilburns/Label-Resolver/wiki") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openInstallomatorWiki(_ sender: NSMenuItem) {
        if let url = URL(string: "https://github.com/Installomator/Installomator/wiki") {
            NSWorkspace.shared.open(url)
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

}

