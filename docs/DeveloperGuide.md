# Crackinate Developer Guide

## Architecture Overview

Crackinate is a single-process macOS menu bar app written in Swift. It uses AppKit for the status item and SwiftUI for all views.

```
┌─────────────────────────────────────────────────────────────┐
│                      Crackinate.app                         │
│                                                             │
│  ┌─────────────┐  ┌──────────────┐  ┌───────────────────┐  │
│  │ AppDelegate  │  │ PopoverView   │  │   SettingsView    │  │
│  │ (NSStatusItem│  │ (SwiftUI)     │  │   (SwiftUI)       │  │
│  │  + NSPopover)│  │               │  │                   │  │
│  └──────┬───────┘  └──────┬───────┘  └────────┬──────────┘  │
│         │                 │                    │             │
│         │          ┌──────▼────────────────────▼──────┐      │
│         │          │       PersistenceManager          │      │
│         │          │       (UserDefaults)              │      │
│         │          └──────────────────────────────────┘      │
│         │                                                    │
│  ┌──────▼──────────────────────────────────────────────┐     │
│  │                 KeepAwakeManager                     │     │
│  │  ┌──────────────────┐  ┌────────────────────────┐   │     │
│  │  │ Screen Sleep     │  │ Lid-Close Prevention    │   │     │
│  │  │ NSProcessInfo    │  │ pmset via Process        │   │     │
│  │  │ beginActivity()  │  │ + sudoers file           │   │     │
│  │  └──────────────────┘  └────────────────────────┘   │     │
│  └─────────────────────────────────────────────────────┘     │
│                                                             │
│  ┌───────────────┐ ┌──────────────┐ ┌───────────────────┐  │
│  │ TimerManager   │ │ThermalMonitor│ │  PowerMonitor     │  │
│  │ (countdown +  │ │(NSProcessInfo│ │  (IOPSCopyPower)  │  │
│  │  expiry)      │ │ thermalState)│ │                   │  │
│  └───────────────┘ └──────────────┘ └───────────────────┘  │
│                                                             │
│  ┌───────────────┐ ┌──────────────┐ ┌───────────────────┐  │
│  │ LidDetector    │ │DisplayDimmer │ │ NotificationMgr   │  │
│  │ (IOKit poll)  │ │(CoreDisplay) │ │ (UNNotification)  │  │
│  └───────────────┘ └──────────────┘ └───────────────────┘  │
│                                                             │
│  ┌───────────────┐ ┌──────────────┐                        │
│  │ SudoersInstaller││LaunchAgentMgr│                       │
│  │ (/etc/sudoers) │ │(launchd)     │                       │
│  └───────────────┘ └──────────────┘                        │
└─────────────────────────────────────────────────────────────┘
```

## Project Structure

```
Crackinate/
├── Package.swift                  # SwiftPM build config
├── Makefile                       # Build shortcuts
├── README.md
├── docs/
│   ├── UserGuide.md
│   └── DeveloperGuide.md
├── Crackinate/
│   ├── CrackinateApp.swift        # @main entry, Settings scene
│   ├── AppDelegate.swift          # NSStatusItem, lifecycle, single-instance
│   ├── Constants.swift            # SettingsKeys enum, app constants
│   ├── PersistenceManager.swift   # UserDefaults typed wrapper
│   ├── IconProvider.swift         # Menu bar icon states (6 variants)
│   ├── Info.plist                 # LSUIElement, bundle config
│   ├── Managers/
│   │   ├── KeepAwakeManager.swift     # Core: NSProcessInfo + pmset
│   │   ├── TimerManager.swift         # Countdown + expiry callbacks
│   │   ├── ThermalMonitor.swift       # Thermal safety observer
│   │   ├── PowerMonitor.swift         # AC/battery via IOKit
│   │   ├── LidDetector.swift          # IORegistry lid polling
│   │   ├── SudoersInstaller.swift     # /etc/sudoers.d/ management
│   │   ├── LaunchAgentManager.swift   # SMAppService + LaunchAgent
│   │   ├── NotificationManager.swift  # UNUserNotificationCenter
│   │   └── DisplayDimmer.swift        # CoreDisplay brightness (experimental)
│   ├── Views/
│   │   ├── PopoverView.swift          # Main popover with toggles + timer
│   │   └── SettingsView.swift         # 5-tab preferences
│   └── Components/
│       ├── ToggleRow.swift            # Icon + label + switch row
│       ├── TimerPicker.swift          # Duration picker (Forever/5m/15m/...)
│       └── CountdownDisplay.swift     # Live countdown with stop button
└── CrackinateTests/
    ├── PmsetControllerTests.swift
    ├── PersistenceManagerTests.swift
    ├── TimerManagerTests.swift
    ├── KeepAwakeManagerTests.swift
    ├── SudoersInstallerTests.swift
    ├── PopoverViewLogicTests.swift
    ├── BatteryWarningTests.swift
    └── PowerMonitorTests.swift
```

## Key Design Decisions

### Why AppKit NSStatusItem + SwiftUI Views?

`NSStatusItem` gives full control over the menu bar button (left-click, right-click, variable length). SwiftUI's `MenuBarExtra` is simpler but can't do dynamic icons or right-click menus easily.

### Why sudoers instead of SMAppService Daemon?

A privileged helper daemon (SMAppService) requires XPC protocol code, code signing setup, and user approval in System Settings. The sudoers file approach is 10% of the code and provides identical functionality for pmset. Since this app isn't for the Mac App Store (Apple rejects lid-close prevention), the privileged helper adds no value.

### Why no Combine in Managers?

Service-layer code uses plain closures, NotificationCenter, and delegates. Combine is used only in SwiftUI views (via `@Published`, `onReceive`, `onChange`). This keeps the managers simple and testable.

## Building

### Prerequisites

- macOS 14 (Sonoma) or later
- Xcode 15+ (for tests; the command-line Swift compiler works for builds)
- Apple Silicon or Intel Mac

### Build Commands

```bash
# Debug build (fast, no optimization)
make build

# Release .app bundle
make app

# Open the built app
open .build/release/Crackinate.app

# Install to /Applications
cp -R .build/release/Crackinate.app /Applications/

# Clean build artifacts
make clean
```

### Running Tests

Tests require Xcode's developer tools:

```bash
# If xcode-select points to Command Line Tools, switch to Xcode:
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

# Run all tests
swift test

# Run specific test suite
swift test --filter PmsetControllerTests
```

## Threading Model

| Thread | What runs there |
|--------|----------------|
| **Main** | All UI updates, NSStatusItem, NSPopover, animation |
| **Main run loop** | Timer.scheduledTimer callbacks, countdown ticks |
| **Background** | pmset Process execution, IOKit polling (via Timer on main) |
| **Notification callbacks** | Delivered on main thread |

## State Management

### UserDefaults Keys

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `screenAwakeEnabled` | Bool | false | Screen sleep toggle state |
| `lidSleepDisabled` | Bool | false | Lid-close toggle state |
| `timerDuration` | Int | 0 | Seconds; 0 = forever |
| `isTimerActive` | Bool | false | Whether countdown is running |
| `launchAtLogin` | Bool | false | Launch at login |
| `dimDisplayWhenLidClosed` | Bool | false | Dim display on lid close |
| `autoDisableOnThermal` | Bool | true | Safety: auto-disable on critical |
| `warnOnBatteryLidClosed` | Bool | true | Safety: battery warning |
| `hasCompletedSetup` | Bool | false | First-run setup done |
| `firstLaunchDate` | Date | nil | When app was first opened |

### Notification Names

| Notification | Object | When |
|-------------|--------|------|
| `CrackinateScreenAwakeDidChange` | Bool (NSNumber) | Screen awake toggled |
| `CrackinateLidClosePreventionDidChange` | Bool (NSNumber) | Lid-close toggled |
| `CrackinatePowerSourceDidChange` | Bool (NSNumber) | AC/battery changed |
| `CrackinateLidStateDidChange` | Bool (NSNumber) | Lid opened/closed |

## Adding Features

### Adding a New Manager

1. Create `Crackinate/Managers/NewManager.swift`
2. Use singleton pattern: `static let shared = NewManager()`
3. Post state changes via NotificationCenter
4. Start from `AppDelegate.applicationDidFinishLaunching`
5. Clean up in `applicationWillTerminate`

### Adding a New Setting

1. Add key to `SettingsKeys` enum in `Constants.swift`
2. Add property to `PersistenceManager` with get/set
3. Add default value in `registerDefaults()`
4. Add UI in `SettingsView.swift`
5. Read from `@AppStorage` in SwiftUI or `PersistenceManager` elsewhere

### Adding a New Popover Component

1. Create view in `Crackinate/Components/`
2. Add to `PopoverView.swift` body
3. If component needs state, add `@State` or `@AppStorage`

## Distribution

### Not for Mac App Store

Apple rejects apps that prevent lid-close sleep. The `pmset -a disablesleep` command and CoreDisplay private API make App Store distribution impossible.

### Distribution Methods

- **Direct download** from GitHub Releases (`.zip`)
- **Homebrew cask**

### Notarization

The app should be signed and notarized for distribution:

```bash
# Code sign
codesign --deep --force --verify --verbose --sign "Developer ID" Crackinate.app

# Notarize
xcrun notarytool submit Crackinate.zip --apple-id "you@example.com" --team-id "TEAMID" --password "@keychain:AC_PASSWORD" --wait

# Staple
xcrun stapler staple Crackinate.app
```

## Reference Implementations

| Project | URL | What it does |
|---------|-----|-------------|
| SleepOff | github.com/sabraman/sleepoff | pmset toggle, lid dimming, sudoers install |
| muxbar | github.com/1989v/muxbar | Keep Awake + closed-lid, SwiftUI, caffeinate + pmset |
| Amphetamine | App Store | Screen sleep prevention (no lid-close) |
| Caffeine | Older open-source | IOPMAssertion-based screen sleep |
