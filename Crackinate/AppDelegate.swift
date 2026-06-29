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

        // Listen for CLI commands via distributed notifications
        setupCLIListener()

        // Request notification permissions early
        NotificationManager.shared.requestPermission()

        // Begin monitoring systems
        ThermalMonitor.shared.startMonitoring()
        PowerMonitor.shared.startMonitoring()
        LidDetector.shared.startPolling()

        // Wire lid state changes to display dimming (if enabled in Settings)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(lidStateDidChange(_:)),
            name: .lidStateDidChange,
            object: nil
        )

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

    // MARK: - Lid State → Display Dimming

    @objc private func lidStateDidChange(_ notification: Notification) {
        guard PersistenceManager.shared.dimDisplayWhenLidClosed else { return }
        guard let isClosed = notification.object as? NSNumber else { return }

        if isClosed.boolValue {
            DisplayDimmer.shared.dim()
        } else {
            DisplayDimmer.shared.restore()
        }
    }

    // MARK: - Single Instance

    /// Returns true if this is the only running instance of Crackinate.
    private var isOnlyInstance: Bool {
        let bundleID = Bundle.main.bundleIdentifier ?? Constants.bundleIdentifier
        let instances = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        let count = instances.filter { $0.activationPolicy == .accessory || $0.activationPolicy == .regular }.count
        return count <= 1
    }

    // MARK: - CLI Commands

    private func setupCLIListener() {
        let center = DistributedNotificationCenter.default()

        let commands: [(String, Selector)] = [
            ("com.crackinate.activate",   #selector(handleCLIActivate)),
            ("com.crackinate.deactivate",  #selector(handleCLIDeactivate)),
            ("com.crackinate.screenOn",    #selector(handleCLIScreenOn)),
            ("com.crackinate.screenOff",   #selector(handleCLIScreenOff)),
            ("com.crackinate.lidOn",       #selector(handleCLILidOn)),
            ("com.crackinate.lidOff",      #selector(handleCLILidOff)),
            ("com.crackinate.status",      #selector(handleCLIStatus)),
            ("com.crackinate.timer",       #selector(handleCLITimer)),
        ]

        for (name, sel) in commands {
            center.addObserver(self, selector: sel, name: NSNotification.Name(name), object: nil)
        }

        print("[Crackinate] CLI listener ready")
    }

    @objc private func handleCLIActivate() {
        DispatchQueue.main.async {
            KeepAwakeManager.shared.enableScreenAwake()
            KeepAwakeManager.shared.enableLidClosePrevention()
            self.updateIcon()
        }
    }

    @objc private func handleCLIDeactivate() {
        DispatchQueue.main.async {
            KeepAwakeManager.shared.disableAll()
            self.updateIcon()
        }
    }

    @objc private func handleCLIScreenOn() {
        DispatchQueue.main.async {
            KeepAwakeManager.shared.enableScreenAwake()
            self.updateIcon()
        }
    }

    @objc private func handleCLIScreenOff() {
        DispatchQueue.main.async {
            KeepAwakeManager.shared.disableScreenAwake()
            self.updateIcon()
        }
    }

    @objc private func handleCLILidOn() {
        DispatchQueue.main.async {
            KeepAwakeManager.shared.enableLidClosePrevention()
            self.updateIcon()
        }
    }

    @objc private func handleCLILidOff() {
        DispatchQueue.main.async {
            KeepAwakeManager.shared.disableLidClosePrevention()
            self.updateIcon()
        }
    }

    @objc private func handleCLIStatus(_ notification: Notification) {
        DispatchQueue.main.async {
            let mgr = KeepAwakeManager.shared
            let timerActive = TimerManager.shared.isTimerActive
            let remaining = TimerManager.shared.remainingTime

            var status = ""
            if mgr.isScreenAwakeActive && mgr.isLidClosePreventionActive {
                status = "Screen awake + Lid-close prevention active"
            } else if mgr.isScreenAwakeActive {
                status = "Screen awake"
            } else if mgr.isLidClosePreventionActive {
                status = "Lid-close prevention active"
            } else {
                status = "Inactive"
            }

            if timerActive, let remaining = remaining {
                let mins = Int(remaining) / 60
                let secs = Int(remaining) % 60
                status += " | Timer: \(mins):\(String(format: "%02d", secs)) remaining"
            }

            DistributedNotificationCenter.default().postNotificationName(
                NSNotification.Name("com.crackinate.statusReply"),
                object: nil,
                userInfo: ["status": status],
                options: .deliverImmediately
            )
        }
    }

    @objc private func handleCLITimer(_ notification: Notification) {
        guard let duration = notification.userInfo?["duration"] as? Int, duration > 0 else { return }
        DispatchQueue.main.async {
            KeepAwakeManager.shared.enableScreenAwake(duration: TimeInterval(duration))
            KeepAwakeManager.shared.enableLidClosePrevention(duration: TimeInterval(duration))
            self.updateIcon()
        }
    }
}
