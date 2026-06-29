import SwiftUI

/// Preferences/settings window with tabbed layout.
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralTab()
                .tabItem { Label("General", systemImage: "gearshape") }

            KeepAwakeTab()
                .tabItem { Label("Keep Awake", systemImage: "bolt.fill") }

            DisplayTab()
                .tabItem { Label("Display", systemImage: "display") }

            SafetyTab()
                .tabItem { Label("Safety", systemImage: "shield.checkered") }

            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 450, height: 320)
        .onAppear {
            bringToFront()
        }
    }

    /// Ensure the settings window is visible, not buried behind other apps.
    private func bringToFront() {
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let window = NSApp.windows.first(where: {
                $0.contentView?.subviews.contains(where: { $0 is NSHostingView<SettingsView> }) ?? false
            }) ?? NSApp.keyWindow {
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
            }
        }
    }
}

// MARK: - General Tab

private struct GeneralTab: View {
    @AppStorage(SettingsKeys.launchAtLogin) private var launchAtLogin = false

    var body: some View {
        Form {
            Toggle("Launch at Login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    if newValue {
                        do {
                            try LaunchAgentManager.shared.enableAll()
                        } catch {
                            launchAtLogin = false
                            print("[Crackinate] Launch at login failed: \(error)")
                        }
                    } else {
                        LaunchAgentManager.shared.disableAll()
                    }
                }

            Text("Automatically start Crackinate when you log in, and restart if it crashes.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
    }
}

// MARK: - Keep Awake Tab

private struct KeepAwakeTab: View {
    @AppStorage(SettingsKeys.timerDuration) private var timerDuration = 0

    var body: some View {
        Form {
            Picker("Default Timer", selection: $timerDuration) {
                Text("Forever").tag(0)
                Text("5 minutes").tag(300)
                Text("15 minutes").tag(900)
                Text("30 minutes").tag(1800)
                Text("1 hour").tag(3600)
                Text("2 hours").tag(7200)
            }

            Text("Default duration for keep-awake when enabled from the popover.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
    }
}

// MARK: - Display Tab

private struct DisplayTab: View {
    @AppStorage(SettingsKeys.dimDisplayWhenLidClosed) private var dimDisplayWhenLidClosed = false

    var body: some View {
        Form {
            Toggle("Dim built-in display when lid closed", isOn: $dimDisplayWhenLidClosed)

            Text("When keep-awake is active and the lid closes, dim the built-in display to save power and reduce heat. Brightness restores when the lid opens.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
    }
}

// MARK: - Safety Tab

private struct SafetyTab: View {
    @AppStorage(SettingsKeys.autoDisableOnThermal) private var autoDisableOnThermal = true
    @AppStorage(SettingsKeys.warnOnBatteryLidClosed) private var warnOnBatteryLidClosed = true

    var body: some View {
        Form {
            Toggle("Auto-disable on critical temperature", isOn: $autoDisableOnThermal)

            Text("If your Mac reaches critical temperature, Crackinate will automatically disable all keep-awake modes to prevent overheating.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            Toggle("Warn when enabling lid-close on battery", isOn: $warnOnBatteryLidClosed)

            Text("Shows a confirmation dialog before enabling lid-close sleep prevention when running on battery power.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
    }
}

// MARK: - About Tab

private struct AboutTab: View {
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "bolt.shield.fill")
                .font(.system(size: 56))
                .foregroundStyle(.yellow)

            Text("Crackinate")
                .font(.title)
                .fontWeight(.semibold)

            Text("Version \(version) (\(build))")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Prevents screen sleep and lid-close sleep on macOS.\nNot for distribution — personal use only.")
                .multilineTextAlignment(.center)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
