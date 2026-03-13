# SlighRes — Implementation Plan

## Milestones

### M1 — Scaffold & Display Enumeration (Day 1)
- [x] Create Xcode project structure
- [x] Implement `DisplayService` — enumerate displays, list modes, get current mode
- [x] Unit-test with mock data

### M2 — Menu Bar UI (Day 1–2)
- [x] `MenuBarExtra` with SF Symbol icon
- [x] `DisplayViewModel` publishing display list
- [x] Per-display sections with resolution rows
- [x] Accent-colour highlight for current mode

### M3 — Resolution Switching + Safety (Day 2)
- [x] `DisplayService.applyMode` implementation
- [x] `RevertSafetyManager` with countdown alert
- [x] Wire switch → revert flow end-to-end

### M4 — Hot-Plug & Polish (Day 2–3)
- [x] `CGDisplayRegisterReconfigurationCallback` integration
- [x] Refresh display list on connect/disconnect
- [x] Settings window (launch-at-login, about)

### M5 — Packaging & Docs (Day 3)
- [x] App icon asset
- [x] Info.plist (LSUIElement = true)
- [x] README, test plan, signing notes
- [x] Final code review

## Task Breakdown

See individual milestone items above.  Each bullet is a discrete, testable
unit of work.

## Testing Strategy

| Layer | Method |
|-------|--------|
| DisplayService | Manual testing on real hardware; mock wrapper for CI |
| RevertSafetyManager | Unit test timer logic with XCTest expectations |
| ViewModel | Verify published state updates via Combine/Observation |
| UI | Manual smoke test: single display, dual display, hot-plug |
| Integration | End-to-end: launch → switch → confirm/revert |

Automated UI tests are impractical for `MenuBarExtra`; the test plan
(`docs/TEST_PLAN.md`) covers manual verification steps.
