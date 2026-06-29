import SwiftUI

/// Entry point for Crackinate — a menu bar app that prevents screen sleep and lid-close sleep.
@main
struct CrackinateApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        PersistenceManager.shared.registerDefaults()
    }

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}
