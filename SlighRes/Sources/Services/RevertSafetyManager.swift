//
//  RevertSafetyManager.swift
//  SlighRes
//
//  After a resolution switch this manager shows a confirmation dialog
//  with a 10-second countdown.  If the user does not confirm, the
//  previous mode is restored automatically.
//

import AppKit
import Foundation

final class RevertSafetyManager {

    // MARK: - Configuration

    /// Total seconds the user has to confirm.
    static let countdownSeconds = 10

    // MARK: - State

    private var previousMode: DisplayMode?
    private var displayID: CGDirectDisplayID?
    private var countdownTimer: Timer?
    private var remainingSeconds: Int = 0
    private var alert: NSAlert?

    // MARK: - Public

    /// Begin the revert-safety flow.
    ///
    /// - Parameters:
    ///   - displayID: The display that was changed.
    ///   - previousMode: The mode to revert to if the user does not confirm.
    ///   - onComplete: Called with `true` if the user confirmed, `false` if reverted.
    func beginCountdown(
        displayID: CGDirectDisplayID,
        previousMode: DisplayMode,
        onComplete: @escaping (Bool) -> Void
    ) {
        self.displayID = displayID
        self.previousMode = previousMode
        self.remainingSeconds = Self.countdownSeconds

        // Build alert
        let alert = NSAlert()
        alert.messageText = "Keep this resolution?"
        alert.informativeText = informativeText()
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Keep (\(remainingSeconds)s)")      // index 1000
        alert.addButton(withTitle: "Revert Now")                        // index 1001
        self.alert = alert

        // Bring our app to front so the alert is visible
        NSApp.activate(ignoringOtherApps: true)

        // Start countdown timer — updates the button title every second
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick(onComplete: onComplete)
        }

        // Run modal (blocks this call until user clicks or we abort)
        let response = alert.runModal()

        // Timer may still be alive if user clicked a button
        countdownTimer?.invalidate()
        countdownTimer = nil

        if response == .alertFirstButtonReturn {
            // User clicked "Keep"
            onComplete(true)
        } else {
            // User clicked "Revert" or timer expired -> revert
            revert()
            onComplete(false)
        }

        cleanup()
    }

    // MARK: - Private

    private func tick(onComplete: @escaping (Bool) -> Void) {
        remainingSeconds -= 1

        if remainingSeconds <= 0 {
            // Time's up — dismiss the alert and revert
            countdownTimer?.invalidate()
            countdownTimer = nil
            NSApp.abortModal()
            return
        }

        // Update the Keep button title with remaining seconds
        if let keepButton = alert?.buttons.first {
            keepButton.title = "Keep (\(remainingSeconds)s)"
        }
        alert?.informativeText = informativeText()
    }

    private func informativeText() -> String {
        "The display resolution has been changed. " +
        "If you can\u2019t see this dialog, the previous resolution " +
        "will be restored automatically in \(remainingSeconds) seconds."
    }

    private func revert() {
        guard let displayID, let previousMode else { return }
        do {
            try DisplayService.shared.applyMode(previousMode, to: displayID)
        } catch {
            NSLog("[SlighRes] Revert failed: \(error.localizedDescription)")
        }
    }

    private func cleanup() {
        previousMode = nil
        displayID = nil
        alert = nil
    }
}
