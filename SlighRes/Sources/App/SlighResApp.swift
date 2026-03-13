//
//  SlighResApp.swift
//  SlighRes
//
//  App entry point — menu-bar-only application.
//

import SwiftUI

@main
struct SlighResApp: App {
    @State private var viewModel = DisplayViewModel()

    var body: some Scene {
        // Menu bar icon + dropdown
        MenuBarExtra("SlighRes", systemImage: "display") {
            MenuBarView(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)

        // Settings window (opened via SettingsLink)
        Settings {
            SettingsView()
        }
    }
}
