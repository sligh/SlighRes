//
//  DisplayService.swift
//  SlighRes
//
//  Stateless service that wraps CoreGraphics / Quartz Display Services
//  for enumerating displays, querying modes, applying resolution changes,
//  and monitoring hotplug events.
//

import CoreGraphics
import Foundation
import IOKit

// MARK: - DisplayService

/// Singleton service providing all low-level display operations.
///
/// All public methods are safe to call from the main thread.  Heavy
/// CoreGraphics work (mode enumeration, IOKit name lookup) is synchronous
/// but typically completes in < 1 ms per display.
final class DisplayService {

    // MARK: Singleton

    /// Shared instance — use this instead of creating new instances.
    static let shared = DisplayService()
    private init() {}

    // MARK: - Display Enumeration

    /// Returns the IDs of all currently active (connected and powered-on) displays.
    ///
    /// - Returns: An array of `CGDirectDisplayID` values.
    func connectedDisplayIDs() -> [CGDirectDisplayID] {
        var displayCount: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &displayCount)
        guard displayCount > 0 else { return [] }

        var ids = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        CGGetActiveDisplayList(displayCount, &ids, &displayCount)
        return Array(ids.prefix(Int(displayCount)))
    }

    /// Builds a full `DisplayInfo` model for a single display.
    ///
    /// - Parameter displayID: The CoreGraphics display identifier.
    /// - Returns: A populated `DisplayInfo` struct.
    func displayInfo(for displayID: CGDirectDisplayID) -> DisplayInfo {
        let name: String         = displayName(for: displayID)
        let serial: UInt32       = CGDisplaySerialNumber(displayID)
        let builtIn: Bool        = CGDisplayIsBuiltin(displayID) != 0
        let current: DisplayMode? = currentMode(for: displayID)
        let modes: [DisplayMode] = availableModes(for: displayID)

        return DisplayInfo(
            id: displayID,
            name: name,
            serial: serial,
            isBuiltIn: builtIn,
            currentMode: current,
            modes: modes
        )
    }

    /// Convenience: all connected displays as `DisplayInfo` models.
    ///
    /// - Returns: Array of `DisplayInfo`, one per active display.
    func allDisplays() -> [DisplayInfo] {
        connectedDisplayIDs().map { displayInfo(for: $0) }
    }

    // MARK: - Mode Queries

    /// Returns the resolution mode currently active on the given display.
    ///
    /// - Parameter displayID: The target display.
    /// - Returns: The active `DisplayMode`, or `nil` if it cannot be determined.
    func currentMode(for displayID: CGDirectDisplayID) -> DisplayMode? {
        guard let cg = CGDisplayCopyDisplayMode(displayID) else { return nil }
        return DisplayMode(cgMode: cg)
    }

    /// All usable modes for a display, deduplicated by
    /// `(logicalWidth, logicalHeight, scale)` and sorted descending.
    ///
    /// Includes both HiDPI and non-HiDPI modes. Filtering by preference
    /// is done at the view layer.
    ///
    /// - Parameter displayID: The target display.
    /// - Returns: Sorted, deduplicated array of `DisplayMode`.
    func availableModes(for displayID: CGDirectDisplayID) -> [DisplayMode] {
        // Request all modes including low-res duplicates so we can
        // deduplicate ourselves.
        let options: CFDictionary = [
            kCGDisplayShowDuplicateLowResolutionModes: kCFBooleanTrue!
        ] as CFDictionary

        guard let cgModes = CGDisplayCopyAllDisplayModes(displayID, options) as? [CGDisplayMode] else {
            return []
        }

        var seen = Set<String>()
        var result = [DisplayMode]()

        for cg in cgModes {
            guard let mode = DisplayMode(cgMode: cg) else { continue }
            // Dedup key: logical dimensions + scale
            let key: String = "\(mode.logicalWidth)x\(mode.logicalHeight)x\(mode.scale)"
            guard seen.insert(key).inserted else { continue }
            result.append(mode)
        }

        // Sort: largest logical width first, then height, then prefer HiDPI.
        result.sort {
            if $0.logicalWidth  != $1.logicalWidth  { return $0.logicalWidth  > $1.logicalWidth  }
            if $0.logicalHeight != $1.logicalHeight { return $0.logicalHeight > $1.logicalHeight }
            return $0.scale > $1.scale
        }

        return result
    }

    // MARK: - Apply Mode

    /// Errors that can occur during a display mode switch.
    enum SwitchError: LocalizedError {
        case configurationFailed(CGError)
        case modeSwitchFailed(CGError)
        case completeFailed(CGError)

        var errorDescription: String? {
            switch self {
            case .configurationFailed(let e):
                return "Failed to begin display configuration (CGError \(e.rawValue))."
            case .modeSwitchFailed(let e):
                return "Failed to set display mode (CGError \(e.rawValue))."
            case .completeFailed(let e):
                return "Failed to complete configuration (CGError \(e.rawValue))."
            }
        }
    }

    /// Applies a resolution mode to a display.
    ///
    /// Uses `CGBeginDisplayConfiguration` / `CGCompleteDisplayConfiguration`
    /// for atomic switching.  The change persists for the current login session.
    ///
    /// - Parameters:
    ///   - mode: The target `DisplayMode` to apply.
    ///   - displayID: The display to reconfigure.
    /// - Throws: `SwitchError` on failure at any stage.
    func applyMode(_ mode: DisplayMode, to displayID: CGDirectDisplayID) throws {
        var config: CGDisplayConfigRef?

        let beginErr: CGError = CGBeginDisplayConfiguration(&config)
        guard beginErr == .success, let config else {
            throw SwitchError.configurationFailed(beginErr)
        }

        let setErr: CGError = CGConfigureDisplayWithDisplayMode(config, displayID, mode.cgMode, nil)
        guard setErr == .success else {
            CGCancelDisplayConfiguration(config)
            throw SwitchError.modeSwitchFailed(setErr)
        }

        let completeErr: CGError = CGCompleteDisplayConfiguration(config, .forSession)
        guard completeErr == .success else {
            throw SwitchError.completeFailed(completeErr)
        }
    }

    // MARK: - Display Name via IOKit

    /// Reads the localised product name from IOKit's display registry.
    ///
    /// Falls back to "Built-in Display" or "Display (vendor-model)" when
    /// IOKit lookup fails.
    ///
    /// - Parameter displayID: The target display.
    /// - Returns: A human-readable display name.
    func displayName(for displayID: CGDirectDisplayID) -> String {
        var iter: io_iterator_t = 0
        let matching: CFDictionary? = IOServiceMatching("IODisplayConnect")

        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iter) == KERN_SUCCESS else {
            return fallbackName(for: displayID)
        }
        defer { IOObjectRelease(iter) }

        var serv: io_service_t = IOIteratorNext(iter)
        while serv != 0 {
            defer { IOObjectRelease(serv); serv = IOIteratorNext(iter) }

            guard let info = IODisplayCreateInfoDictionary(
                serv,
                UInt32(kIODisplayOnlyPreferredName)
            ).takeRetainedValue() as? [String: Any],
                  let vendorID  = info[kDisplayVendorID]  as? UInt32,
                  let productID = info[kDisplayProductID] as? UInt32
            else { continue }

            // Match by vendor + product to find the correct display
            if vendorID == CGDisplayVendorNumber(displayID),
               productID == CGDisplayModelNumber(displayID) {
                if let names = info[kDisplayProductName] as? [String: String],
                   let name = names.values.first, !name.isEmpty {
                    return name
                }
            }
        }

        return fallbackName(for: displayID)
    }

    /// Generates a fallback display name when IOKit lookup fails.
    private func fallbackName(for displayID: CGDirectDisplayID) -> String {
        if CGDisplayIsBuiltin(displayID) != 0 {
            return "Built-in Display"
        }
        let vendor: UInt32 = CGDisplayVendorNumber(displayID)
        let model: UInt32  = CGDisplayModelNumber(displayID)
        return "Display (\(vendor)-\(model))"
    }

    // MARK: - Hotplug Monitoring

    /// Stored callback reference (prevents premature deallocation).
    private var reconfigCallback: CGDisplayReconfigurationCallBack?

    /// User-supplied handler called after any display reconfiguration.
    private var changeHandler: (() -> Void)?

    /// Registers for display connect/disconnect/mode-change notifications.
    ///
    /// The `onChange` closure is dispatched on the **main queue**.
    ///
    /// - Parameter onChange: Called each time a reconfiguration completes.
    func startMonitoring(onChange: @escaping () -> Void) {
        changeHandler = onChange

        let callback: CGDisplayReconfigurationCallBack = { _, flags, _ in
            // Fire only once the reconfiguration is complete (not at begin).
            guard !flags.contains(.beginConfigurationFlag) else { return }
            DispatchQueue.main.async {
                DisplayService.shared.changeHandler?()
            }
        }
        reconfigCallback = callback
        CGDisplayRegisterReconfigurationCallback(callback, nil)
    }

    /// Removes the reconfiguration callback.
    func stopMonitoring() {
        if let cb = reconfigCallback {
            CGDisplayRemoveReconfigurationCallback(cb, nil)
            reconfigCallback = nil
        }
        changeHandler = nil
    }
}
