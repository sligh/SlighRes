//
//  MenuBarView.swift
//  SlighRes
//
//  Root view rendered inside the MenuBarExtra popover / window.
//  Displays per-display resolution sections with optional HiDPI filtering,
//  scrollable overflow, and quick access to Preferences and Quit.
//

import SwiftUI

// MARK: - MenuBarView

/// The main content view shown in the menu-bar popover.
struct MenuBarView: View {

    /// Shared view-model providing display state and switch actions.
    @Bindable var viewModel: DisplayViewModel

    /// User preference: when `true`, only HiDPI (Retina) modes are shown.
    @AppStorage("showHiDPIOnly") private var showHiDPIOnly: Bool = false

    // MARK: Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Resolution list (scrollable when content exceeds screen) ──
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    if viewModel.displays.isEmpty {
                        Text("No displays detected")
                            .foregroundStyle(.secondary)
                            .padding()
                    } else {
                        ForEach(Array(viewModel.displays.enumerated()), id: \.element.id) { index, display in
                            if index > 0 {
                                Divider().padding(.vertical, 4)
                            }
                            DisplaySectionView(
                                display: display,
                                isSwitching: viewModel.isSwitching,
                                showHiDPIOnly: showHiDPIOnly
                            ) { mode in
                                viewModel.switchResolution(displayID: display.id, to: mode)
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 500) // Prevent the menu from growing unbounded

            Divider().padding(.vertical, 4)

            // ── Footer: error + refresh ──
            HStack {
                if let error = viewModel.lastError {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()

                Button("Refresh") {
                    viewModel.refresh()
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            Divider()

            // ── Settings & Quit ──
            HStack {
                SettingsLink {
                    Text("Preferences\u{2026}")
                }
                .buttonStyle(.borderless)

                Spacer()

                Button("Quit SlighRes") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(minWidth: 280, maxWidth: 340)
    }
}

// MARK: - Display Section

/// Shows a single display's header and its list of resolution modes.
struct DisplaySectionView: View {

    /// The display whose modes are listed.
    let display: DisplayInfo

    /// Whether a resolution switch is currently in progress (disables buttons).
    let isSwitching: Bool

    /// When `true`, only modes with `scale >= 2` (HiDPI) are shown.
    let showHiDPIOnly: Bool

    /// Called when the user selects a mode.
    let onSelect: (DisplayMode) -> Void

    /// Modes filtered according to the HiDPI preference.
    private var filteredModes: [DisplayMode] {
        if showHiDPIOnly {
            return display.modes.filter { $0.scale >= 2 }
        }
        return display.modes
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Header
            HStack {
                Image(systemName: display.isBuiltIn ? "laptopcomputer" : "display")
                    .foregroundStyle(.secondary)
                Text(display.name)
                    .font(.headline)
                    .lineLimit(1)
                if display.serial != 0 {
                    Text("#\(display.serial)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)

            // Modes
            if filteredModes.isEmpty {
                Text("No matching modes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
            } else {
                ForEach(filteredModes) { mode in
                    ResolutionRowView(
                        mode: mode,
                        isCurrent: mode.id == display.currentMode?.id,
                        disabled: isSwitching
                    ) {
                        onSelect(mode)
                    }
                }
            }
        }
    }
}

// MARK: - Resolution Row

/// A single clickable resolution row with checkmark indicator and HiDPI badge.
struct ResolutionRowView: View {

    /// The display mode this row represents.
    let mode: DisplayMode

    /// Whether this mode is the currently active mode.
    let isCurrent: Bool

    /// Whether interaction is disabled (e.g. during a switch).
    let disabled: Bool

    /// Action invoked when the user clicks this row.
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                if isCurrent {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundStyle(.tint)
                } else {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .hidden()
                }

                Text(mode.label)
                    .foregroundStyle(isCurrent ? Color.accentColor : .primary)

                Spacer()

                if mode.scale >= 2 {
                    Image(systemName: "rectangle.on.rectangle")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .help("Retina / HiDPI")
                }
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
        .buttonStyle(.borderless)
        .disabled(disabled || isCurrent)
    }
}
