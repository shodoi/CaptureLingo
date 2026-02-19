import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private enum PendingMenuAction {
        case capture
        case settings
    }

    private var statusItem: NSStatusItem?
    private var pendingMenuAction: PendingMenuAction?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMenuBar()
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "viewfinder", accessibilityDescription: "Capture Lingo")
        }

        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(makeMenuItem(title: "Capture", action: #selector(startCapture), keyEquivalent: "t"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(makeMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(makeMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    private func makeMenuItem(title: String, action: Selector, keyEquivalent: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        return item
    }

    @objc private func startCapture() {
        pendingMenuAction = .capture
    }

    @objc private func openSettings() {
        pendingMenuAction = .settings
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    func menuDidClose(_ menu: NSMenu) {
        runPendingMenuAction()
    }

    private func runPendingMenuAction() {
        guard let action = pendingMenuAction else { return }
        pendingMenuAction = nil

        DispatchQueue.main.async {
            switch action {
            case .capture:
                WindowManager.shared.showCaptureOverlay()
            case .settings:
                WindowManager.shared.showSettings()
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
