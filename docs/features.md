# Crackinate — Feature Specification

## Overview

Crackinate is a macOS menu bar app that prevents screen sleep and lid-close sleep, with configurable time limits, persistent settings, and safety guardrails.

---

## Core Features

### F1 — Screen Sleep Prevention

**Description:** Prevent the display and system from sleeping due to user inactivity. The computer stays fully awake with the screen on. This is the classic "Caffeine" behavior.

**Behavior:**
- When enabled, the display does not dim or turn off, and the system does not idle-sleep
- When disabled, normal macOS sleep behavior resumes immediately
- Does NOT affect manual sleep (Apple menu → Sleep still works)
- Does NOT prevent lid-close sleep (see F2)

**Implementation:** `NSProcessInfo.beginActivity` with `.idleSystemSleepDisabled + .idleDisplaySleepDisabled`

**Menu Bar Toggle:** Primary toggle in the popover — "Keep Screen Awake" switch

---

### F2 — Lid-Close Sleep Prevention

**Description:** Prevent the Mac from sleeping when the laptop lid is closed. This enables "clamshell mode without external display" — the system keeps running with the lid shut.

**Behavior:**
- When enabled, closing the lid does NOT trigger system sleep
- When disabled, closing the lid triggers normal sleep behavior
- Setting persists across reboots (kernel-level `pmset` setting)
- Requires one-time admin authorization to install a sudoers exception

**Implementation:** `pmset -a disablesleep 1 / 0` via passwordless sudoers file

**Menu Bar Toggle:** Secondary toggle in the popover — "Prevent Lid-Close Sleep" switch

**⚠️ Safety Warning:** User must be warned that this prevents sleep in a bag and can cause overheating.

---

### F3 — Combined Mode

**Description:** Both F1 and F2 can be independently toggled. The app supports four states:

| Screen Awake | Lid-Close Disabled | Effect |
|-------------|-------------------|--------|
| OFF | OFF | Normal macOS behavior (app idle) |
| ON | OFF | Screen stays on, but lid close still sleeps |
| OFF | ON | Screen can sleep, but lid close doesn't sleep system |
| ON | ON | Full keep-awake: screen on + lid close ignored |

---

## Timer Features

### F4 — Keep Awake Forever (Default)

**Description:** No time limit. Keep-awake stays active until the user manually turns it off.

**Behavior:**
- No automatic expiration
- Survives display sleep/wake cycles
- Screen sleep prevention must be recreated on app relaunch (assertions are process-scoped)
- Lid-close prevention persists across reboots

---

### F5 — Keep Awake for a Specific Duration

**Description:** User sets a time limit (5 min, 15 min, 30 min, 1 hour, 2 hours, Custom). Keep-awake automatically disables when the timer expires.

**Behavior:**
- Timer counts down in the menu bar popover (e.g., "Screen awake — 14:32 remaining")
- When timer expires, assertions are released / pmset is reset to 0
- App shows a notification: "Keep-awake session ended"
- If the app is quit before the timer expires, the timer is lost (screen sleep assertion may persist briefly via system timeout)
- If lid-close prevention was timer-based, pmset resets to 0 (NOT lost on quit — this is the kernel setting)

**Implementation:** 
- Screen sleep: `caffeinate -d -i -t <seconds>` subprocess, OR Timer + `ProcessInfo.endActivity`
- Lid-close: Timer + `pmset -a disablesleep 0` on expiry

**Settings UI:** Picker or segmented control for preset durations, plus a custom text field for arbitrary minutes.

---

### F6 — Countdown Display

**Description:** When a timer is active, the menu bar icon or popover shows remaining time.

**Behavior:**
- Popover shows "⏳ 14:32 remaining" with a cancel button
- Optional: menu bar shows a badge or changes icon to indicate timer mode
- When timer expires, icon reverts to inactive state

---

## Settings & Persistence

### F7 — Settings Window

**Description:** Standard macOS Preferences window accessible via the app menu or a gear icon in the popover.

**Tabs/Sections:**

| Section | Settings |
|---------|----------|
| **General** | Launch at login toggle |
| **Keep Awake** | Default timer duration (Forever / 5 min / 15 min / 30 min / 1 hr / 2 hr / Custom) |
| **Display** | Dim built-in display when lid is closed (while keep-awake active) |
| **Safety** | Auto-disable on critical thermal state, Warn on battery power with lid closed |
| **About** | Version, credits, links |

---

### F8 — Settings Persist Across Restarts

**Description:** All user preferences survive reboots.

**Implementation:** `UserDefaults` with `register(defaults:)` called at app init. Keys:

```
screenAwakeEnabled        Bool    (current toggle state for F1)
lidSleepDisabled          Bool    (current toggle state for F2)
defaultTimerDuration      Int     (seconds, 0 = forever)
launchAtLogin             Bool
dimDisplayWhenLidClosed   Bool
warnOnBatteryLidClosed    Bool
autoDisableOnThermal      Bool
```

**State restoration on launch:** The app reads pmset state and UserDefaults to restore toggle positions correctly. If `pmset disablesleep` is 1 but `lidSleepDisabled` UserDefault is false, the app detects the mismatch and offers to correct it.

---

### F9 — Launch at Login

**Description:** Option to automatically start Crackinate when the user logs in.

**Implementation:** `SMAppService.mainApp.register()` / `unregister()`

**Behavior:**
- Toggle in Settings → General
- User must approve first time (macOS shows notification)
- When enabled, app launches hidden (menu bar only) at login
- The app restores its last known keep-awake state on launch

---

### F10 — Auto-Revive if Killed

**Description:** If Crackinate crashes or is force-quit, it automatically restarts.

**Implementation:** LaunchAgent at `~/Library/LaunchAgents/com.crackinate.app.plist` with `KeepAlive → SuccessfulExit → false`

**Behavior:**
- Crashes (non-zero exit): restarts after 5-second throttle
- User chooses Quit from menu (exit 0): does NOT restart
- Force Quit from Activity Monitor (SIGKILL): restarts
- User holds Option and clicks Quit: does NOT restart (clean exit)
- If user disables "Launch at Login", the LaunchAgent is removed

---

## Safety Features

### F11 — Thermal State Monitoring

**Description:** Monitors system thermal state and auto-disables keep-awake if the Mac overheats.

**Behavior:**
| Thermal State | Action |
|--------------|--------|
| Nominal | No action |
| Fair | No action (system may begin throttling) |
| Serious | Show warning notification: "Your Mac is getting hot. Consider disabling keep-awake." |
| Critical | **Force disable** all keep-awake modes. Show critical alert. Log event. |

**Settings:** User can disable the auto-disable behavior (not recommended). Warning is always shown.

**Implementation:** `ProcessInfo.thermalStateDidChangeNotification`

---

### F12 — Battery Warning for Lid-Close Prevention

**Description:** Warns the user when enabling lid-close sleep prevention on battery power.

**Behavior:**
- When user toggles F2 ON while on battery: show dialog "Lid-close sleep prevention on battery will drain your battery quickly. Continue?"
- User choice is remembered for this session
- If AC power is lost while F2 is active: show notification
- Optional: auto-disable F2 when switching to battery (configurable in Settings)

**Implementation:** `IOPSCopyPowerSourcesInfo` polling or `IOPSNotificationCreateRunLoopSource`

---

### F13 — Lid State Awareness

**Description:** The app knows when the lid is open or closed, and adjusts behavior accordingly.

**Behavior:**
- When lid is open and F2 is enabled: status shows "Lid-close sleep is disabled" but no special action
- When lid is closed and F2 is enabled: status shows "Lid closed — staying awake"
- When lid is opened after being closed with F2 active: no automatic change (user may still want F2)
- When lid closes: if Display Dimming is enabled (F14), dim the built-in display

**Implementation:** Poll `AppleClamshellState` via IORegistry every 2 seconds

---

### F14 — Display Dimming When Lid Closed (Optional)

**Description:** When keep-awake is active and the lid closes, the built-in display is dimmed to 0 brightness to save power and reduce heat. Brightness is restored when the lid opens.

**Behavior:**
- Only applies to the built-in display (not external monitors)
- Saves current brightness before dimming
- Restores brightness only if the app set it to 0 (user may have changed it independently)
- Disabled by default; enabled in Settings → Display
- Does not affect external displays

**Implementation:** CoreDisplay private API (`CoreDisplay_Display_SetUserBrightness`)

---

### F15 — Safe Shutdown on Quit

**Description:** When the user quits Crackinate, all keep-awake assertions are released.

**Behavior:**
- Screen sleep assertions are released via `ProcessInfo.endActivity`
- The `caffeinate` subprocess (if any) is terminated
- Lid-close prevention (`pmset disablesleep`) is set back to 0
- Any active timers are cancelled

**Implementation:** `NSApplication.willTerminateNotification` handler + `AppDelegate.applicationWillTerminate`

---

## UI / UX Features

### F16 — Menu Bar Icon

**Description:** A status bar icon that indicates the current keep-awake state.

**States:**
| State | Icon | Description |
|-------|------|-------------|
| Inactive | ☀️ Sun / empty cup | No keep-awake active |
| Screen only | ☕️ Filled cup | Screen sleep prevented |
| Lid-close only | 🌙 Moon | Lid-close sleep disabled |
| Both active | ⚡ Lightning bolt | Full keep-awake |
| Timer active | ⏳ Hourglass | Timer countdown in progress |
| Thermal warning | 🔥 Fire | Critical temperature — keep-awake disabled |

**Interaction:**
- Left-click: toggle popover open/closed
- Right-click / Option-click: context menu (Preferences, Quit)

---

### F17 — Popover Menu

**Description:** The main interaction panel that appears when clicking the menu bar icon.

**Layout:**
```
┌─────────────────────────────┐
│  ☕️  Crackinate              │
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

**Behavior:**
- Toggles react immediately (no "Apply" button)
- Timer picker and countdown only visible when a toggle is ON
- Popover dismisses when clicking outside (`.transient` behavior)
- Popover can be pinned open by holding Option while clicking

---

### F18 — Keyboard Shortcut

**Description:** Global keyboard shortcut to toggle the primary keep-awake mode.

**Default:** `Control + Command + K` (configurable in Settings)

**Behavior:**
- Toggles both screen sleep prevention and lid-close prevention simultaneously
- Shows a brief HUD/notification confirming the new state
- Works even when the app is in the background (global hotkey)

---

### F19 — Notifications

**Description:** macOS notification center alerts for important state changes.

**Notifications:**
| Event | Notification |
|-------|-------------|
| Timer expired | "Keep-awake session ended. Your Mac can now sleep normally." |
| Thermal critical | "Crackinate disabled keep-awake due to critical temperature." |
| Battery warning | "Lid-close sleep prevention is active on battery power." |
| AC power lost | "Switched to battery — lid-close prevention still active." |

---

## Non-Functional Requirements

### N1 — Minimum macOS Version

**Target:** macOS 14 (Sonoma) — supports SMAppService without deprecation warnings, MenuBarExtra available.  
**Fallback:** macOS 13 (Ventura) at minimum for SMAppService.

### N2 — Distribution

**Not for Mac App Store** — Apple rejects apps that disable lid-close sleep. Distribute via:
- Direct download from GitHub Releases (`.dmg` or `.zip`)
- Homebrew cask

### N3 — Notarization

App must be signed and notarized for distribution. The sudoers file approach and IOKit calls pass notarization. CoreDisplay private API (display dimming) should be optional and loaded via `dlopen`/`dlsym` to avoid static linking issues.

### N4 — Apple Silicon Native

Must run natively on Apple Silicon (M1/M2/M3/M4). Both Intel and ARM builds in a Universal Binary.

### N5 — Low Resource Usage

Menu bar app must be lightweight:
- CPU: <1% when idle (polling timer at 2s intervals is the only background work)
- Memory: <50MB resident
- No background processes except the optional `caffeinate` subprocess during active keep-awake

---

## Feature Priority (MVP vs Future)

### MVP (v1.0)
- [x] F1 — Screen Sleep Prevention
- [x] F2 — Lid-Close Sleep Prevention  
- [x] F3 — Combined Mode (independent toggles)
- [x] F4 — Keep Awake Forever
- [x] F5 — Keep Awake for Duration (preset times only)
- [x] F7 — Settings Window (basic: launch at login, default timer)
- [x] F8 — Settings Persistence
- [x] F9 — Launch at Login
- [x] F10 — Auto-Revive if Killed
- [x] F11 — Thermal Safety (critical auto-disable)
- [x] F12 — Battery Warning
- [x] F15 — Safe Shutdown on Quit
- [x] F16 — Menu Bar Icon
- [x] F17 — Popover Menu

### v1.1
- [ ] F6 — Countdown Display in menu bar
- [ ] F13 — Lid State Awareness (icon changes when lid closes)
- [ ] F14 — Display Dimming When Lid Closed
- [ ] F18 — Keyboard Shortcut
- [ ] F19 — Notifications

### v2.0
- [ ] Custom timer durations (freeform text input)
- [ ] Per-app keep-awake triggers (e.g., "stay awake while Zoom is running")
- [ ] Schedules (e.g., "keep awake weekdays 9AM–5PM")
- [ ] Apple Watch complication / iOS companion for remote toggle
- [ ] CLI companion (`crackinate on|off|status|timer 30m`)
