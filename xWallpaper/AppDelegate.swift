import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    let popover = NSPopover()

    func applicationDidFinishLaunching(_ notification: Notification) {
        LaunchAtLoginManager.shared.syncWithStoredPreference()

        popover.contentSize = NSSize(width: 380, height: 460)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: MainMenuView())

        WallpaperRefreshScheduler.shared.start()
        WallpaperFileCleaner.shared.start()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "photo.on.rectangle.angled", accessibilityDescription: "Wallpaper")
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        WallpaperRefreshScheduler.shared.stop()
        WallpaperFileCleaner.shared.stop()
    }

    @objc func togglePopover() {
        if let button = statusItem?.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }
}

// ...existing code...
