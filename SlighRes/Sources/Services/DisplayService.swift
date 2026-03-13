//
//  DisplayService.swift
//  SlighRes
//
//  Wraps CoreGraphics / Quartz Display Services for enumerating
//  displays, reading modes, and applying resolution changes.
//

import CoreGraphics
import Foundation
import IOKit

// MARK: - Public API

final class DisplayService {

    // MARK: Singleton (stateless helper, one callback registration)

    static let shared = DisplayService()
    private init() {}

    // MARK: - Display Enumeration

    /// Returns all currently-active display IDs.
    func connectedDisplayIDs() -> [CGDirectDisplayID] {
        var displayCount: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &displayCount)
        guard displayCount > 0 else { return [] }

        var ids = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        CGGetActiveDisplayList(displayCount, &ids, &displayCount)
        return Array(ids.prefix(Int(displayCount)))
    }

    /// Build a full `DisplayInfo` for a given display ID.
    func displayInfo(for displayID: CGDirectDisplayID) -> DisplayInfo {
        let name = displayName(for: displayID)
        let serial = CGDisplaySerialNumber(displayID)
        let builtIn = CGDisplayIsBuiltin(displayID) != 0
        let current = currentMode(for: displayID)
        let modes = availableModes(for: displayID)

        return DisplayInfo(
            id: displayID,
            name: name,
            serial: serial,
            isBuiltIn: builtIn,
            currentMode: current,
            modes: modes
        )
    }

    /// All connected displays as `DisplayInfo` models.
    func allDisplays() -> [DisplayInfo] {
        connectedDisplayIDs().map { displayInfo(for: $0) }
    }

    // MARK: - Mode Queries

    /// The mode currently active on a display.
    func currentMode(for displayID: CGDirectDisplayID) -> DisplayMode? {
        guard let cg = CGDisplayCopyDisplayMode(displayID) else { return nil }
        return DisplayMode(cgMode: cg)
    }

    /// All usable modes, deduplicated by (logicalWidth, logicalHeight, scale),
    /// sorted descending by logical width then height.
    func availableModes(for displayID: CGDirectDisplayID) -> [DisplayMode] {
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
            let key = "\(mode.logicalWidth)x\(mode.logicalHeight)x\(mode.scale)"
            guard seen.insert(key).inserted else { continue }
            result.append(mode)
        }

        result.sort {
            if $0.logicalWidth != $1.logicalWidth { return $0.logicalWidth > $1.logicalWidth }
            if $0.logicalHeight != $1.logicalHeight { return $0.logicalHeight > $1.logicalHeight }
            return $0.scale > $1.scale
        }

        return result
    }

    // MARK: - Apply Mode

    enum SwitchError: LocalizedError {
        case configurationFailed(CGError)
        case modeSwitchFailed(CGError)
        case completeFailed(CGError)

        var errorDescription: String? {
            switch self {
            case .configurationFailed(let e): return "Failed to begin display configuration (\(e.rawValue))."
            case .modeSwitchFailed(let e):    return "Failed to set display mode (\(e.rawValue))."
            case .completeFailed(let e):      return "Failed to complete configuration (\(e.rawValue))."
            }
        }
    }

    /// Apply a mode to a display. Throws on failure.
    func applyMode(_ mode: DisplayMode, to displayID: CGDirectDisplayID) throws {
        var config: CGDisplayConfigRef?
        let beginErr = CGBeginDisplayConfiguration(&config)
        guard beginErr == .success, let config else {
            throw SwitchError.configurationFailed(beginErr)
        }

        let setErr = CGConfigureDisplayWithDisplayMode(config, displayID, mode.cgMode, nil)
        guard setErr == .success else {
            CGCancelDisplayConfiguration(config)
            throw SwitchError.modeSwitchFailed(setErr)
        }

        let completeErr = CGCompleteDisplayConfiguration(config, .forSession)
        guard completeErr == .success else {
            throw SwitchError.completeFailed(completeErr)
        }
    }

    // MARK: - Display Name via IOKit

    /// Reads the localised product name from IOKit’s display registry entry.
    func displayName(for displayID: CGDirectDisplayID) -> String {
        // Attempt IOKit lookup
        var iter: io_iterator_t = 0
        let matching = IOServiceMatching("IODisplayConnect")
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iter) == KERN_SUCCESS else {
            return fallbackName(for: displayID)
        }
        defer { IOObjectRelease(iter) }

        var serv: io_service_t = IOIteratorNext(iter)
        while serv != 0 {
            defer { IOObjectRelease(serv); serv = IOIteratorNext(iter) }
            guard let info = IODisplayCreateInfoDictionary(serv, UInt32(kIODisplayOnlyPreferredName)).takeRetainedValue() as? [String: Any],
                  let vendorID = info[kDisplayVendorID] as? UInt32,
                  let productID = info[kDisplayProductID] as? UInt32 else { continue }

            // Match by vendor + product
            if vendorID == CGDisplayVendorNumber(displayID) && productID == CGDisplayModelNumber(displayID) {
                if let names = info[kDisplayProductName] as? [String: String],
                   let name = names.values.first, !name.isEmpty {
                    return name
                }
            }
        }

        return fallbackName(for: displayID)
    }

    private func fallbackName(for displayID: CGDirectDisplayID) -> String {
        if CGDisplayIsBuiltin(displayID) != 0 {
            return "Built-in Display"
        }
        let vendor = CGDisplayVendorNumber(displayID)
        let model = CGDisplayModelNumber(displayID)
        return "Display (\(vendor)-\(model))"
    }

    // MARK: - Hotplug Monitoring

    private var reconfigCallback: CGDisplayReconfigurationCallBack?
    private var changeHandler: (() -> Void)?

    /// Register for display connect/disconnect/mode-change notifications.
    func startMonitoring(onChange: @escaping () -> Void) {
        changeHandler = onChange

        let callback: CGDisplayReconfigurationCallBack = { _, flags, _ in
            // Fire only once the reconfiguration is complete.
            guard flags.contains(.beginConfigurationFlag) == false else { return }
            DispatchQueue.main.async {
                DisplayService.shared.changeHandler?()
            }
        }
        reconfigCallback = callback
        CGDisplayRegisterReconfigurationCallback(callback, nil)
    }

    /// Remove the reconfiguration callback.
    func stopMonitoring() {
        if let cb = reconfigCallback {
            CGDisplayRemoveReconfigurationCallback(cb, nil)
            reconfigCallback = nil
        }
        changeHandler = nil
    }
}
