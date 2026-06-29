# Crackinate User Guide

## What is Crackinate?

Crackinate is a menu bar app that keeps your Mac awake. It prevents two things:

1. **Screen sleep** — Your display dimming or turning off from inactivity
2. **Lid-close sleep** — Your Mac sleeping when you close the lid

## Getting Started

### Installation

1. Download the latest `Crackinate.app`
2. Drag it to your `/Applications` folder
3. Open it — you'll see a bolt icon (⚡) in your menu bar

### First Launch

When you first open Crackinate:

- A bolt icon appears in the menu bar
- The app is hidden from the Dock (menu bar only)
- Click the icon to open the popover

---

## Using Crackinate

### The Popover

Click the menu bar icon to open the control panel:

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

### Keep Screen Awake

Turn this **ON** to prevent your display from dimming or sleeping. Your Mac stays fully awake with the screen on. Perfect for:
- Watching long videos
- Reading documents
- Monitoring dashboards
- Presentations

### Prevent Lid Sleep

Turn this **ON** to prevent your Mac from sleeping when you close the lid. This requires a **one-time admin setup** — Crackinate will prompt you the first time you enable it.

⚠️ **Warning:** With lid-close prevention enabled, your Mac keeps running with the lid closed. Never put your Mac in a bag in this state — it can overheat and cause damage. Crackinate has thermal protection as a safety net, but it's not a guarantee.

### Timer

Instead of "Forever," you can set a time limit:

| Duration | Use case |
|----------|----------|
| **Forever** | Stay awake until manually turned off |
| **5 min** | Quick task, don't want to forget to turn off |
| **15 min** | Short presentation or video |
| **30 min** | Movie or meeting |
| **1 hr** | Extended work session |
| **2 hr** | Long presentation or download |

When the timer expires, Crackinate automatically turns off keep-awake and your Mac can sleep normally.

The countdown appears in the popover and the menu bar icon changes to an hourglass (⏳).

### Menu Bar Icon

The icon shows what Crackinate is doing:

| Icon | Meaning |
|------|---------|
| ☀️ Sun | Inactive — normal sleep behavior |
| 🖥 Display | Screen awake only |
| 🌙 Moon | Lid-close prevention only |
| ⚡ Bolt | Both modes active |
| ⏳ Hourglass | Timer countdown in progress |
| 🔥 Flame | Thermal warning — keep-awake disabled |

---

## Preferences

Open Preferences from the popover (⚙️ gear icon) or `Cmd+,`.

### General
- **Launch at Login** — Start Crackinate automatically when you log in. Also auto-restarts if it crashes.

### Keep Awake
- **Default Timer** — Which duration is selected by default in the popover.

### Display
- **Dim built-in display when lid closed** — When keep-awake is active and you close the lid, dims the built-in display to save power. Restores brightness when you open the lid. (Experimental feature.)

### Safety
- **Auto-disable on critical temperature** — If your Mac reaches dangerous temperatures, Crackinate automatically turns off all keep-awake modes. **Leave this ON.**
- **Warn when enabling lid-close on battery** — Shows a confirmation before enabling lid-close prevention when running on battery power. **Recommended.**

---

## Safety Features

### Thermal Protection

Your Mac monitors its own temperature. Crackinate watches this and acts:

| Temperature Level | What Happens |
|---|---|
| Normal / Fair | Nothing — keep-awake works normally |
| **Serious** | Notification: "Your Mac is getting hot. Consider disabling." |
| **Critical** | **All keep-awake modes force-disabled.** Critical alert shown. |

This is a hard safety net to prevent hardware damage. You can disable auto-disable in Settings → Safety, but it's not recommended.

### Battery Protection

When you try to enable lid-close prevention on battery power, Crackinate warns you that it will drain your battery quickly. You must confirm before it enables.

If AC power is lost while lid-close prevention is active, you'll get a notification.

### Safe Quit

- **Quitting** (Cmd+Q or menu → Quit) releases all assertions and resets sleep settings
- **Crashing** — the Launch at Login feature auto-restarts the app

---

## Uninstalling

To completely remove Crackinate:

1. Quit Crackinate from the menu or popover
2. Drag `Crackinate.app` to the Trash
3. If you set up lid-close prevention, remove the sudoers file:
   ```bash
   sudo rm /etc/sudoers.d/crackinate
   ```
4. Remove the LaunchAgent:
   ```bash
   rm ~/Library/LaunchAgents/com.crackinate.app.plist
   ```
5. Clear UserDefaults (optional):
   ```bash
   defaults delete com.crackinate.app
   ```

---

## Troubleshooting

### "Crackinate is damaged and can't be opened"

Right-click the app → Open, then click Open in the dialog. This bypasses Gatekeeper for unsigned apps.

### Lid-close toggle won't stay ON

You need to complete the one-time admin setup. When you toggle it ON, Crackinate should show a "Setup Required" dialog. If it doesn't appear, check:
- You have admin privileges on this Mac
- No other app is blocking the alert

### Two icons in the menu bar

This happens if you re-enable "Launch at Login" while Crackinate is already running. Quit both instances and restart — the single-instance guard will prevent duplicates.

### Settings window is behind other windows

The settings window should come to the front automatically. If it doesn't, click the Crackinate icon in the menu bar first to bring the app to the foreground.

---

## Keyboard Shortcuts

- **Cmd+,** — Open Preferences
- **Cmd+Q** — Quit (releases all keep-awake and resets sleep settings)
