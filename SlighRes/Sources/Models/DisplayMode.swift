//
//  DisplayMode.swift
//  SlighRes
//
//  A single display resolution mode.
//

import CoreGraphics
import Foundation

/// Represents one usable display resolution mode.
struct DisplayMode: Identifiable, Hashable {
    /// CoreGraphics mode number (unique per display).
    let id: Int32
    /// Pixel width.
    let width: Int
    /// Pixel height.
    let height: Int
    /// Scaling factor: 2 = HiDPI / Retina, 1 = standard.
    let scale: Int
    /// The underlying `CGDisplayMode` reference kept alive for applying.
    let cgMode: CGDisplayMode

    // MARK: - Computed

    /// Logical ("looks like") width = width / scale.
    var logicalWidth: Int { width / max(scale, 1) }
    /// Logical ("looks like") height = height / max(scale, 1).
    var logicalHeight: Int { height / max(scale, 1) }
    /// Human-readable label, e.g. "1920 × 1080 (HiDPI)".
    var label: String {
        let suffix = scale >= 2 ? "  (HiDPI)" : ""
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

// MARK: - Convenience init from CGDisplayMode

extension DisplayMode {
    init?(cgMode: CGDisplayMode) {
        guard cgMode.isUsableForDesktopGUI else { return nil }
        let w = cgMode.width
        let h = cgMode.height
        let pw = cgMode.pixelWidth
        let scale = (pw > 0 && w > 0) ? (pw / w) : 1

        self.id = cgMode.ioDisplayModeID
        self.width = pw
        self.height = cgMode.pixelHeight
        self.scale = scale
        self.cgMode = cgMode
    }
}
