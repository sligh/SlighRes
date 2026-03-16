# SlighRes — Memory Analysis Report

**Date:** March 16, 2026  
**Observed Memory:** ~51 MB (production, running in menu bar)  
**Goal:** Identify optimization opportunities to minimize memory footprint

---

## 1. Memory Usage Breakdown (Estimated)

| Component | Estimated Memory | Notes |
|-----------|-----------------|-------|
| **Swift/SwiftUI runtime** | ~18–22 MB | Baseline for any SwiftUI app on macOS 14+ |
| **AppKit framework** | ~8–12 MB | Loaded because of `NSAlert`, `NSApplication` usage in `RevertSafetyManager` |
| **Combine framework** | ~2–3 MB | Imported in `DisplayViewModel.swift` (even if unused directly) |
| **IOKit framework** | ~1–2 MB | Used for display name lookup |
| **CoreGraphics** | ~2–3 MB | Display mode enumeration, configuration APIs |
| **CGDisplayMode objects** | ~1–3 MB | Retained `CGDisplayMode` references in `DisplayMode.cgMode` (per display × modes) |
| **MenuBarExtra window style** | ~3–5 MB | `.window` style allocates a full `NSPanel` + backing store |
| **Settings scene** | ~2–4 MB | `Settings` scene is pre-allocated by SwiftUI even when not shown |
| **App icon assets** | ~0.5–1 MB | 10 PNG icons (16px to 1024px), ~56 KB on disk, decoded larger |
| **Miscellaneous (strings, metadata, dyld)** | ~2–4 MB | String tables, dylib mappings, OS overhead |
| **Total estimated** | **~40–57 MB** | Consistent with observed 51 MB |

### Key Insight
**The majority of the 51 MB (~30–35 MB) is framework overhead**, not application code. A SwiftUI + AppKit menu bar app has a floor of approximately 25–35 MB simply by importing SwiftUI and presenting a `MenuBarExtra`. The app's own data structures and logic contribute only ~5–10 MB.

---

## 2. Optimization Opportunities

### 🔴 High Impact

#### H1. Replace `MenuBarExtra(.window)` with `MenuBarExtra(.menu)` or Pure `NSStatusItem`
- **Current:** `.menuBarExtraStyle(.window)` creates a full SwiftUI-backed `NSPanel` with compositing layers, even when the menu is closed.
- **Savings:** ~3–8 MB  
- **Complexity:** Medium  
- **Trade-off:** `.menu` style is more limited in layout but uses native `NSMenu` with significantly less overhead. Alternatively, dropping `MenuBarExtra` entirely and using a manual `NSStatusItem` + `NSPopover` approach lets you control the window lifecycle — create on open, destroy on close.
- **Recommendation:** If custom SwiftUI layout is needed, use `NSStatusItem` with `NSPopover` and destroy the popover's content view controller when closed. If a simple list suffices, switch to `.menu` style.

#### H2. Remove the `Settings` Scene (Lazy-Load Instead)
- **Current:** `Settings { SettingsView() }` is declared in the `App` body. SwiftUI pre-allocates the `Settings` scene infrastructure at launch, even before the user opens Preferences.
- **Savings:** ~2–4 MB
- **Complexity:** Low–Medium  
- **Implementation:** Replace with a programmatic `NSWindow` created on-demand when the user clicks "Preferences…", and release it on close. Or use `openWindow` with a `Window` scene gated behind user action.
- **Trade-off:** Slightly more code to manage the preferences window lifecycle manually.

#### H3. Remove Unused `Combine` Import
- **Current:** `DisplayViewModel.swift` imports `Combine` but uses `@Observable` (Swift Observation framework), not `@Published` / Combine publishers.
- **Savings:** ~1–3 MB (Combine framework won't be linked if nothing references it)
- **Complexity:** Trivial  
- **Implementation:** Remove `import Combine` from `DisplayViewModel.swift`.
- **Trade-off:** None.

---

### 🟡 Medium Impact

#### M1. Don't Retain `CGDisplayMode` Objects in `DisplayMode`
- **Current:** Every `DisplayMode` stores `let cgMode: CGDisplayMode` — a Core Foundation reference type that retains the underlying CG mode descriptor. With 2 displays × ~30–50 modes each, this can hold 60–100+ CG objects in memory indefinitely.
- **Savings:** ~0.5–2 MB  
- **Complexity:** Medium  
- **Implementation:** Store only the `ioDisplayModeID` (Int32). When applying a mode, re-fetch the `CGDisplayMode` from `CGDisplayCopyAllDisplayModes` by matching the ID. This is a fast operation (~1 ms).
- **Trade-off:** Tiny latency on resolution switch (negligible for user-facing action).

#### M2. Lazy Display Mode Enumeration
- **Current:** `DisplayViewModel.init()` calls `refresh()` which calls `allDisplays()`, which enumerates **all** modes for **all** displays at launch — even before the user opens the menu.
- **Savings:** ~0.5–1 MB (deferred allocation)
- **Complexity:** Low  
- **Implementation:** Enumerate display names/IDs at launch but defer mode enumeration until the menu is first opened.
- **Trade-off:** ~50 ms delay on first menu open (imperceptible).

#### M3. Reduce App Icon Sizes for Menu Bar App
- **Current:** 10 icon variants from 16×16 to 1024×1024 (56 KB on disk, but PNG decompression can allocate 4× size in RGBA bitmap).
- **Savings:** ~0.3–0.8 MB  
- **Complexity:** Low  
- **Implementation:** Since this is an `LSUIElement` (menu-bar-only) app, it never appears in the Dock or App Switcher at large sizes. You can safely remove the 512@2x (1024px) icon — the largest. macOS will use the largest available for any context. Keep only 16, 32, 128, 256 at 1× and 2×.
- **Trade-off:** Slightly lower fidelity if icon is ever viewed at 512pt (rare for menu bar apps).

#### M4. Eliminate Redundant `displays` Array Copies
- **Current:** `refresh()` replaces the entire `displays` array. Each `DisplayInfo` contains a `modes: [DisplayMode]` array. Since `DisplayMode` holds a CG reference type, array copies involve reference counting overhead.
- **Savings:** ~0.2–0.5 MB  
- **Complexity:** Low  
- **Implementation:** Use in-place mutation or diff the new display list against the existing one, only updating changed entries.
- **Trade-off:** Slightly more complex refresh logic.

---

### 🟢 Low Impact

#### L1. Avoid Re-creating `RevertSafetyManager` Instance
- **Current:** `RevertSafetyManager()` is created once in `DisplayViewModel` and retained. This is fine. However, each countdown creates and retains an `NSAlert` that is only cleaned up in `cleanup()`.
- **Savings:** Minimal (~few KB)
- **Complexity:** Already handled correctly (cleanup is called)
- **Recommendation:** Verify `cleanup()` is always called, even on error paths. Current code looks correct.

#### L2. String Interpolation in Mode Dedup Keys
- **Current:** `availableModes(for:)` creates dedup keys via `"\(mode.logicalWidth)x\(mode.logicalHeight)x\(mode.scale)"` — allocates a String per mode.
- **Savings:** ~few KB  
- **Complexity:** Trivial  
- **Implementation:** Use a `struct` key (3 Ints) or a packed `Int64` instead of String for the `seen` set.
- **Trade-off:** None.

#### L3. `@AppStorage` Observers
- **Current:** `showHiDPIOnly` and `launchAtLogin` each register a `UserDefaults` KVO observer.
- **Savings:** Negligible  
- **Complexity:** N/A  
- **Recommendation:** No action needed. This is standard SwiftUI behavior.

#### L4. Unused `height` Variable in `DisplayMode.init`
- **Current:** Screenshot shows a warning: "Initialization of immutable value 'h' was never used." (line 53 of `DisplayMode.swift` — the `let h = cgMode.height` that was previously used in the removed code).
- **Savings:** Negligible (a single `Int` on stack)  
- **Complexity:** Trivial  
- **Note:** This was already partially addressed per the screenshots, but removing unused locals is good hygiene.

---

## 3. Framework Dependency Analysis

| Framework | Required By | Can Replace? |
|-----------|------------|--------------|
| **SwiftUI** | All views, `MenuBarExtra`, `@Observable` | No — core UI framework |
| **AppKit** | `NSAlert` (RevertSafetyManager), `NSApplication.terminate`, `NSApp.activate` | Partially — could use SwiftUI `.alert()` instead of `NSAlert`, but it's already loaded by SwiftUI |
| **CoreGraphics** | Display enumeration, mode switching | No — essential for core functionality |
| **IOKit** | Display name lookup (`IODisplayCreateInfoDictionary`) | Could replace with `CGDisplayVendorNumber`/`CGDisplayModelNumber` fallback only, saving IOKit import. Savings: ~1 MB |
| **Combine** | Imported but unused | **Yes — remove entirely.** `@Observable` doesn't need Combine |
| **Foundation** | Used everywhere | No — required by Swift runtime |

---

## 4. Overall Recommendations (Ranked by ROI)

| Priority | Action | Est. Savings | Effort |
|----------|--------|-------------|--------|
| 1 | Remove `import Combine` | 1–3 MB | 1 min |
| 2 | Replace `Settings` scene with on-demand `NSWindow` | 2–4 MB | 30 min |
| 3 | Switch to `.menu` style or `NSStatusItem` + `NSPopover` (destroy on close) | 3–8 MB | 1–2 hrs |
| 4 | Don't retain `CGDisplayMode` in model; re-fetch on apply | 0.5–2 MB | 30 min |
| 5 | Lazy-load display modes (defer until menu opened) | 0.5–1 MB | 20 min |
| 6 | Trim oversized app icons (remove 512@2x) | 0.3–0.8 MB | 5 min |
| 7 | Replace IOKit name lookup with CG fallback | ~1 MB | 15 min |
| 8 | Use struct key instead of String for dedup set | ~few KB | 5 min |

**Best-case total savings: ~10–20 MB** → achievable target of **~31–41 MB**.

---

## 5. What You Cannot Optimize Away

The irreducible minimum for a SwiftUI menu bar app on macOS 14 is approximately **25–30 MB**. This includes:

- Swift runtime and standard library (~8–10 MB)
- SwiftUI framework (~10–12 MB)  
- AppKit (loaded as SwiftUI dependency) (~5–8 MB)
- dyld shared cache mappings and process overhead (~2–3 MB)

These are loaded into the process address space by the OS and are **shared across all apps** using the same frameworks (copy-on-write pages). They appear in the app's memory footprint but do not actually consume unique physical RAM proportionally.

### Dirty vs. Clean Memory
The 51 MB figure likely includes **clean memory** (framework pages, read-only data) that is reclaimable by the OS under pressure. The app's actual **dirty memory** (unique allocations) is likely only **5–15 MB**. To verify, use Instruments → Allocations or `vmmap --summary` on the running process.

---

## 6. Nuclear Option: Drop SwiftUI Entirely

If sub-20 MB is a hard requirement, the only path is to replace SwiftUI with a pure AppKit implementation:

- `NSStatusItem` + `NSMenu` (no `NSPopover`, no `NSPanel`)
- `NSAlert` for revert safety (already in use)
- `UserDefaults` directly instead of `@AppStorage`

This would eliminate the SwiftUI framework dependency entirely, reducing the baseline to **~12–18 MB**. However, this is a full rewrite with significantly more boilerplate code and loss of SwiftUI's declarative benefits.

**Recommendation:** Unless memory is a hard competitive differentiator, focus on priorities 1–5 above to bring the app to ~35–40 MB, which is reasonable for a macOS menu bar utility.

---

## 7. Trade-offs Summary

| Approach | Target Memory | Dev Effort | Maintainability |
|----------|--------------|------------|-----------------|
| Current (no changes) | ~51 MB | None | ✅ Excellent |
| Quick wins (1, 2, 6) | ~44–47 MB | 1 hour | ✅ Excellent |
| All recommended (1–7) | ~35–40 MB | 3–4 hours | ✅ Good |
| Nuclear (pure AppKit) | ~15–20 MB | 1–2 days | ⚠️ More boilerplate |

---

*Report generated by code analysis. Memory estimates are based on typical macOS framework sizes and should be validated with Instruments (Allocations, VM Tracker) on the actual running application.*
