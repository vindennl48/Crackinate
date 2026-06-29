# Crackinate

**macOS menu bar app for preventing screen sleep and lid-close sleep.**

Crackinate keeps your Mac awake when you need it — with configurable timers, persistent settings, and thermal safety guardrails.

> ⚠️ **Not for Mac App Store distribution.** Apple rejects apps that prevent lid-close sleep. This is a personal/internal tool.

## Features

- 🔒 **Screen Sleep Prevention** — Prevent display and system idle-sleep via `NSProcessInfo.beginActivity`
- 🚫 **Lid-Close Sleep Prevention** — Keep the system running with the lid closed (requires one-time sudo setup)
- ⏱ **Timed Keep-Awake** — 5min / 15min / 30min / 1hr / 2hr presets with countdown display
- 🌡 **Thermal Safety** — Auto-disables all keep-awake on critical system temperature
- 🔋 **Battery Warnings** — Confirms before enabling lid-close prevention on battery
- 🚀 **Launch at Login + Auto-Revive** — SMAppService + LaunchAgent ensures the app restarts after a crash
- 💾 **Persistent Settings** — All preferences survive reboots via UserDefaults

## Requirements

- macOS 14 (Sonoma) or later
- Apple Silicon or Intel

## Installation

### Build from Source

```bash
git clone https://github.com/yourname/Crackinate.git
cd Crackinate
make app
open .build/release/Crackinate.app
```

Or build with Xcode:

```bash
open -a Xcode Package.swift  # opens as Xcode project
```

### Move to Applications (Recommended)

```bash
cp -R .build/release/Crackinate.app /Applications/
```

## Usage

### Menu Bar

Crackinate lives in your menu bar. Click the icon to open the popover:

```
┌─────────────────────────────┐
│  ⚡  Crackinate              │
│                             │
│  Keep Screen Awake    [ON]  │
│  Prevent Lid Sleep    [ON]  │
│                             │
│  Timer: [Forever  ▾]        │
│  ⏳ 14:32 remaining  [Stop] │
│                             │
│  ─────────────────────────  │
│  ⚙️  Preferences...          │
│  ❌  Quit Crackinate         │
└─────────────────────────────┘
```

### Modes

| Screen Awake | Lid-Close | Effect |
|-------------|-----------|--------|
| OFF | OFF | Normal macOS behavior |
| ON | OFF | Screen stays on, lid-close still sleeps |
| OFF | ON | Screen can sleep, lid-close ignored |
| ON | ON | Full keep-awake: screen on + lid-close ignored |

### Lid-Close Sleep Prevention Setup

The first time you toggle "Prevent Lid Sleep," Crackinate will ask for admin privileges to install a passwordless sudoers file. This is a one-time setup. After that, toggling lid-close prevention works without any password prompt.

### Timer

Select a duration from the picker to automatically disable keep-awake after that time:
- **Forever** — Stays active until manually turned off
- **5 min / 15 min / 30 min / 1 hr / 2 hr** — Auto-disables on expiry

A countdown timer appears in the popover when a timed session is active.

## Settings

Open Settings from the popover gear icon or `Cmd+,`:

- **General** — Launch at Login toggle
- **Keep Awake** — Default timer duration
- **Display** — Dim built-in display when lid closed (experimental)
- **Safety** — Auto-disable on critical thermal / Battery warnings
- **About** — Version info

## Safety

### Thermal Protection

If your Mac reaches critical temperature, Crackinate **automatically disables all keep-awake modes** to prevent hardware damage. A notification is shown at serious level, and keep-awake is force-disabled at critical.

### Battery Protection

Enabling lid-close prevention on battery power shows a confirmation dialog (can be disabled in Settings).

### Safe Quit

Quitting Crackinate (Cmd+Q or menu → Quit) releases all assertions and resets `pmset disablesleep` to 0. Screen sleep assertions are automatically released by macOS if the app crashes.

## Development

### Project Structure

```
Crackinate/
├── CrackinateApp.swift          # @main entry point
├── AppDelegate.swift            # NSStatusItem + NSPopover
├── Constants.swift              # SettingsKeys, constants
├── PersistenceManager.swift     # UserDefaults wrapper
├── IconProvider.swift           # Menu bar icons (6 states)
├── Info.plist
├── Managers/
│   ├── KeepAwakeManager.swift   # Core sleep prevention engine
│   ├── TimerManager.swift       # Countdown timers
│   ├── ThermalMonitor.swift     # Thermal safety
│   ├── PowerMonitor.swift       # AC/battery detection
│   ├── LidDetector.swift        # Lid state via IORegistry
│   ├── SudoersInstaller.swift   # sudoers file management
│   ├── LaunchAgentManager.swift # Login item + auto-revive
│   ├── NotificationManager.swift
│   └── DisplayDimmer.swift      # CoreDisplay dimming (experimental)
├── Views/
│   ├── PopoverView.swift        # Main popover UI
│   └── SettingsView.swift       # Preferences window
└── Components/
    ├── ToggleRow.swift
    ├── TimerPicker.swift
    └── CountdownDisplay.swift
```

### Building & Testing

```bash
make build          # Debug build
make app            # Release .app bundle
make clean          # Remove build artifacts
swift test          # Run all tests (requires Xcode)
```

To run tests, ensure `xcode-select` points to Xcode:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
swift test
```

## License

MIT — see LICENSE file.

## Credits

Built with Swift 6, AppKit, SwiftUI, and IOKit.
Inspired by Amphetamine, Caffeine, and SleepOff.
