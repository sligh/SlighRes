//
//  DisplayViewModel.swift
//  SlighRes
//
//  Central view-model that publishes display state and
//  orchestrates resolution switching with the safety-revert flow.
//

import Combine
import Foundation
import SwiftUI

/// Observable view-model powering the menu-bar UI.
///
/// Responsibilities:
/// - Maintains the list of connected displays and their modes.
/// - Triggers resolution switches via `DisplayService`.
/// - Coordinates the revert-safety countdown via `RevertSafetyManager`.
/// - Refreshes automatically when displays are connected/disconnected.
@Observable
final class DisplayViewModel {

    // MARK: - Published State

    /// All currently connected displays with their modes.
    var displays: [DisplayInfo] = []

    /// `true` while a switch + confirmation is in progress; disables UI.
    var isSwitching: Bool = false

    /// Last error message to surface in the UI (auto-clears on next switch).
    var lastError: String?

    // MARK: - Dependencies

    /// Shared low-level display service.
    private let displayService: DisplayService = .shared

    /// Manages the 10-second revert-safety dialog.
    private let revertManager: RevertSafetyManager = RevertSafetyManager()

    // MARK: - Lifecycle

    init() {
        refresh()
        // Re-query displays whenever macOS reports a configuration change.
        displayService.startMonitoring { [weak self] in
            self?.refresh()
        }
    }

    deinit {
        displayService.stopMonitoring()
    }

    // MARK: - Public Methods

    /// Re-reads all connected displays and their modes from CoreGraphics.
    func refresh() {
        displays = displayService.allDisplays()
    }

    /// Switches a display to the given mode, then runs the revert-safety flow.
    ///
    /// - Parameters:
    ///   - displayID: The display to change.
    ///   - mode: The target resolution mode.
    func switchResolution(displayID: CGDirectDisplayID, to mode: DisplayMode) {
        // Prevent concurrent switches.
        guard !isSwitching else { return }

        // Determine the current mode so we can revert if needed.
        guard let display = displays.first(where: { $0.id == displayID }),
              let currentMode: DisplayMode = display.currentMode else {
            lastError = "Could not determine current mode for display."
            return
        }

        // No-op if already on the requested mode.
        guard currentMode.id != mode.id else { return }

        isSwitching = true
        lastError   = nil

        // Apply the new mode immediately.
        do {
            try displayService.applyMode(mode, to: displayID)
        } catch {
            lastError   = error.localizedDescription
            isSwitching = false
            return
        }

        // After a short delay (to let the display settle), show the
        // "Keep / Revert" safety dialog.
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
                    // Revert is intentional, not an error.
                    self.lastError = nil
                }
            }
        }
    }
}
