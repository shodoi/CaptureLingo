import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private enum PendingMenuAction {
        case capture
        case settings
    }

    private var statusItem: NSStatusItem?
    private var pendingMenuAction: PendingMenuAction?
    private var isStatusMenuOpen = false

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
        enqueueMenuAction(.capture)
    }

    @objc private func openSettings() {
        enqueueMenuAction(.settings)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    func menuWillOpen(_ menu: NSMenu) {
        isStatusMenuOpen = true
    }

    func menuDidClose(_ menu: NSMenu) {
        isStatusMenuOpen = false
        runPendingMenuAction()
    }

    private func enqueueMenuAction(_ action: PendingMenuAction) {
        pendingMenuAction = action

        // On newer macOS versions, menuDidClose can fire before item actions.
        // Retry on the next runloop and execute only after the menu has closed.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard !self.isStatusMenuOpen else { return }
            self.runPendingMenuAction()
        }
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
