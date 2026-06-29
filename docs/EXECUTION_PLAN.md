# Crackinate — Execution Plan

> **Generated:** 2026-06-29
> **Source docs:** `features.md`, `research-apis.md`, `research-architecture.md`

---

## Overview

Crackinate is a macOS menu bar app that prevents screen sleep and lid-close sleep with configurable time limits, persistent settings, and safety guardrails. Greenfield project — no existing code.

**Target:** macOS 14 (Sonoma) minimum
**Distribution:** Personal/internal use only — NOT distributed publicly. Apple does not allow apps that prevent lid-close sleep on the Mac App Store, and notarization of such an app carries risk. This is a tool for your own Mac.
**Language:** Swift 100%
**UI:** AppKit NSStatusItem + NSPopover with SwiftUI views
**Architecture:** Single-process with optional `caffeinate` subprocess and LaunchAgent for auto-revive

---

## Phase Summary

| Phase | Name | Est. Effort | Dependencies |
|-------|------|-------------|-------------|
| **P0** | Project Scaffold & Core Infrastructure | 1-2 days | None |
| **P1** | Core Keep-Awake Engine | 2-3 days | P0 |
| **P2** | Menu Bar UI (Popover + Icon) | 2-3 days | P1 |
| **P3** | Timer & Duration Features | 1-2 days | P2 |
| **P4** | Settings & Persistence | 1-2 days | P2 |
| **P5** | Safety Systems | 2-3 days | P1, P2 |
| **P6** | Sudo/Privilege Setup & Lid-Close | 2-3 days | P1 |
| **P7** | Launch at Login & Auto-Revive | 1-2 days | P0 |
| **P8** | Polish, Notifications & Keyboard Shortcut | 2-3 days | P2-P7 |
| **P9** | Testing, Edge Cases & Documentation | 2-3 days | P8 |

> **Total estimated effort:** 14-23 days for a solo developer. With a team of 2-3, parallelizable to ~10-14 days.

---

## Detailed Phases

---

### P0 — Project Scaffold & Core Infrastructure

**Goal:** Create the Xcode project, establish file structure, configure build settings, and wire up the app lifecycle (entry point, AppDelegate, LSUIElement, minimum deployment target).

#### Tasks

| # | Task | File(s) | Details |
|---|------|---------|---------|
| 0.1 | Create Xcode project | `Crackinate.xcodeproj` | macOS App target, Swift, deployment target macOS 14.0, no storyboard, no Core Data |
| 0.2 | Configure Info.plist | `Info.plist` | Add `LSUIElement = YES` (hide from Dock). Set `CFBundleIdentifier = com.crackinate.app`. |
| 0.3 | Create `CrackinateApp.swift` | `Crackinate/CrackinateApp.swift` | `@main` entry point with `@NSApplicationDelegateAdaptor`. `Settings { ... }` scene. `init()` calls `UserDefaults.register(defaults:)`. |
| 0.4 | Create `AppDelegate.swift` | `Crackinate/AppDelegate.swift` | `NSApplicationDelegate` class. Sets activation policy to `.accessory`. Creates `NSStatusItem`. Creates `NSPopover`. Wire up terminate cleanup. |
| 0.5 | Create `Constants.swift` | `Crackinate/Constants.swift` | All UserDefaults keys as string constants (`SettingsKeys` enum). Bundle identifier constant. Sudoers path constant. LaunchAgent label constant. |
| 0.6 | Create `PersistenceManager.swift` | `Crackinate/PersistenceManager.swift` | Wrapper around `UserDefaults.standard` with typed get/set for every setting + `registerDefaults()` called from app init. |
| 0.7 | Create directory structure | N/A | Ensure folders: Models (if needed), Views, Managers, Utilities, Assets.xcassets |
| 0.8 | Add SPM/Carthage dependencies (if any) | `project.pbxproj` | Determine if any external packages needed. Likely none — all Apple frameworks. |

#### Validation
- [ ] Project builds without errors on macOS 14 target
- [ ] App launches and shows nothing in Dock (LSUIElement working)
- [ ] Status bar item appears (can be a placeholder icon)
- [ ] `NSApplication.willTerminateNotification` fires on Cmd+Q

---

### P1 — Core Keep-Awake Engine

**Goal:** Implement the two independent keep-awake mechanisms — screen sleep prevention (NSProcessInfo/IOPMAssertion) and lid-close sleep prevention (pmset). Ensure safe shutdown on quit.

#### Tasks

| # | Task | File(s) | Details |
|---|------|---------|---------|
| 1.1 | Create `KeepAwakeManager.swift` | `Crackinate/KeepAwakeManager.swift` | Singleton. Manages both screen sleep assertions and lid-close pmset. Provides `enableScreenAwake()`, `disableScreenAwake()`, `enableLidClosePrevention()`, `disableLidClosePrevention()`, `disableAll()`. `isScreenAwakeActive` and `isLidClosePreventionActive` computed properties. |
| 1.2 | Implement screen sleep via `NSProcessInfo.beginActivity` | `KeepAwakeManager.swift` | Use `.idleSystemSleepDisabled` + `.idleDisplaySleepDisabled`. Strongly retain the returned `NSObjectProtocol`. `endActivity()` on disable. |
| 1.3 | Implement lid-close sleep via `pmset` subprocess | `KeepAwakeManager.swift` | `Process` wrapper: `pmset -a disablesleep 0/1`. Run via `sudo` using the passwordless sudoers file (installed in P6). Parse output for error handling. |
| 1.4 | Implement `disableAll()` | `KeepAwakeManager.swift` | Release screen assertion + run `sudo pmset -a disablesleep 0`. Called on app quit and thermal critical. |
| 1.5 | Wire up `applicationWillTerminate` | `AppDelegate.swift` | Call `KeepAwakeManager.shared.disableAll()` in the terminate handler. |
| 1.6 | State restoration on launch | `KeepAwakeManager.swift` | Check `pmset -g live` for current `disablesleep` state. Read UserDefaults. Reconcile any mismatch (app state vs kernel state). If pmset shows `disablesleep 1` but user default says false, show alert offering to correct. |
| 1.7 | Unit tests for KeepAwakeManager | `CrackinateTests/KeepAwakeManagerTests.swift` | Mock `Process` for pmset. Test enable/disable calls. Test state mismatch detection. |

#### Validation
- [ ] Calling `enableScreenAwake()` prevents display sleep (verify with `pmset -g assertions`)
- [ ] Calling `disableScreenAwake()` releases assertions (verify with `pmset -g assertions`)
- [ ] App quit (Cmd+Q) releases all assertions
- [ ] `pmset -a disablesleep 0/1` works with passwordless sudo (after P6 setup)
- [ ] State restoration detects pmset mismatch on launch

---

### P2 — Menu Bar UI (Popover + Icon)

**Goal:** Build the primary user interface — menu bar icon with state awareness and the popover with toggle controls.

#### Tasks

| # | Task | File(s) | Details |
|---|------|---------|---------|
| 2.1 | Create `IconProvider.swift` | `Crackinate/IconProvider.swift` | Returns `NSImage` for each state: inactive (empty cup/sun), screen-only (filled cup), lid-only (moon), both (lightning), timer (hourglass), thermal-warning (fire). Use SF Symbols. |
| 2.2 | Update `AppDelegate` with dynamic icon | `AppDelegate.swift` | `updateIcon()` method called on state changes. Observes KeepAwakeManager and timer state. Also handles right-click for context menu. |
| 2.3 | Create `PopoverView.swift` | `Crackinate/PopoverView.swift` | Main SwiftUI view for the popover content. Layout per the spec: title, toggles, timer section, separator, Preferences/Quit buttons. |
| 2.4 | Create toggle row component | `Crackinate/Components/ToggleRow.swift` | Reusable `HStack` with label text and `Toggle` bound to `@AppStorage`. |
| 2.5 | Create timer picker component | `Crackinate/Components/TimerPicker.swift` | Segmented control or `Picker` with options: Forever, 5 min, 15 min, 30 min, 1 hr, 2 hr. Hidden when no toggle is ON. |
| 2.6 | Create countdown display component | `Crackinate/Components/CountdownDisplay.swift` | Shows "⏳ X:XX remaining" with a Stop button. Visible only when timer is active. |
| 2.7 | Wire popover toggles to KeepAwakeManager | `PopoverView.swift` | Toggle actions call `KeepAwakeManager.shared.enable/disableScreenAwake()` etc. Read current state from manager. |
| 2.8 | Implement popover behavior | `PopoverView.swift` | `.transient` behavior (dismisses on click-outside). Option-click to pin. Popover resizes based on content (timer visible/hidden). |
| 2.9 | Dark mode support | All views | Use SwiftUI's automatic color scheme adaptation. Test manually. |

#### Validation
- [ ] Left-click status item shows popover
- [ ] Click outside dismisses popover
- [ ] Toggles visually represent current keep-awake state
- [ ] Flicking a toggle immediately calls KeepAwakeManager
- [ ] Icon changes to reflect state (e.g., cup filled when screen awake)
- [ ] Right-click shows context menu (Preferences, Quit)
- [ ] Dark mode appearance is correct

---

### P3 — Timer & Duration Features

**Goal:** Implement keep-awake for a specific duration with countdown timer and auto-disable on expiry.

#### Tasks

| # | Task | File(s) | Details |
|---|------|---------|---------|
| 3.1 | Create `TimerManager.swift` | `Crackinate/TimerManager.swift` | Singleton. `startTimer(duration: TimeInterval, onExpiry: @escaping () -> Void)`. `stopTimer()`. Publishes `remainingTime: TimeInterval?` and `isTimerActive: Bool`. Uses `Timer.scheduledTimer(withTimeInterval:repeats:)` for countdown display. Uses `DispatchWorkItem` for expiry callback. |
| 3.2 | Integrate TimerManager with KeepAwakeManager | `KeepAwakeManager.swift` | `enableScreenAwake(duration: TimeInterval?)` — if duration provided, start timer; on expiry, disable. Same pattern for lid-close. |
| 3.3 | Wire timer picker to KeepAwakeManager | `PopoverView.swift` | When user selects a duration from the picker, pass it to `enableScreenAwake(duration:)`. When "Forever" selected, pass `nil`. |
| 3.4 | Implement countdown display UI | `PopoverView.swift` | Show `CountdownDisplay` component when timer is active. Bind to `TimerManager.shared.$remainingTime`. |
| 3.5 | Handle timer loss on app quit | `TimerManager.swift` | On `applicationWillTerminate`, cancel timer and release assertions. The timer state is intentionally NOT persisted — document this in the app. |
| 3.6 | Handle lid-close timer expiry | `TimerManager.swift` | Ensure `pmset -a disablesleep 0` is called on expiry. This is critical — unlike screen assertions (which auto-release), pmset persists. |

#### Validation
- [ ] Selecting "30 min" enables screen awake and shows countdown
- [ ] Countdown displays correct remaining time, decrementing each second
- [ ] At 0:00, both keep-awake modes disable and countdown disappears
- [ ] "Stop" button cancels timer and disables keep-awake
- [ ] App quit during timer properly cleans up assertions AND pmset

---

### P4 — Settings & Persistence

**Goal:** Build the Preferences window with all settings, persist everything in UserDefaults, and restore state on launch.

#### Tasks

| # | Task | File(s) | Details |
|---|------|---------|---------|
| 4.1 | Create `SettingsView.swift` | `Crackinate/SettingsView.swift` | SwiftUI view with `TabView` (General, Keep Awake, Display, Safety, About tabs). |
| 4.2 | Build General tab | `SettingsView.swift` | Launch at Login toggle. |
| 4.3 | Build Keep Awake tab | `SettingsView.swift` | Default timer duration picker (same options as popover). |
| 4.4 | Build Display tab | `SettingsView.swift` | "Dim built-in display when lid closed" toggle. |
| 4.5 | Build Safety tab | `SettingsView.swift` | "Auto-disable keep-awake on critical thermal" toggle. "Warn before enabling lid-close on battery" toggle. |
| 4.6 | Build About tab | `SettingsView.swift` | Version (from bundle), credits, links to GitHub. |
| 4.7 | Implement `PersistenceManager` fully | `PersistenceManager.swift` | All get/set methods. `registerDefaults()` with sensible defaults. Thread-safe reads/writes. |
| 4.8 | Wire `@AppStorage` throughout views | All SwiftUI views | Replace any hardcoded `UserDefaults` calls with `@AppStorage` where possible (SwiftUI views). Use `PersistenceManager` in non-View code. |
| 4.9 | Settings → Gear icon in popover | `PopoverView.swift` | Gear button opens `Settings` scene (CrackinateApp already declares this scene). |
| 4.10 | Implement `SMAppService` launch at login | `PersistenceManager.swift` + `SettingsView.swift` | Toggle calls `SMAppService.mainApp.register()/unregister()`. Handle errors with alert. |

#### Validation
- [ ] Settings window opens from app menu (Cmd+,) and gear icon
- [ ] All tabs display correctly with toggles and pickers
- [ ] Changing a setting persists across app relaunches
- [ ] Launch at login toggle registers/unregisters with SMAppService
- [ ] Default timer duration is correctly read on launch

---

### P5 — Safety Systems

**Goal:** Implement thermal monitoring (auto-disable on critical), AC power detection (warn on battery), lid state detection, and optional display dimming.

#### Tasks

| # | Task | File(s) | Details |
|---|------|---------|---------|
| 5.1 | Create `ThermalMonitor.swift` | `Crackinate/ThermalMonitor.swift` | Singleton. Observes `ProcessInfo.thermalStateDidChangeNotification`. On `.serious`: show notification. On `.critical`: call `KeepAwakeManager.shared.disableAll()` + show critical alert. Respects `autoDisableOnThermal` setting. |
| 5.2 | Implement thermal alert UI | `ThermalMonitor.swift` | `NSAlert` with `.critical` style for critical thermal. Standard notification for serious. |
| 5.3 | Create `PowerMonitor.swift` | `Crackinate/PowerMonitor.swift` | Polls `IOPSCopyPowerSourcesInfo` every 10 seconds. Publishes `isOnACPower: Bool`. Calls `IOPSNotificationCreateRunLoopSource` for instant notifications. |
| 5.4 | Implement battery warning on lid-close toggle | `PopoverView.swift` + `KeepAwakeManager.swift` | When user toggles F2 ON and `isOnACPower == false`, show confirmation dialog. Remember choice for session. |
| 5.5 | Implement AC-loss notification | `PowerMonitor.swift` | When switching from AC to battery while lid-close prevention is active, show notification: "Switched to battery — lid-close prevention still active." |
| 5.6 | Create `LidDetector.swift` | `Crackinate/LidDetector.swift` | Poll `AppleClamshellState` IORegistry every 2 seconds. Detects transitions (open → closed, closed → open). Publishes `isLidClosed: Bool`. |
| 5.7 | Integrate lid state with icon | `IconProvider.swift` | When lid closed + F2 active → different icon. |
| 5.8 | Create `DisplayDimmer.swift` (v1.1 — optional) | `Crackinate/DisplayDimmer.swift` | `dlopen`/`dlsym` CoreDisplay private API. Saves brightness, dims to 0 on lid close, restores on lid open. Only for built-in display. Respects `dimDisplayWhenLidClosed` setting. |

#### Validation
- [ ] System thermal state change triggers notifications at `.serious`
- [ ] Critical thermal forces keep-awake disable
- [ ] Toggling lid-close on battery shows confirmation dialog
- [ ] Unplugging AC while lid-close is active shows notification
- [ ] Lid state is correctly detected (open/closed)
- [ ] Display dims on lid close (opt-in, v1.1)

---

### P6 — Sudo/Privilege Setup & Lid-Close

**Goal:** Implement the one-time sudoers file installation so lid-close prevention doesn't require repeated password prompts. Handle setup UI and error states.

#### Tasks

| # | Task | File(s) | Details |
|---|------|---------|---------|
| 6.1 | Create `SudoersInstaller.swift` | `Crackinate/SudoersInstaller.swift` | `isInstalled()` — checks for `/etc/sudoers.d/crackinate`. `install()` — writes temp file, uses AppleScript `do shell script ... with administrator privileges` to move to `/etc/sudoers.d/` and `chmod 0440`. `uninstall()` — removes the file. |
| 6.2 | Create setup wizard / onboarding view | `Crackinate/SetupView.swift` | Shown on first launch. Explains what the app needs root for. "Set Up" button triggers sudoers install. Shows progress/error. |
| 6.3 | Handle sudoers installation errors | `SudoersInstaller.swift` | Detect common failures: user cancels auth, file permissions wrong, syntax error. Show user-friendly error messages. |
| 6.4 | Handle sudoers missing on lid-close toggle | `KeepAwakeManager.swift` | When user tries to enable lid-close and sudoers is NOT installed, show alert: "Requires one-time setup" → triggers installer. |
| 6.5 | Validate sudoers syntax | `SudoersInstaller.swift` | After writing, run `visudo -c -f /etc/sudoers.d/crackinate` or at minimum verify the file was written correctly. |
| 6.6 | Test pmset with passwordless sudo | `SudoersInstaller.swift` | After installation, test `sudo pmset -a disablesleep 1` to verify it doesn't prompt for password. |
| 6.7 | Create uninstall script/routine | `SudoersInstaller.swift` | On app uninstall (or user request), remove the sudoers file. This can be triggered from Settings → Advanced. |

#### Validation
- [ ] First run shows setup wizard explaining sudoers need
- [ ] Admin auth prompt appears once during setup
- [ ] After setup, `sudo pmset -a disablesleep 1` runs without password
- [ ] `sudoers.d/crackinate` has permissions 0440
- [ ] Invalid sudoers syntax is caught before writing
- [ ] Toggling lid-close prevention works after setup
- [ ] Uninstalling removes the sudoers file cleanly

---

### P7 — Launch at Login & Auto-Revive

**Goal:** App starts automatically at login and restarts if it crashes.

#### Tasks

| # | Task | File(s) | Details |
|---|------|---------|---------|
| 7.1 | Create `LaunchAgentManager.swift` | `Crackinate/LaunchAgentManager.swift` | `install()` — writes LaunchAgent plist to `~/Library/LaunchAgents/com.crackinate.app.plist`, runs `launchctl load`. `uninstall()` — `launchctl unload` + delete file. `isInstalled()` — file exists check. |
| 7.2 | Generate LaunchAgent plist | `LaunchAgentManager.swift` | XML with `KeepAlive → SuccessfulExit → false`, `ThrottleInterval → 5`, `RunAtLoad → true`. `ProgramArguments` points to `/Applications/Crackinate.app/Contents/MacOS/Crackinate`. Handle non-standard install locations. |
| 7.3 | Integrate LaunchAgent with Launch at Login setting | `PersistenceManager.swift` | When user enables "Launch at Login", also install the LaunchAgent for auto-revive. When disabled, remove both SMAppService registration AND LaunchAgent. |
| 7.4 | Handle clean quit vs crash | `AppDelegate.swift` | Clean quit (user chooses Quit, exit 0): LaunchAgent does NOT restart. Crash (non-zero exit, SIGKILL): LaunchAgent restarts. Implement clean exit path. |
| 7.5 | Option-click to skip auto-revive quit | `AppDelegate.swift` | Option+Quit → exit 0 cleanly without restart. Document this in the UI. |
| 7.6 | Handle app path changes | `LaunchAgentManager.swift` | On launch, verify the LaunchAgent plist ProgramArguments matches the current app path. Update if needed (e.g., user moved the app). |

#### Validation
- [ ] Enabling "Launch at Login" registers with SMAppService AND installs LaunchAgent
- [ ] App auto-starts on next login (both SMAppService and LaunchAgent)
- [ ] Force-quitting the app causes it to restart within 5-10 seconds
- [ ] Normal Quit (Cmd+Q or menu Quit) does NOT restart the app
- [ ] Disabling "Launch at Login" removes both SMAppService and LaunchAgent
- [ ] Moving the app to a different location doesn't break the LaunchAgent

---

### P8 — Polish, Notifications & Keyboard Shortcut

**Goal:** Add notifications for key events, global keyboard shortcut, and UI polish including animation and tooltips.

#### Tasks

| # | Task | File(s) | Details |
|---|------|---------|---------|
| 8.1 | Create `NotificationManager.swift` | `Crackinate/NotificationManager.swift` | Central manager for all user notifications. Methods: `timerExpired()`, `thermalCritical()`, `thermalWarning()`, `batteryWarning()`, `acPowerLost()`. Uses `UNUserNotificationCenter`. |
| 8.2 | Request notification permission | `AppDelegate.swift` | On first launch, request notification authorization. Handle declined gracefully (no notifications, but app still works). |
| 8.3 | Integrate notifications with feature managers | Various | `TimerManager` calls `NotificationManager.timerExpired()` on expiry. `ThermalMonitor` calls thermal notifications. `PowerMonitor` calls battery/AC notifications. |
| 8.4 | Create `HotkeyManager.swift` | `Crackinate/HotkeyManager.swift` | Register global keyboard shortcut (defaults: Ctrl+Cmd+K). Uses `RegisterEventHotKey` from Carbon or `NSEvent.addGlobalMonitorForEvents`. Configurable in Settings. |
| 8.5 | Implement hotkey toggle behavior | `HotkeyManager.swift` | On hotkey press, toggle both screen awake and lid-close prevention. Show brief HUD/floating notification confirming the new state. |
| 8.6 | Add hotkey configuration to Settings | `SettingsView.swift` | Allow user to record a custom shortcut key combination. Save to UserDefaults. |
| 8.7 | Create HUD overlay for hotkey feedback | `Crackinate/HUDView.swift` | Transient overlay showing "Keep Awake: ON 🔛" or "Keep Awake: OFF 🌙". Fades out after 2 seconds. |
| 8.8 | Add tooltips to UI elements | `PopoverView.swift` | Help tooltips on toggles explaining what each does. |
| 8.9 | Polish popover animations | `PopoverView.swift` | Smooth transitions when timer section appears/disappears. Animated icon changes. |
| 8.10 | Accessibility labels | All views | Add `.accessibilityLabel()` and `.accessibilityHint()` to all interactive elements. |

#### Validation
- [ ] Notifications appear for all defined events
- [ ] Blocking notifications still allows the app to function
- [ ] Ctrl+Cmd+K (or custom shortcut) toggles keep-awake from any app
- [ ] HUD shows briefly after hotkey toggle
- [ ] Tooltips are helpful and explain each control
- [ ] VoiceOver reads all interactive elements correctly

---

### P9 — Testing, Edge Cases & Documentation

**Goal:** Comprehensive testing, edge case handling, and user-facing documentation.

#### Tasks

| # | Task | File(s) | Details |
|---|------|---------|---------|
| 9.1 | Write unit tests for KeepAwakeManager | `CrackinateTests/` | Test enable/disable, state tracking, pmset parsing, mismatch detection. |
| 9.2 | Write unit tests for PersistenceManager | `CrackinateTests/` | Test all get/set, defaults, migration of settings. |
| 9.3 | Write unit tests for TimerManager | `CrackinateTests/` | Test timer creation, countdown, expiry callback, cancellation. |
| 9.4 | Write integration tests | `CrackinateTests/` | Test full flows: enable → timer set → expiry → disable. State restoration on simulated relaunch. |
| 9.5 | Test edge cases | Manual + automated | List below (see Edge Cases section). |
| 9.6 | Performance testing | Manual | Verify CPU < 1% when idle. Memory < 50MB. Use Instruments (Time Profiler, Allocations). |
| 9.7 | Test on multiple macOS versions | Manual | macOS 14 (Sonoma), macOS 15 (Sequoia). Both Apple Silicon and Intel. |
| 9.8 | Test with other keep-awake apps | Manual | Run alongside Amphetamine, Caffeine. Verify no conflicts. Document known interactions. |
| 9.9 | Create user guide | `docs/UserGuide.md` | How to use, what each toggle does, safety warnings, keyboard shortcuts, troubleshooting. |
| 9.10 | Create developer guide | `docs/DeveloperGuide.md` | Project architecture, how to build, how to contribute, API reference. |

#### Edge Cases to Test

- [ ] App launched while pmset disablesleep is already 1 (from previous session or another app)
- [ ] Two instances of the app running simultaneously
- [ ] App moved to Trash while running
- [ ] System goes to sleep manually (Apple menu → Sleep) while keep-awake is active
- [ ] External display connected/disconnected while keep-awake is active
- [ ] MacBook lid closed while on AC power with lid-close prevention active
- [ ] Thermal critical event occurs during timer-based keep-awake
- [ ] Battery drops below 5% while lid-close prevention is active
- [ ] App launched on a desktop Mac (iMac, Mac Studio) — lid detection should gracefully return nil
- [ ] macOS rapid user switching
- [ ] App launched from a non-/Applications path (DMG, Downloads)
- [ ] Very long timer durations (24 hours+)
- [ ] System time changes (NTP sync) while timer is active
- [ ] Language/locale changes while app is running

---

## Master Checklist

### P0 — Project Scaffold
- [ ] Xcode project created with macOS 14 target
- [ ] Info.plist with LSUIElement = YES
- [ ] CrackinateApp.swift (entry point + Settings scene)
- [ ] AppDelegate.swift (status item + popover shell)
- [ ] Constants.swift (all string keys)
- [ ] PersistenceManager.swift (UserDefaults wrapper)
- [ ] Directory structure established
- [ ] Project builds and runs (empty popover, status item visible)

### P1 — Core Keep-Awake Engine
- [ ] KeepAwakeManager singleton
- [ ] Screen sleep prevention via NSProcessInfo
- [ ] Lid-close sleep prevention via pmset Process wrapper
- [ ] disableAll() releases everything
- [ ] applicationWillTerminate calls disableAll()
- [ ] State restoration on launch (pmset sync check)
- [ ] Unit tests for KeepAwakeManager

### P2 — Menu Bar UI
- [ ] IconProvider with all state icons
- [ ] Dynamic icon updates based on state
- [ ] PopoverView with layout per spec
- [ ] ToggleRow component
- [ ] TimerPicker component
- [ ] CountdownDisplay component
- [ ] Toggles wired to KeepAwakeManager
- [ ] Popover .transient behavior
- [ ] Dark mode support verified

### P3 — Timer Features
- [ ] TimerManager singleton
- [ ] Timer integrated with KeepAwakeManager
- [ ] Timer picker wired to popover
- [ ] Countdown display updates in real-time
- [ ] Timer expiry disables keep-awake
- [ ] Timer cleanup on app quit
- [ ] Lid-close pmset reset on timer expiry

### P4 — Settings & Persistence
- [ ] SettingsView with all tabs (General, Keep Awake, Display, Safety, About)
- [ ] All settings persisted in UserDefaults
- [ ] @AppStorage used in SwiftUI views
- [ ] Launch at Login toggle (SMAppService)
- [ ] Gear icon in popover opens Settings
- [ ] Default timer duration read correctly

### P5 — Safety Systems
- [ ] ThermalMonitor observing thermalStateDidChangeNotification
- [ ] Critical thermal forces disableAll()
- [ ] Thermal alert UI (notification + NSAlert)
- [ ] PowerMonitor tracking AC/battery
- [ ] Battery warning on lid-close toggle
- [ ] AC-loss notification
- [ ] LidDetector polling AppleClamshellState
- [ ] Lid state integrated with icon
- [ ] DisplayDimmer (v1.1, optional)

### P6 — Sudo/Privilege Setup
- [ ] SudoersInstaller (install, uninstall, check)
- [ ] Setup wizard / onboarding view
- [ ] Error handling for auth cancellation
- [ ] Lid-close toggle triggers install if missing
- [ ] Sudoers syntax validation
- [ ] Passwordless pmset works after install
- [ ] Uninstall removes sudoers file

### P7 — Launch & Auto-Revive
- [ ] LaunchAgentManager (install, uninstall, check)
- [ ] LaunchAgent plist with KeepAlive + ThrottleInterval
- [ ] Integrated with Launch at Login setting
- [ ] Clean quit exits 0 (no restart)
- [ ] Force quit / crash restarts app
- [ ] Option+Quit exits cleanly
- [ ] App path changes handled

### P8 — Polish & Extras
- [ ] NotificationManager with all event methods
- [ ] Notification permission requested at launch
- [ ] Notifications integrated with all managers
- [ ] HotkeyManager with global shortcut
- [ ] Hotkey toggles keep-awake
- [ ] Custom shortcut configurable in Settings
- [ ] HUD overlay for hotkey feedback
- [ ] Tooltips on all controls
- [ ] Accessibility labels on all elements
- [ ] README.md
- [ ] CONTRIBUTING.md

### P9 — Testing & Docs
- [ ] Unit tests for KeepAwakeManager
- [ ] Unit tests for PersistenceManager
- [ ] Unit tests for TimerManager
- [ ] Integration tests for full flows
- [ ] All edge cases tested
- [ ] Performance verified (<1% CPU, <50MB)
- [ ] Tested on macOS 14 + 15, Apple Silicon + Intel
- [ ] Tested alongside other keep-awake apps
- [ ] User Guide written
- [ ] Developer Guide written

---

## Architecture Diagram

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
│  │ (AppleClamshell│ │(CoreDisplay) │ │ (UNUserNotifCtr)  │  │
│  │  IORegistry)   │ │              │ │                   │  │
│  └───────────────┘ └──────────────┘ └───────────────────┘  │
│                                                             │
│  ┌───────────────┐ ┌──────────────┐ ┌───────────────────┐  │
│  │ SudoersInstaller││LaunchAgentMgr│ │ HotkeyManager     │  │
│  │ (/etc/sudoers) │ │(launchd plist)│ │(Carbon HotKey)   │  │
│  └───────────────┘ └──────────────┘ └───────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## Key Implementation Notes

### Threading Model
- **Main thread:** All UI updates, NSStatusItem manipulation, NSPopover display
- **Background:** pmset Process execution, IOKit polling timers, timer countdown callbacks (delivered on main via DispatchQueue.main)
- **No GCD overuse:** Timer uses RunLoop.main, notifications arrive on main

### Error Handling Strategy
- `pmset` failures: Show alert, suggest checking sudoers setup
- `SMAppService` failures: Log, show alert with "Open System Settings" button
- IOKit failures (lid detection): Gracefully degrade — assume lid open
- Thermal monitoring failure: Log, don't crash — safety net is gone but app still works
- Notifications permission denied: No alerts, just silently skip notifications

### Code Style
- **Singletons:** `KeepAwakeManager.shared`, `ThermalMonitor.shared`, `PowerMonitor.shared`, `TimerManager.shared`, `LidDetector.shared`
- **SwiftUI for views, UIKit/AppKit where necessary:** NSStatusItem requires AppKit
- **MVVM-light:** SwiftUI views bind to `@Published` properties on singleton managers
- **No Combine in non-UI code:** Keep service layer simple with closures and delegates

---

## Risk Register

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| pmset disablesleep broken in future macOS | Low | High | Monitor macOS betas. Fallback: only screen sleep prevention. |
| CoreDisplay API changes/removed | Medium | Low | Feature is optional (v1.1). Graceful fallback via dlopen. |
| Sudoers file causes system issues | Low | Critical | Validate syntax with visudo. Test thoroughly. Provide uninstall. |
| Thermal events not firing reliably | Low | Medium | Poll thermalState as backup every 30s on top of notifications. |
| SMAppService deprecation path | Low | Low | Monitor WWDC. Migration path to whatever replaces it. |
| Conflict with Amphetamine/Caffeine | Medium | Low | Document known interactions. Stacking assertions is generally safe. |
| App crashes causing pmset stuck at 1 | Medium | High | State restoration on launch detects and offers to fix. Thermal safety as last resort. |

---

## v1.0 MVP Exit Criteria

The following must all be true for v1.0 to ship:

1. Screen sleep prevention works (verified via `pmset -g assertions`)
2. Lid-close sleep prevention works (verified by closing lid, system stays awake)
3. Both modes can be toggled independently from the popover
4. Timer durations (preset: 5min, 15min, 30min, 1hr, 2hr) work end-to-end
5. Timer expiry correctly disables keep-awake including pmset reset
6. UserDefaults persist across launches
7. Launch at Login works (SMAppService)
8. Auto-revive from crash works (LaunchAgent)
9. Critical thermal event disables all keep-awake
10. Battery warning appears when enabling lid-close on battery
11. All assertions released on clean quit
12. No crashes in 24 hours of continuous use
13. CPU < 1% idle, memory < 50MB
14. User Guide exists and is accurate

---

## v1.1 Feature Additions

- [ ] Countdown display in menu bar (badge or icon change)
- [ ] Lid state awareness (icon changes when lid closes)
- [ ] Display dimming when lid closed
- [ ] Keyboard shortcut (Ctrl+Cmd+K) with HUD
- [ ] Notifications for all events
