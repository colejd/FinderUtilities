//
//  RightClickExtension.swift
//  RightClickExtension
//
//  Created by Antti Tulisalo on 27/08/2019.
//  Copyright © 2019 Antti Tulisalo. All rights reserved.
//

import Cocoa
import FinderSync
import ProcessRunner

struct AppInfo {
    let url: URL

    init?(forAppWithPath path: String) {
        guard path.hasSuffix(".app") else {
            NSLog("The path \"\(path)\" must end in \".app\"!")
            return nil
        }
        guard FileManager.default.fileExists(atPath: path) else {
            NSLog("The app specified with the path \"\(path)\" does not exist")
            return nil
        }
        url = URL(fileURLWithPath: path)
    }

    var name: String {
        return url.deletingPathExtension().lastPathComponent
    }

    var icon: NSImage {
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}

struct Apps {
    static let terminal = AppInfo(forAppWithPath: "/System/Applications/Utilities/Terminal.app")!
    static let textEdit = AppInfo(forAppWithPath: "/System/Applications/TextEdit.app")!
    static let visualStudioCode = AppInfo(forAppWithPath: "/Applications/Visual Studio Code.app")!
}

class FinderSync: FIFinderSync {
    
    override init() {
        super.init()
        
        NSLog("FinderSync() launched from %@", Bundle.main.bundlePath as NSString)
        
        // Set up the directory we are syncing
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
    }
    
    override func menu(for menuKind: FIMenuKind) -> NSMenu {

        // Produce a menu for the extension (to be shown when right clicking a folder in Finder)
        let menu = NSMenu(title: "")
        let terminalItem = menu.addItem(withTitle: "Open in Terminal", action: #selector(openTerminalClicked(_:)), keyEquivalent: "")
        terminalItem.image = Apps.terminal.icon
        let editorItem = menu.addItem(withTitle: "Open in Editor", action: #selector(openInEditorClicked(_:)), keyEquivalent: "")
        editorItem.image = Apps.visualStudioCode.icon
        menu.addItem(withTitle: "Create empty file here", action: #selector(createEmptyFileClicked(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Copy selected paths", action: #selector(copyPathToClipboard), keyEquivalent: "")

        return menu
    }

    /// Copies the selected file and/or directory paths to pasteboard
    @IBAction func copyPathToClipboard(_ sender: AnyObject?) {
        
        guard let target = FIFinderSyncController.default().selectedItemURLs() else {
            NSLog("Failed to obtain targeted URLs: %@")
            return
        }
        
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([NSPasteboard.PasteboardType.string], owner: nil)
        var result = ""
        
        // Loop through all selected paths
        for path in target {
            result.append(contentsOf: path.relativePath)
            result.append("\n")
        }
        result.removeLast() // Remove trailing \n

        pasteboard.setString(result, forType: NSPasteboard.PasteboardType.string)
    }

    /// Opens a macOS Terminal.app window in the user-chosen folder
    @IBAction func openTerminalClicked(_ sender: AnyObject?) {
        openApp(withAppInfo: Apps.terminal)
    }

    @IBAction func openInEditorClicked(_ sender: AnyObject?) {
        openApp(withAppInfo: Apps.visualStudioCode)
    }

    /// Creates an empty file with name "untitled" under the user-chosen Finder folder.
    /// If file already exists, append it with a counter.
    @IBAction func createEmptyFileClicked(_ sender: AnyObject?) {
        
        guard let target = FIFinderSyncController.default().targetedURL() else {
            
            NSLog("Failed to obtain targeted URL: %@")
            
            return
        }

        var originalPath = target
        let originalFilename = "untitled"
        let fileType = ""

        var counter = 1
        var filename = "untitled"
        while FileManager.default.fileExists(atPath: originalPath.appendingPathComponent(filename).path) {
            filename = "\(originalFilename) \(counter)\(fileType)"
            counter+=1
            originalPath = target
        }
        
        do {
            try "".write(to: target.appendingPathComponent(filename), atomically: true, encoding: String.Encoding.utf8)
        } catch let error as NSError {
            NSLog("Failed to create file: %@", error.description as NSString)
        }
    }

    func openApp(withAppInfo info: AppInfo) {
        guard let target = FIFinderSyncController.default().targetedURL() else {
            NSLog("Failed to obtain targeted URL: %@")
            return
        }

//        let task = Process()
//        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
//        task.currentDirectoryURL = target
//        task.arguments = ["-a", info.name, "\(target.absoluteString)"]
//
//        do {
//            try task.run()
//            task.waitUntilExit()
//        } catch let error as NSError {
//            NSLog("Failed to open \"\(info.name)\": %@", error.description as NSString)
//        }
        let f = target.startAccessingSecurityScopedResource()
        let command = "open -a \(info.name) \(target.path)"
        let currentDirectory = target.isFileURL ? target.deletingLastPathComponent() : target
        let result = try! system(command: command, captureOutput: true)
        currentDirectory.stopAccessingSecurityScopedResource()
        NSLog(result.standardOutput)
        NSLog(result.standardError)
        NSLog("\(result.success)")
        let x = 5
    }
}
