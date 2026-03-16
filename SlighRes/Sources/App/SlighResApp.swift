//
//  SlighResApp.swift
//  SlighRes
//
//  App entry point — menu-bar-only application (LSUIElement = true).
//
//  Note on menu-bar icon visibility at low resolutions:
//  macOS does not expose a public API for controlling menu-bar item
//  priority or ordering.  Third-party `MenuBarExtra` items are placed
//  to the left of system status items and are hidden last when space
//  is constrained.  Using a compact SF Symbol ("display") helps ensure
//  the icon remains visible even at very low screen resolutions.
//

import SwiftUI

@main
struct SlighResApp: App {

    /// Central view-model shared across the menu-bar view.
    @State private var viewModel = DisplayViewModel()

    var body: some Scene {
        // Menu-bar icon + dropdown window
        MenuBarExtra("SlighRes", systemImage: "display") {
            MenuBarView(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)

        // Preferences window (opened via SettingsLink in the menu)
        Settings {
            SettingsView()
        }
    }
}
