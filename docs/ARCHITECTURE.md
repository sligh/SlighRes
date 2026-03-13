# SlighRes — Technical Architecture & Specification

## 1. System Architecture

```
┌─────────────────────────────────────────────────┐
│                  macOS Menu Bar                  │
│  ┌───────────────────────────────────────────┐   │
│  │          MenuBarExtra (SwiftUI)           │   │
│  │  ┌─────────────────────────────────────┐  │   │
│  │  │  DisplayMenuView (per display)      │  │   │
│  │  │    → ResolutionRowView (per mode)   │  │   │
│  │  └─────────────────────────────────────┘  │   │
│  └───────────────────────────────────────────┘   │
├─────────────────────────────────────────────────┤
│               DisplayViewModel                   │
│   • Publishes [DisplayInfo]                      │
│   • Coordinates switch + revert                  │
├─────────────────────────────────────────────────┤
│  DisplayService          RevertSafetyManager     │
│  (CoreGraphics)          (Timer + Alert)         │
├─────────────────────────────────────────────────┤
│           CoreGraphics / Quartz Display SPI       │
└─────────────────────────────────────────────────┘
```

## 2. Technology Stack

| Layer | Technology |
|-------|------------|
| Language | Swift 5.9+ |
| UI | SwiftUI (MenuBarExtra, Settings scene) |
| Display API | CoreGraphics — `CGGetActiveDisplayList`, `CGDisplayCopyAllDisplayModes`, `CGDisplaySetDisplayMode`, `CGDisplayRegisterReconfigurationCallback` |
| Lifecycle | SwiftUI `@main` App with `MenuBarExtra` |
| Build | Xcode 15+ / Swift Package (single-target macOS app) |

## 3. Key Components

### 3.1 `DisplayService`
Stateless helper that wraps CoreGraphics calls.

| Method | Purpose |
|--------|---------|
| `connectedDisplays() -> [CGDirectDisplayID]` | List active displays |
| `displayInfo(for:) -> DisplayInfo` | Model name, serial, bounds |
| `availableModes(for:) -> [DisplayMode]` | Deduplicated, recommended modes |
| `currentMode(for:) -> DisplayMode?` | The mode currently active |
| `applyMode(_:to:) throws` | Set a new mode on a display |
| `startMonitoring(onChange:)` | Register reconfiguration callback |
| `stopMonitoring()` | Unregister callback |

### 3.2 `RevertSafetyManager`
Manages the 10-second countdown + confirmation alert.

- On switch: stores previous mode, starts a `Timer`.
- Shows an `NSAlert` (modal) with countdown text updated every second.
- "Keep" button → cancels timer, finalises switch.
- Timer expiry or "Revert" button → calls `DisplayService.applyMode` with
  saved mode.

### 3.3 `DisplayViewModel` (`@Observable`)
- Holds `[DisplayInfo]` with nested `[DisplayMode]`.
- Refreshes on app launch + reconfiguration callback.
- Exposes `switchResolution(displayID:mode:)` which coordinates
  `DisplayService` + `RevertSafetyManager`.

### 3.4 Views
- **`MenuBarView`** — iterates displays, renders sections.
- **`DisplaySectionView`** — header (display name) + list of modes.
- **`ResolutionRowView`** — single mode; highlighted if current.
- **`SettingsView`** — launch-at-login toggle, about info.

## 4. Data Models

```swift
struct DisplayInfo: Identifiable {
    let id: CGDirectDisplayID
    let name: String            // e.g. "LG HDR 4K"
    let serial: UInt32
    let isBuiltIn: Bool
    var currentMode: DisplayMode?
    var modes: [DisplayMode]
}

struct DisplayMode: Identifiable, Hashable {
    let id: Int32               // CGDisplayMode modeNumber
    let width: Int
    let height: Int
    let scale: Int              // 1 = lo-DPI, 2 = Retina
    let isCurrentMode: Bool
}
```

## 5. Auto-Revert Safety Mechanism

```
User clicks mode
       │
       ▼
Save previous mode ──► Apply new mode
       │                     │
       │                     ▼
       │              Show NSAlert
       │           "Keep this resolution?"
       │            Countdown: 10 … 0
       │                 │         │
       │            [Keep]    [Revert / timeout]
       │                 │         │
       │            Cancel timer   Restore previous mode
       ▼                 ▼         ▼
                    Done       Done
```

The alert runs on the main thread via `NSAlert.runModal()` variant with a
background timer that updates the informative text every second and, on
expiry, calls `NSApp.abortModal()` to dismiss.

## 6. Display Mode Filtering

CoreGraphics returns many duplicate/exotic modes. We filter by:
1. Only modes flagged as "usable for desktop GUI" (`kCGDisplayModeIsUsableForDesktopGUI`).
2. Deduplicate by (width, height, scale) — keep first occurrence.
3. Sort descending by width, then height.

## 7. Entitlements

No sandbox. No special entitlements required for CoreGraphics display
configuration when running outside the sandbox.
