import SwiftUI

@main
struct CaptureLingoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // We do not want a main window to appear on launch, as this is a menu bar app.
        // However, we need at least one scene to keep the app running in some contexts,
        // but for a purely menu bar app, we can use Settings or an empty WindowGroup that is hidden.
        // In this case, since we handle everything via AppDelegate and NSPanel, we can use Settings 
        // if we want a settings window later, or an empty WindowGroup.
        // A common pattern for menu bar apps is to just use Settings() and manage the main UI via NSStatusItem.
        // Managed manually by WindowManager
        // Settings { SettingsView() }
        WindowGroup {
             EmptyView().frame(width: 0, height: 0)
        }
        .windowStyle(.hiddenTitleBar) // Try to keep it hidden
    }
}
