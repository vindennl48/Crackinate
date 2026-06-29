import Foundation

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
    postNotification(notificationActivate)
    let status = getStatus()
    print("Activated keep-awake (screen + lid)")
    showSetupHints(from: status)

case "deactivate":
    postNotification(notificationDeactivate)
    print("Deactivated keep-awake")

case "screen":
    guard let sub = args.dropFirst().first else {
        print("Usage: crackinate screen on|off")
        exit(1)
    }
    switch sub {
    case "on":  postNotification(notificationScreenOn);  print("Screen awake enabled")
    case "off": postNotification(notificationScreenOff); print("Screen awake disabled")
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
    case "on":
        postNotification(notificationLidOn)
        print("Lid-close prevention enabled")
        let status = getStatus()
        showSetupHints(from: status)
    case "off": postNotification(notificationLidOff); print("Lid-close prevention disabled")
    default:
        print("Usage: crackinate lid on|off")
        exit(1)
    }

case "status":
    let statusLine = getStatus()
    if statusLine.isEmpty {
        print("Crackinate: could not reach app (is it running?)")
    } else {
        print(statusLine)
    }

case "timer":
    guard let durationStr = args.dropFirst().first else {
        print("Usage: crackinate timer 5m|15m|30m|1h|2h")
        exit(1)
    }
    guard let seconds = parseDuration(durationStr) else {
        print("Invalid duration: \(durationStr). Use 5m, 15m, 30m, 1h, or 2h.")
        exit(1)
    }
    postNotification(notificationActivate)
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
