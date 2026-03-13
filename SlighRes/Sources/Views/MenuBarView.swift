//
//  MenuBarView.swift
//  SlighRes
//
//  Root view rendered inside the MenuBarExtra popover / menu.
//

import SwiftUI

struct MenuBarView: View {
    @Bindable var viewModel: DisplayViewModel

    var body: some View {
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
                        isSwitching: viewModel.isSwitching
                    ) { mode in
                        viewModel.switchResolution(displayID: display.id, to: mode)
                    }
                }
            }

            Divider().padding(.vertical, 4)

            // Footer
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

            // Settings & Quit
            HStack {
                SettingsLink {
                    Text("Settings\u2026")
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

struct DisplaySectionView: View {
    let display: DisplayInfo
    let isSwitching: Bool
    let onSelect: (DisplayMode) -> Void

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
            ForEach(display.modes) { mode in
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

// MARK: - Resolution Row

struct ResolutionRowView: View {
    let mode: DisplayMode
    let isCurrent: Bool
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                if isCurrent {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundStyle(.accent)
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
