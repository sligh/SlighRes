//
//  SettingsView.swift
//  SlighRes
//
//  Preferences window for user-configurable options.
//

import SwiftUI

/// The Preferences (Settings) window content.
struct SettingsView: View {

    /// When `true`, only HiDPI / Retina modes appear in the resolution menu.
    @AppStorage("showHiDPIOnly") private var showHiDPIOnly: Bool = true

    /// When `true`, the app is registered as a login item.
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false

    var body: some View {
        Form {
            Section("Display") {
                Toggle("Show only HiDPI / Retina resolutions", isOn: $showHiDPIOnly)
                    .help("When enabled, non-Retina (1× scale) modes are hidden from the menu.")
            }

            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .help("Register SlighRes as a login item (requires macOS 13+).")
            }

            Section("About") {
                LabeledContent("Version", value: Bundle.main.appVersionString)
                LabeledContent("Author", value: "Personal Use")
                Text("SlighRes is a lightweight macOS menu-bar utility for switching display resolutions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 260)
    }
}

// MARK: - Bundle Extension

extension Bundle {
    /// Returns a human-readable version string, e.g. "1.0.0 (1)".
    var appVersionString: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
