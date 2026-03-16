//
//  DisplayMode.swift
//  SlighRes
//
//  A single display resolution mode backed by a CoreGraphics `CGDisplayMode`.
//

import CoreGraphics
import Foundation

/// Represents one usable display resolution mode.
///
/// Each instance wraps a `CGDisplayMode` and exposes pixel dimensions,
/// logical (scaled) dimensions, and a human-readable label.  The struct
/// conforms to `Identifiable` (keyed by the CG mode number) and
/// `Hashable` so it can be used directly in SwiftUI `ForEach` views
/// and stored in sets.
struct DisplayMode: Identifiable, Hashable {

    // MARK: - Stored Properties

    /// CoreGraphics mode number — unique per display.
    let id: Int32

    /// Pixel width of the mode (physical pixels).
    let width: Int

    /// Pixel height of the mode (physical pixels).
    let height: Int

    /// Scaling factor: `2` = HiDPI / Retina, `1` = standard.
    let scale: Int

    /// The underlying `CGDisplayMode` reference, retained for applying.
    let cgMode: CGDisplayMode

    // MARK: - Computed Properties

    /// Logical ("looks like") width = `width / scale`.
    var logicalWidth: Int { width / max(scale, 1) }

    /// Logical ("looks like") height = `height / scale`.
    var logicalHeight: Int { height / max(scale, 1) }

    /// Whether this mode is HiDPI / Retina (`scale >= 2`).
    var isHiDPI: Bool { scale >= 2 }

    /// Human-readable label, e.g. `"1920 × 1080  (HiDPI)"`.
    var label: String {
        let suffix = isHiDPI ? "  (HiDPI)" : ""
        return "\(logicalWidth) × \(logicalHeight)\(suffix)"
    }

    // MARK: - Hashable / Equatable

    static func == (lhs: DisplayMode, rhs: DisplayMode) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Convenience Initialiser from CGDisplayMode

extension DisplayMode {

    /// Failable initialiser that extracts dimensions and scale from
    /// a `CGDisplayMode`.
    ///
    /// Returns `nil` if the mode is not flagged as usable for the
    /// desktop GUI (e.g. TV-only modes).
    ///
    /// - Parameter cgMode: The CoreGraphics display mode to wrap.
    init?(cgMode: CGDisplayMode) {
        guard cgMode.isUsableForDesktopGUI() else { return nil }

        let logicalWidth: Int = cgMode.width
        let pixelWidth: Int   = cgMode.pixelWidth
        // Derive scale: pixel-width / logical-width; fallback to 1.
        let derivedScale: Int = (pixelWidth > 0 && logicalWidth > 0)
            ? (pixelWidth / logicalWidth)
            : 1

        self.id     = cgMode.ioDisplayModeID
        self.width  = pixelWidth
        self.height = cgMode.pixelHeight
        self.scale  = derivedScale
        self.cgMode = cgMode
    }
}
