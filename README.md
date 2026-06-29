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
- 🖥 **Display Dimming** — Dims built-in display when lid closes while keep-awake is active
- 🚀 **Launch at Login + Auto-Revive** — SMAppService + LaunchAgent ensures the app restarts after a crash
- ⌨️ **CLI Companion** — Control keep-awake from the terminal (`crackinate activate`, `crackinate status`, etc.)
- 🔒 **Single Instance** — Prevents duplicate menu bar icons
- 💾 **Persistent Settings** — All preferences survive reboots via UserDefaults

## Requirements

- macOS 14 (Sonoma) or later
- Apple Silicon or Intel

## Installation

### Build from Source

```bash
git clone https://github.com/vindennl48/Crackinate.git
cd Crackinate
make app
open .build/release/Crackinate.app
```

### One-Command Install (Recommended)

```bash
./scripts/install.sh
```

This uninstalls any previous version, builds the app, installs to `/Applications`, and sets up the CLI to `/usr/local/bin/crackinate`.

### Uninstall

```bash
./scripts/uninstall.sh
```

Removes the app, CLI, sudoers file, LaunchAgent, and UserDefaults.

### Build with Xcode

```bash
open -a Xcode Package.swift
```

### CLI Companion

The CLI installs automatically with `./scripts/install.sh`, or manually:

```bash
make install-cli   # installs to /usr/local/bin/crackinate
```

```bash
crackinate activate           # Turn ON screen + lid
crackinate deactivate         # Turn OFF everything
crackinate screen on|off      # Toggle screen awake
crackinate lid on|off         # Toggle lid-close prevention
crackinate timer 30m          # Activate with 30-minute auto-off
crackinate status             # Show current state
```

If the app isn't running or lid-close needs setup, the CLI will tell you.

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

You can change the timer at any time, even while keep-awake is active. The countdown restarts with the new duration. When the timer expires or you click Stop, the picker resets to your default from Settings.

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

### Single Instance

Crackinate detects if another copy is already running and refuses to launch a duplicate — no more double menu bar icons.

### Safe Quit

Quitting Crackinate (Cmd+Q or menu → Quit) releases all assertions and resets `pmset disablesleep` to 0. Screen sleep assertions are automatically released by macOS if the app crashes.

## Development

### Project Structure

```
Crackinate/
├── CrackinateApp.swift          # @main entry point
├── AppDelegate.swift            # NSStatusItem, NSPopover, CLI listener, lid dimming
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
│   └── DisplayDimmer.swift      # CoreDisplay brightness control
├── Views/
│   ├── PopoverView.swift        # Main popover UI
│   └── SettingsView.swift       # Preferences window
├── Components/
│   ├── ToggleRow.swift
│   ├── TimerPicker.swift
│   └── CountdownDisplay.swift
├── CLI/
│   ├── main.swift               # CLI command routing
│   └── Helpers.swift            # parseDuration, getStatus, hints
├── CrackinateTests/             # 71 app unit tests
├── CLITests/                    # 16 CLI unit tests
├── scripts/
│   ├── install.sh               # One-command build + install
│   └── uninstall.sh             # Complete removal
├── docs/                        # User Guide, Developer Guide, planning docs
├── Package.swift
└── Makefile
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
swift test  # 87 tests, all passing
```

### Current Status

✅ All 9 phases complete — P0 through P9
✅ 87 unit tests, all passing
✅ Zero build warnings
✅ Single-instance guard
✅ Live timer picker sync with Settings
✅ CLI companion with setup hints
✅ Display dimming on lid close

## Documentation

- [User Guide](docs/UserGuide.md) — How to use Crackinate
- [Developer Guide](docs/DeveloperGuide.md) — Architecture, design decisions, contributing
- [Feature Spec](docs/features.md) — Full feature specification
- [API Reference](docs/research-apis.md) — macOS API catalog
- [Architecture Research](docs/research-architecture.md) — Technology recommendations
- [Execution Plan](docs/EXECUTION_PLAN.md) — Phase-by-phase build plan

## License

MIT — see LICENSE file.

## Credits

Built with Swift 6, AppKit, SwiftUI, and IOKit.
Inspired by Amphetamine, Caffeine, and SleepOff.
