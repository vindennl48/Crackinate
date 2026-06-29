import Foundation

// MARK: - Notification Names (must match the main app)

private let notificationActivate  = "com.crackinate.activate"
private let notificationDeactivate = "com.crackinate.deactivate"
private let notificationScreenOn  = "com.crackinate.screenOn"
private let notificationScreenOff = "com.crackinate.screenOff"
private let notificationLidOn     = "com.crackinate.lidOn"
private let notificationLidOff    = "com.crackinate.lidOff"
private let notificationStatus    = "com.crackinate.status"
private let notificationTimer     = "com.crackinate.timer"
private let notificationStatusReply = "com.crackinate.statusReply"

// MARK: - Main

let args = CommandLine.arguments.dropFirst()

guard let command = args.first else {
    printUsage()
    exit(1)
}

switch command {
case "--help", "help", "-h":
    printUsage()
    exit(0)

case "activate":
    post(notificationActivate)
    print("Activated keep-awake (screen + lid)")

case "deactivate":
    post(notificationDeactivate)
    print("Deactivated keep-awake")

case "screen":
    guard let sub = args.dropFirst().first else {
        print("Usage: crackinate screen on|off")
        exit(1)
    }
    switch sub {
    case "on":  post(notificationScreenOn);  print("Screen awake enabled")
    case "off": post(notificationScreenOff); print("Screen awake disabled")
    default:
        print("Usage: crackinate screen on|off")
        exit(1)
    }

case "lid":
    guard let sub = args.dropFirst().first else {
        print("Usage: crackinate lid on|off")
        exit(1)
    }
    switch sub {
    case "on":  post(notificationLidOn);  print("Lid-close prevention enabled")
    case "off": post(notificationLidOff); print("Lid-close prevention disabled")
    default:
        print("Usage: crackinate lid on|off")
        exit(1)
    }

case "status":
    // Listen for the reply from the main app
    let semaphore = DispatchSemaphore(value: 0)
    var statusLine = "Crackinate: could not reach app (is it running?)"

    var observer: NSObjectProtocol?
    observer = DistributedNotificationCenter.default().addObserver(
        forName: NSNotification.Name(notificationStatusReply),
        object: nil,
        queue: .main
    ) { notification in
        if let info = notification.userInfo?["status"] as? String {
            statusLine = info
        }
        semaphore.signal()
    }

    post(notificationStatus)

    // Wait up to 1 second for reply
    _ = semaphore.wait(timeout: .now() + 1.0)
    if let obs = observer {
        DistributedNotificationCenter.default().removeObserver(obs)
    }
    print(statusLine)

case "timer":
    guard let durationStr = args.dropFirst().first else {
        print("Usage: crackinate timer 5m|15m|30m|1h|2h")
        exit(1)
    }
    guard let seconds = parseDuration(durationStr) else {
        print("Invalid duration: \(durationStr). Use 5m, 15m, 30m, 1h, or 2h.")
        exit(1)
    }
    // Activate with timer
    post(notificationActivate)
    DistributedNotificationCenter.default().postNotificationName(
        NSNotification.Name(notificationTimer),
        object: nil,
        userInfo: ["duration": seconds],
        deliverImmediately: true
    )
    print("Activated keep-awake with \(durationStr) timer")

default:
    print("Unknown command: \(command)")
    printUsage()
    exit(1)
}

// MARK: - Helpers

func post(_ name: String) {
    DistributedNotificationCenter.default().postNotificationName(
        NSNotification.Name(name),
        object: nil,
        userInfo: nil,
        deliverImmediately: true
    )
}

func parseDuration(_ s: String) -> Int? {
    let lower = s.lowercased()
    if lower == "5m"  || lower == "5min"  { return 300 }
    if lower == "15m" || lower == "15min" { return 900 }
    if lower == "30m" || lower == "30min" { return 1800 }
    if lower == "1h"  || lower == "1hr"  { return 3600 }
    if lower == "2h"  || lower == "2hr"  { return 7200 }
    if lower == "forever" { return 0 }
    return nil
}

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
