//
//  DisplayInfo.swift
//  SlighRes
//
//  Describes one connected display with its available modes.
//

import CoreGraphics
import Foundation

/// Model for a single connected display.
struct DisplayInfo: Identifiable {
    /// `CGDirectDisplayID` doubles as unique identifier.
    let id: CGDirectDisplayID
    /// Human-readable name, e.g. "LG HDR 4K" or "Built-in Retina Display".
    let name: String
    /// Hardware serial number (may be 0 for some displays).
    let serial: UInt32
    /// `true` for the MacBook’s built-in panel.
    let isBuiltIn: Bool
    /// Currently active mode.
    var currentMode: DisplayMode?
    /// All recommended/usable modes, deduplicated and sorted.
    var modes: [DisplayMode]
}
