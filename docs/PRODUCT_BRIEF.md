# SlighRes — Product Brief

## Overview

**SlighRes** is a lightweight, native macOS menu-bar utility that lets you switch
display resolutions in two clicks. It lives entirely in the system menu bar,
shows every connected display with its available resolutions, and includes a
10-second auto-revert safety net so you never get stuck on an unusable mode.

## Problem

macOS System Settings → Displays works, but it buries resolution options behind
multiple panes and an "Advanced" toggle. Power users — developers, designers,
presenters — change resolutions frequently and want instant access.

## Target Users

| Persona | Need |
|---------|------|
| Developer with external monitor | Quick toggle between Retina-scaled and native-pixel modes |
| Presenter | Switch to a projector-safe resolution before a talk |
| Designer | Preview layouts at common consumer resolutions |

## Key Features

1. **Menu-bar icon** — always accessible, zero dock clutter.
2. **Per-display resolution list** — every connected display gets its own
   section; current mode highlighted with the system accent colour.
3. **One-click switch** — select a resolution and it applies immediately.
4. **Auto-revert safety** — a 10-second confirmation dialog appears after every
   switch; declining (or ignoring) reverts to the previous resolution.
5. **Hot-plug aware** — displays added/removed while the app is running update
   the menu automatically.
6. **Display identification** — each display is labelled with its model name
   and, where possible, serial or connector info so identical monitors are
   distinguishable.

## Non-Goals (v1)

- Refresh-rate selection
- Rotation / mirroring controls
- Favourites / presets
- App Store distribution

## Platform Requirements

- macOS 14 (Sonoma) or later
- Apple Silicon (arm64)
- No sandbox — uses private CoreGraphics SPI for mode switching

## Success Criteria

- App launches silently into the menu bar.
- All connected displays and their recommended modes are listed.
- Switching a resolution succeeds and the revert dialog appears.
- Confirming keeps the new mode; ignoring/declining reverts.
- Connecting or disconnecting a display refreshes the list within 2 seconds.
