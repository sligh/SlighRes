//
//  SettingsView.swift
//  SlighRes
//
//  Minimal Settings window.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("showHiDPIOnly") private var showHiDPIOnly = false
    @AppStorage("launchAtLogin") private var launchAtLogin = false

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .help("Register as a login item (requires macOS 13+).")

                Toggle("Show HiDPI modes only", isOn: $showHiDPIOnly)
                    .help("Hide non-Retina modes from the menu.")
            }

            Section("About") {
                LabeledContent("Version", value: Bundle.main.appVersionString)
                LabeledContent("Author", value: "Personal Use")
                Text("SlighRes is a lightweight resolution switcher for macOS.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 360, height: 240)
    }
}

// MARK: - Bundle Extension

extension Bundle {
    var appVersionString: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
