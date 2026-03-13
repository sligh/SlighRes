# SlighRes — Test Plan

## Overview

Since `MenuBarExtra` and CoreGraphics display APIs require real hardware,
testing is primarily manual. This document lists scenarios to verify before
each release.

---

## Environment Matrix

| Config | Description |
|--------|-------------|
| **A** | MacBook (built-in display only) |
| **B** | MacBook + 1 external monitor |
| **C** | MacBook + 2 external monitors (ideally same model) |
| **D** | Mac mini / Mac Studio with external only |

---

## Test Cases

### TC-01: Launch & Menu Bar Icon
- **Steps:** Build & run. Check the menu bar.
- **Expected:** A display icon appears in the menu bar. No Dock icon.
- **Configs:** All.

### TC-02: Display Enumeration
- **Steps:** Click the menu bar icon.
- **Expected:** Each connected display appears as a section header with model
  name. Built-in shows a laptop icon; external shows a monitor icon.
- **Configs:** B, C, D.

### TC-03: Resolution Listing
- **Steps:** Expand any display section.
- **Expected:** Modes are listed descending by logical width. HiDPI modes are
  tagged. No duplicates (same logical size + scale).
- **Configs:** All.

### TC-04: Current Mode Highlight
- **Steps:** Open the menu.
- **Expected:** The active resolution has a checkmark and uses the system
  accent colour.
- **Configs:** All.

### TC-05: Switch Resolution — Keep
- **Steps:** Click a different resolution. Wait for the confirmation dialog.
  Click **Keep**.
- **Expected:** Resolution changes. Dialog dismisses. Menu updates to show
  new mode as current.
- **Configs:** All.

### TC-06: Switch Resolution — Revert (button)
- **Steps:** Click a different resolution. In the confirmation dialog, click
  **Revert Now**.
- **Expected:** Previous resolution is restored. Menu updates.
- **Configs:** All.

### TC-07: Switch Resolution — Revert (timeout)
- **Steps:** Click a different resolution. Do **not** interact with the
  dialog. Wait 10 seconds.
- **Expected:** Dialog closes automatically. Previous resolution is restored.
- **Configs:** All.

### TC-08: Hot-Plug Connect
- **Steps:** With the app running, plug in an external display.
- **Expected:** Within ~2 seconds the new display appears in the menu.
- **Configs:** A → B.

### TC-09: Hot-Plug Disconnect
- **Steps:** With 2+ displays, unplug one.
- **Expected:** The disconnected display’s section is removed from the menu.
- **Configs:** B → A.

### TC-10: Identical Monitors Disambiguation
- **Steps:** Connect two identical external monitors.
- **Expected:** Both appear with their model name, distinguished by serial
  number (if available) or display ID.
- **Configs:** C.

### TC-11: Settings Window
- **Steps:** Click Settings… in the menu.
- **Expected:** Settings window opens with launch-at-login toggle and About
  section.
- **Configs:** Any.

### TC-12: Refresh Button
- **Steps:** Click the Refresh button at the bottom of the menu.
- **Expected:** Display list reloads. Useful if a reconfiguration callback
  was missed.
- **Configs:** Any.

### TC-13: Quit
- **Steps:** Click "Quit SlighRes".
- **Expected:** App terminates. Menu bar icon disappears.
- **Configs:** Any.

---

## Regression Checks

- No memory leaks after 50+ resolution switches (use Instruments → Leaks).
- No crashes on rapid connect/disconnect cycles.
- Confirm the app does **not** appear in the Dock or Cmd-Tab switcher.

---

## Automation Notes

Unit tests for `DisplayMode` filtering logic and `RevertSafetyManager` timer
behaviour can be written with XCTest. Full display-switching tests require
hardware and are manual-only.
