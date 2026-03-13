# SlighRes

A lightweight, native macOS menu-bar app for switching display resolutions on Apple Silicon Macs.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Apple Silicon](https://img.shields.io/badge/arch-arm64-orange)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-red)

---

## Features

- **Menu-bar only** — no Dock icon, always one click away.
- **All displays** — built-in and external monitors listed automatically.
- **Smart labels** — model name + serial for disambiguation of identical monitors.
- **One-click switch** — pick a resolution and it applies immediately.
- **10-second safety revert** — if you can’t see or dismiss the confirmation dialog, the previous resolution is restored automatically.
- **Hot-plug aware** — displays added or removed update the menu in real time.
- **HiDPI badge** — Retina modes clearly marked.

## Requirements

| Requirement | Value |
|-------------|-------|
| macOS | 14.0 (Sonoma) or later |
| Architecture | Apple Silicon (arm64) |
| Xcode | 15.0+ |

## Build & Run

### Option A — Xcode

1. Open `SlighRes.xcodeproj` in Xcode 15+.
2. Select the **SlighRes** scheme and **My Mac** destination.
3. **Product → Run** (⌘R).
4. The app appears as a display icon (🖥) in the menu bar.

### Option B — Command-line

```bash
xcodebuild -project SlighRes.xcodeproj \
           -scheme SlighRes \
           -configuration Release \
           -arch arm64 \
           build
```

The built `.app` bundle lands in the derived-data build directory.

### Option C — Swift Package Manager (alternative)

If you prefer SPM over the Xcode project, create a `Package.swift` at the
repo root:

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SlighRes",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "SlighRes",
            path: "SlighRes/Sources",
            resources: [
                .process("../Resources/Assets.xcassets")
            ]
        )
    ]
)
```

Then `swift build`.

## Project Structure

```
SlighRes/
├── Sources/
│   ├── App/
│   │   └── SlighResApp.swift        # @main entry, MenuBarExtra + Settings
│   ├── Models/
│   │   ├── DisplayInfo.swift        # Per-display model
│   │   └── DisplayMode.swift        # Per-resolution model
│   ├── Services/
│   │   ├── DisplayService.swift     # CoreGraphics wrapper
│   │   └── RevertSafetyManager.swift # 10-sec countdown + revert
│   ├── ViewModels/
│   │   └── DisplayViewModel.swift   # @Observable state
│   └── Views/
│       ├── MenuBarView.swift        # Main dropdown UI
│       └── SettingsView.swift       # Preferences window
├── Resources/
│   └── Assets.xcassets/             # App icon, accent colour
├── Info.plist
└── SlighRes.entitlements
```

## How It Works

1. On launch the app enumerates active displays via `CGGetActiveDisplayList`.
2. For each display it reads modes with `CGDisplayCopyAllDisplayModes` and
   filters to usable, deduplicated modes.
3. The menu shows each display as a section; clicking a mode calls
   `CGConfigureDisplayWithDisplayMode`.
4. After a switch, `RevertSafetyManager` shows an `NSAlert` with a 10-second
   countdown. If the user doesn’t click **Keep**, the previous mode is restored.
5. A `CGDisplayReconfigurationCallback` fires whenever displays are
   connected, disconnected, or reconfigured — the menu refreshes automatically.

## Signing & Notarization

See [docs/SIGNING.md](docs/SIGNING.md) for details. **TL;DR:**

- For personal use, ad-hoc signing is fine:
  ```bash
  codesign --force --deep --sign - SlighRes.app
  ```
- For sharing, sign with a Developer ID certificate and notarize with
  `notarytool`.

## License

Personal use. No warranty.
