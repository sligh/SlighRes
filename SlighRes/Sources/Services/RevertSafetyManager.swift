//
//  RevertSafetyManager.swift
//  SlighRes
//
//  After a resolution switch this manager shows a confirmation dialog
//  with a 10-second countdown.  If the user does not confirm, the
//  previous mode is restored automatically — ensuring the user is
//  never stranded on an unusable resolution.
//

import AppKit
import Foundation

/// Manages the post-switch "Keep / Revert" safety dialog.
///
/// Usage:
/// 1. Call `beginCountdown(displayID:previousMode:onComplete:)` after
///    a mode has been applied.
/// 2. The manager shows a modal `NSAlert` with a live countdown.
/// 3. If the user clicks **Keep** the completion is called with `true`.
/// 4. If the timer expires or the user clicks **Revert**, the previous
///    mode is restored and the completion is called with `false`.
final class RevertSafetyManager {

    // MARK: - Configuration

    /// Total seconds the user has to confirm the new resolution.
    static let countdownSeconds: Int = 10

    // MARK: - Internal State

    /// The mode to revert to if the user does not confirm.
    private var previousMode: DisplayMode?

    /// The display that was changed.
    private var displayID: CGDirectDisplayID?

    /// Timer driving the countdown.
    private var countdownTimer: Timer?

    /// Seconds remaining in the countdown.
    private var remainingSeconds: Int = 0

    /// Reference to the live alert so we can update its text.
    private var alert: NSAlert?

    // MARK: - Public API

    /// Begins the revert-safety countdown.
    ///
    /// This method **blocks** (via `NSAlert.runModal()`) until the user
    /// responds or the countdown expires.  Call it from the main thread
    /// inside a `DispatchQueue.main.asyncAfter` to allow the display
    /// to settle first.
    ///
    /// - Parameters:
    ///   - displayID: The display that was switched.
    ///   - previousMode: The mode to revert to on timeout.
    ///   - onComplete: Called with `true` if kept, `false` if reverted.
    func beginCountdown(
        displayID: CGDirectDisplayID,
        previousMode: DisplayMode,
        onComplete: @escaping (_ kept: Bool) -> Void
    ) {
        self.displayID        = displayID
        self.previousMode     = previousMode
        self.remainingSeconds = Self.countdownSeconds

        // Build the alert
        let alert = NSAlert()
        alert.messageText     = "Keep this resolution?"
        alert.informativeText = informativeText()
        alert.alertStyle      = .informational
        alert.addButton(withTitle: "Keep (\(remainingSeconds)s)")   // NSAlertFirstButtonReturn
        alert.addButton(withTitle: "Revert Now")                     // NSAlertSecondButtonReturn
        self.alert = alert

        // Bring the app to front so the alert is visible even if we're
        // a menu-bar-only (LSUIElement) app.
        NSApp.activate(ignoringOtherApps: true)

        // Start a repeating timer that ticks every second.
        countdownTimer = Timer.scheduledTimer(
            withTimeInterval: 1.0,
            repeats: true
        ) { [weak self] _ in
            self?.tick()
        }

        // Run the alert modally — this blocks until the user clicks or
        // we call `NSApp.abortModal()`.
        let response: NSApplication.ModalResponse = alert.runModal()

        // Clean up the timer in case the user clicked a button before expiry.
        countdownTimer?.invalidate()
        countdownTimer = nil

        if response == .alertFirstButtonReturn {
            // User clicked "Keep"
            onComplete(true)
        } else {
            // User clicked "Revert" or timer expired → restore previous mode
            revert()
            onComplete(false)
        }

        cleanup()
    }

    // MARK: - Private Helpers

    /// Called every second to decrement the countdown and update the alert.
    private func tick() {
        remainingSeconds -= 1

        if remainingSeconds <= 0 {
            // Time's up — dismiss the modal alert, triggering revert.
            countdownTimer?.invalidate()
            countdownTimer = nil
            NSApp.abortModal()
            return
        }

        // Update button title and informative text with remaining time.
        if let keepButton = alert?.buttons.first {
            keepButton.title = "Keep (\(remainingSeconds)s)"
        }
        alert?.informativeText = informativeText()
    }

    /// Generates the alert body text with the current countdown value.
    private func informativeText() -> String {
        "The display resolution has been changed. "
        + "If you can\u{2019}t see this dialog, the previous resolution "
        + "will be restored automatically in \(remainingSeconds) seconds."
    }

    /// Attempts to restore the previous display mode.
    private func revert() {
        guard let displayID, let previousMode else { return }
        do {
            try DisplayService.shared.applyMode(previousMode, to: displayID)
        } catch {
            NSLog("[SlighRes] Revert failed: \(error.localizedDescription)")
        }
    }

    /// Resets internal state after the flow completes.
    private func cleanup() {
        previousMode = nil
        displayID    = nil
        alert        = nil
    }
}
