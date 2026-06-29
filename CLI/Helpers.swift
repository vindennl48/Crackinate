import Foundation

// MARK: - Notification Names

let notificationActivate   = "com.crackinate.activate"
let notificationDeactivate = "com.crackinate.deactivate"
let notificationScreenOn   = "com.crackinate.screenOn"
let notificationScreenOff  = "com.crackinate.screenOff"
let notificationLidOn      = "com.crackinate.lidOn"
let notificationLidOff     = "com.crackinate.lidOff"
let notificationStatus     = "com.crackinate.status"
let notificationTimer      = "com.crackinate.timer"
let notificationStatusReply = "com.crackinate.statusReply"

// MARK: - Helpers

/// Post a distributed notification to the running Crackinate app.
func postNotification(_ name: String) {
    DistributedNotificationCenter.default().postNotificationName(
        NSNotification.Name(name),
        object: nil,
        userInfo: nil,
        deliverImmediately: true
    )
}

/// Parse a human-readable duration string into seconds.
func parseDuration(_ s: String) -> Int? {
    let lower = s.lowercased()
    if lower == "5m"  || lower == "5min"  { return 300 }
    if lower == "15m" || lower == "15min" { return 900 }
    if lower == "30m" || lower == "30min" { return 1800 }
    if lower == "1h"  || lower == "1hr"   { return 3600 }
    if lower == "2h"  || lower == "2hr"   { return 7200 }
    if lower == "forever" { return 0 }
    return nil
}

/// Query the running app for current status. Returns empty string on timeout.
func getStatus() -> String {
    let semaphore = DispatchSemaphore(value: 0)
    var statusLine = ""

    var observer: NSObjectProtocol?
    observer = DistributedNotificationCenter.default().addObserver(
        forName: NSNotification.Name(notificationStatusReply),
        object: nil,
        queue: OperationQueue()
    ) { notification in
        if let info = notification.userInfo?["status"] as? String {
            statusLine = info
        }
        semaphore.signal()
    }

    postNotification(notificationStatus)
    _ = semaphore.wait(timeout: .now() + 2.0)
    if let obs = observer {
        DistributedNotificationCenter.default().removeObserver(obs)
    }
    return statusLine
}

/// Show hints if lid-close setup or app not running.
func showSetupHints(from status: String) {
    if status.isEmpty {
        print("  ⚠ Could not reach Crackinate app — is it running?")
        return
    }
    if status.contains("Lid-close") { return }

    print("  ⚠ Lid-close sleep prevention not active.")
    print("  → Open the Crackinate popover and toggle \"Prevent Lid Sleep\" ON to complete one-time setup.")
}

/// Print usage information.
func printUsage() {
    print("""
    Crackinate CLI — control keep-awake from the terminal.

    Commands:
      activate              Turn ON screen awake + lid-close prevention
      deactivate            Turn OFF all keep-awake modes
      screen on|off         Toggle screen awake
      lid on|off            Toggle lid-close prevention
      status                Show current keep-awake state
      timer 5m|15m|30m|1h|2h  Activate with timed auto-off

    Examples:
      crackinate activate
      crackinate screen on
      crackinate timer 30m
      crackinate status
    """)
}
