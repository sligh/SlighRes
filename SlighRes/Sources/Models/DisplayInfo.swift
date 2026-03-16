//
//  DisplayInfo.swift
//  SlighRes
//
//  Model for a single connected display and its available modes.
//

import CoreGraphics
import Foundation

/// Describes a connected display including its identity, current mode,
/// and the full list of available resolution modes.
///
/// Conforms to `Identifiable` using the `CGDirectDisplayID`.
struct DisplayInfo: Identifiable {

    /// `CGDirectDisplayID` — unique system identifier for this display.
    let id: CGDirectDisplayID

    /// Human-readable display name, e.g. "LG HDR 4K" or "Built-in Retina Display".
    let name: String

    /// Hardware serial number reported by IOKit (may be `0` for some panels).
    let serial: UInt32

    /// `true` when the display is the MacBook's built-in panel.
    let isBuiltIn: Bool

    /// The resolution mode currently active on this display, if determinable.
    var currentMode: DisplayMode?

    /// All recommended/usable modes, deduplicated and sorted descending by
    /// logical width.
    var modes: [DisplayMode]
}
