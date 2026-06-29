import Cocoa
import SwiftUI

/// Main app delegate — manages the NSStatusItem, NSPopover, and lifecycle.
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Single-instance guard: if another copy is already running, exit.
        guard isOnlyInstance else {
            print("[Crackinate] Another instance is already running — exiting.")
            NSApp.terminate(nil)
            return
        }

        NSApp.setActivationPolicy(.accessory)

        // Perform state restoration (check pmset state, reconcile settings)
        KeepAwakeManager.shared.performStateRestoration()

        setupStatusItem()
        setupPopover()

        // Clean up keep-awake state on quit
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cleanupOnTerminate),
            name: NSApplication.willTerminateNotification,
            object: nil
        )

        // Observe state changes for icon updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateIcon),
            name: .screenAwakeDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateIcon),
            name: .lidClosePreventionDidChange,
            object: nil
        )

        // Request notification permissions early
        NotificationManager.shared.requestPermission()

        // Begin monitoring systems
        ThermalMonitor.shared.startMonitoring()
        PowerMonitor.shared.startMonitoring()
        LidDetector.shared.startPolling()

        // Validate/update LaunchAgent path in case app was moved
        LaunchAgentManager.shared.validateLaunchAgentPath()

        // Mark first launch date if not set
        if PersistenceManager.shared.firstLaunchDate == nil {
            PersistenceManager.shared.firstLaunchDate = Date()
        }

        print("[Crackinate] App launched successfully")
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            updateIcon()
            button.action = #selector(togglePopover)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    // MARK: - Popover

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverView()
        )
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showContextMenu(for: sender)
            return
        }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func showContextMenu(for button: NSStatusBarButton) {
        let menu = NSMenu()

        menu.addItem(
            NSMenuItem(
                title: "Preferences...",
                action: #selector(openPreferences),
                keyEquivalent: ","
            )
        )
        menu.addItem(.separator())
        menu.addItem(
            NSMenuItem(
                title: "Quit Crackinate",
                action: #selector(cleanQuit),
                keyEquivalent: "q"
            )
        )

        statusItem.menu = menu
        button.performClick(nil)
        statusItem.menu = nil
    }

    // MARK: - Icon Updates

    @objc func updateIcon() {
        guard let button = statusItem.button else { return }
        let provider = IconProvider.shared
        button.image = provider.currentIcon
        button.toolTip = provider.toolTip
    }

    // MARK: - Actions

    @objc private func openPreferences() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    @objc private func cleanQuit() {
        KeepAwakeManager.shared.disableAll()
        NSApp.terminate(nil)
    }

    // MARK: - Lifecycle

    @objc private func cleanupOnTerminate() {
        KeepAwakeManager.shared.disableAll()
    }

    func applicationWillTerminate(_ notification: Notification) {
        KeepAwakeManager.shared.disableAll()
    }

    // MARK: - Single Instance

    /// Returns true if this is the only running instance of Crackinate.
    /// Prevents duplicate menu bar icons when Launch at Login spawns a second copy.
    private var isOnlyInstance: Bool {
        let bundleID = Bundle.main.bundleIdentifier ?? Constants.bundleIdentifier
        let instances = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        // Count only apps (not background daemons) with our bundle ID
        let count = instances.filter { $0.activationPolicy == .accessory || $0.activationPolicy == .regular }.count
        return count <= 1
    }
}
