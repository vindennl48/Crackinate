import SwiftUI

/// Main popover view — the primary interaction panel.
struct PopoverView: View {
    @AppStorage(SettingsKeys.screenAwakeEnabled) private var screenAwakeEnabled = false
    @AppStorage(SettingsKeys.lidSleepDisabled) private var lidSleepDisabled = false
    @AppStorage(SettingsKeys.timerDuration) private var timerDurationRaw = 0

    @State private var timerRemaining: TimeInterval?
    @State private var isTimerActive = false
    @State private var selectedDuration: TimerDuration = .forever

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerView
            Divider()
            togglesSection

            if screenAwakeEnabled || lidSleepDisabled {
                Divider()
                timerSection
            }

            Divider()
            bottomActions
        }
        .frame(width: 280)
        .padding(.bottom, 12)
        .onAppear(perform: syncState)
        .onReceive(
            Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
        ) { _ in
            timerRemaining = TimerManager.shared.remainingTime
            isTimerActive = TimerManager.shared.isTimerActive
        }
        .onChange(of: isTimerActive) { _, active in
            if !active {
                resetToDefaultDuration()
            }
        }
        .onChange(of: timerDurationRaw) { _, _ in
            // Settings default changed — update picker if no timer is running
            if !isTimerActive {
                resetToDefaultDuration()
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Image(systemName: iconName)
                .font(.title2)
                .foregroundStyle(iconColor)
            Text("Crackinate")
                .font(.headline)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 12)
    }

    private var iconName: String {
        if screenAwakeEnabled && lidSleepDisabled { return "bolt.shield.fill" }
        if screenAwakeEnabled { return "display" }
        if lidSleepDisabled { return "moon.zzz.fill" }
        return "sun.max"
    }

    private var iconColor: Color {
        if screenAwakeEnabled && lidSleepDisabled { return .yellow }
        if screenAwakeEnabled { return .blue }
        if lidSleepDisabled { return .indigo }
        return .secondary
    }

    // MARK: - Toggles

    private var togglesSection: some View {
        VStack(spacing: 6) {
            ToggleRow(
                title: "Keep Screen Awake",
                icon: "display",
                isOn: $screenAwakeEnabled
            )
            .onChange(of: screenAwakeEnabled) { _, newValue in
                handleScreenToggle(newValue)
            }

            ToggleRow(
                title: "Prevent Lid Sleep",
                icon: "laptopcomputer",
                isOn: lidToggleBinding
            )
        }
        .padding(.horizontal)
    }

    /// Custom binding for the lid toggle that intercepts the ON action
    /// to show the sudoers setup alert and battery warning before committing.
    private var lidToggleBinding: Binding<Bool> {
        Binding(
            get: { lidSleepDisabled },
            set: { newValue in
                if newValue {
                    handleLidEnableRequest()
                } else {
                    lidSleepDisabled = false
                    KeepAwakeManager.shared.disableLidClosePrevention()
                }
            }
        )
    }

    /// Full enable-request pipeline: battery warning → sudoers check → enable.
    /// Set `skipBatteryCheck` to true after the user has already confirmed the battery warning.
    private func handleLidEnableRequest(skipBatteryCheck: Bool = false) {
        // 1. Battery warning (skip if user already confirmed)
        if !skipBatteryCheck,
           PersistenceManager.shared.warnOnBatteryLidClosed,
           !PowerMonitor.shared.isOnACPower {
            DispatchQueue.main.async {
                self.showBatteryWarningForLidClose()
            }
            lidSleepDisabled = true
            return
        }

        // 2. Sudoers check
        if !SudoersInstaller.shared.isInstalled() {
            DispatchQueue.main.async {
                self.handleLidEnableWithSetup()
            }
            lidSleepDisabled = true
            return
        }

        // 3. All checks passed — enable
        lidSleepDisabled = true
        let duration: TimeInterval? = (selectedDuration == .forever)
            ? nil : TimeInterval(selectedDuration.rawValue)
        KeepAwakeManager.shared.enableLidClosePrevention(duration: duration)
    }

    /// Battery warning: shows a confirmation dialog before enabling
    /// lid-close prevention on battery power. Reverts toggle if cancelled.
    private func showBatteryWarningForLidClose() {
        let alert = NSAlert()
        alert.messageText = "On Battery Power"
        alert.informativeText = "Lid-close sleep prevention on battery will drain your battery quickly.\n\nContinue?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Continue")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            // User confirmed — proceed past battery check to sudoers check
            handleLidEnableRequest(skipBatteryCheck: true)
        } else {
            // User cancelled — revert toggle
            lidSleepDisabled = false
        }
    }

    private func handleScreenToggle(_ enable: Bool) {
        if enable {
            let duration: TimeInterval? = (selectedDuration == .forever)
                ? nil : TimeInterval(selectedDuration.rawValue)
            KeepAwakeManager.shared.enableScreenAwake(duration: duration)
        } else {
            KeepAwakeManager.shared.disableScreenAwake()
        }
    }

    /// Shows sudoers setup alert. If user installs, keeps toggle ON and enables.
    /// If user cancels, reverts toggle OFF.
    private func handleLidEnableWithSetup() {
        let alert = NSAlert()
        alert.messageText = "Setup Required"
        alert.informativeText = "Lid-close sleep prevention needs a one-time admin setup to avoid asking for your password every time.\n\nSet this up now?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Set Up")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            do {
                try SudoersInstaller.shared.install()
                lidSleepDisabled = true
                let duration: TimeInterval? = (selectedDuration == .forever)
                    ? nil : TimeInterval(selectedDuration.rawValue)
                KeepAwakeManager.shared.enableLidClosePrevention(duration: duration)
            } catch {
                lidSleepDisabled = false
                let errorAlert = NSAlert()
                errorAlert.messageText = "Setup Failed"
                errorAlert.informativeText = error.localizedDescription
                errorAlert.alertStyle = .critical
                errorAlert.runModal()
            }
        } else {
            lidSleepDisabled = false
        }
    }

    // MARK: - Timer Section

    private var timerSection: some View {
        VStack(spacing: 8) {
            if !isTimerActive {
                TimerPicker(selectedDuration: $selectedDuration)
                    .padding(.horizontal)
            }
            if isTimerActive, let remaining = timerRemaining {
                CountdownDisplay(remainingTime: remaining, onStop: stopTimer)
                    .padding(.horizontal)
            }
        }
        .onChange(of: selectedDuration) { _, newDuration in
            applyDurationToActiveToggles(newDuration)
        }
    }

    /// When the user changes the timer picker while a toggle is already ON,
    /// restart that toggle with the new duration.
    private func applyDurationToActiveToggles(_ duration: TimerDuration) {
        let interval: TimeInterval? = (duration == .forever)
            ? nil : TimeInterval(duration.rawValue)

        if KeepAwakeManager.shared.isScreenAwakeActive {
            KeepAwakeManager.shared.enableScreenAwake(duration: interval)
        }
        if KeepAwakeManager.shared.isLidClosePreventionActive {
            // Don't show battery/sudoers alerts again — user already approved
            KeepAwakeManager.shared.enableLidClosePrevention(duration: interval)
        }
    }

    private func stopTimer() {
        KeepAwakeManager.shared.disableAll()
        screenAwakeEnabled = false
        lidSleepDisabled = false
        resetToDefaultDuration()
    }

    /// Reset the timer picker to the user's default from Settings.
    private func resetToDefaultDuration() {
        let defaultSeconds = PersistenceManager.shared.timerDuration
        if defaultSeconds > 0, let dur = TimerDuration(rawValue: defaultSeconds) {
            selectedDuration = dur
        } else {
            selectedDuration = .forever
        }
    }

    // MARK: - Bottom

    private var bottomActions: some View {
        VStack(spacing: 4) {
            if #available(macOS 14.0, *) {
                SettingsLink {
                    Label("Preferences...", systemImage: "gearshape")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            } else {
                Button(action: openPreferences) {
                    Label("Preferences...", systemImage: "gearshape")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }

            Button(action: quitApp) {
                Label("Quit Crackinate", systemImage: "xmark.circle")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
    }

    // MARK: - Actions

    private func syncState() {
        screenAwakeEnabled = KeepAwakeManager.shared.isScreenAwakeActive
        lidSleepDisabled = KeepAwakeManager.shared.isLidClosePreventionActive
        isTimerActive = TimerManager.shared.isTimerActive
        timerRemaining = TimerManager.shared.remainingTime
        timerDurationRaw = PersistenceManager.shared.timerDuration
        if timerDurationRaw > 0, let dur = TimerDuration(rawValue: timerDurationRaw) {
            selectedDuration = dur
        }
    }

    private func openPreferences() {
        // SettingsLink opens the SwiftUI Settings scene directly.
        // Use the AppKit action as fallback.
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak app = NSApp] in
            guard let app else { return }
            let sel = Selector(("showSettingsWindow:"))
            if app.responds(to: sel) {
                app.perform(sel, with: nil)
            }
        }
    }

    private func quitApp() {
        KeepAwakeManager.shared.disableAll()
        NSApp.terminate(nil)
    }
}
