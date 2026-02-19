import SwiftUI

@main
struct CaptureLingoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Keep a non-window scene so the app stays menu-bar only on launch.
        Settings {
            SettingsView()
        }
    }
}
