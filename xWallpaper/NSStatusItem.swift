import SwiftUI
// ...existing code...

// 辅助扩展用于初始化菜单栏
extension Scene {
    func setupMenuBar() -> some Scene {
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 380, height: 460)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: MainMenuView())
        
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "photo.on.rectangle.angled", accessibilityDescription: "Wallpaper")
            button.action = #selector(PopoverTarget.togglePopover)
            button.target = PopoverTarget.shared
            PopoverTarget.shared.popover = popover
            PopoverTarget.shared.button = button
        }
        return self
    }
}

class PopoverTarget {
    static let shared = PopoverTarget()
    var popover: NSPopover?
    var button: NSStatusBarButton?

    @objc func togglePopover() {
        if let button = button, let popover = popover {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }
}
