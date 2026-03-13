//
//  DisplayViewModel.swift
//  SlighRes
//
//  Central view-model that publishes display state and
//  orchestrates resolution switching with safety revert.
//

import Combine
import Foundation
import SwiftUI

@Observable
final class DisplayViewModel {

    // MARK: - Published State

    /// All currently connected displays with their modes.
    var displays: [DisplayInfo] = []

    /// True while a switch + confirmation is in progress.
    var isSwitching: Bool = false

    /// Last error message to surface in UI (auto-clears).
    var lastError: String?

    // MARK: - Dependencies

    private let displayService = DisplayService.shared
    private let revertManager = RevertSafetyManager()

    // MARK: - Init

    init() {
        refresh()
        displayService.startMonitoring { [weak self] in
            self?.refresh()
        }
    }

    deinit {
        displayService.stopMonitoring()
    }

    // MARK: - Public

    /// Refresh the display list from CoreGraphics.
    func refresh() {
        displays = displayService.allDisplays()
    }

    /// Switch a display to the given mode, triggering the revert-safety flow.
    func switchResolution(displayID: CGDirectDisplayID, to mode: DisplayMode) {
        guard !isSwitching else { return }

        guard let display = displays.first(where: { $0.id == displayID }),
              let currentMode = display.currentMode else {
            lastError = "Could not determine current mode for display."
            return
        }

        // Don't switch if already on this mode
        guard currentMode.id != mode.id else { return }

        isSwitching = true
        lastError = nil

        // Apply the new mode
        do {
            try displayService.applyMode(mode, to: displayID)
        } catch {
            lastError = error.localizedDescription
            isSwitching = false
            return
        }

        // Run revert-safety on a short delay so the display has
        // time to settle before the alert appears.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self else { return }
            self.revertManager.beginCountdown(
                displayID: displayID,
                previousMode: currentMode
            ) { [weak self] kept in
                guard let self else { return }
                self.isSwitching = false
                self.refresh()
                if !kept {
                    self.lastError = nil   // revert is not an error
                }
            }
        }
    }
}
