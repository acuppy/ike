# Ike

A menu bar time tracker for macOS that asks you, at the end of every focus block, which Eisenhower quadrant you were in.

Work in blocks. When each block ends, a small panel pops up:

- **Q1 — Urgent & Important**
- **Q2 — Important, Not Urgent**
- **Q3 — Urgent, Not Important**
- **Q4 — Neither Urgent nor Important**

Pick one (keyboard shortcut, click, or let it auto-log after 10 seconds). The block is recorded and the next one starts.

## Today

Click the menu bar item to see how the day is shaping up:

- A colored timeline bar across the day
- A "trending toward" callout once you've logged enough to have a story
- Every block in reverse chronological order — click any one to edit its type or description
- Per-quadrant totals at the bottom

## This week

A stacked bar chart of the last seven days, so you can see whether you're leaning into Q2 deep work or staying trapped in Q1 firefighting.

## Breaks

`⌃⌥⌘0` to step away. The work timer pauses, a break counter starts in the menu bar, and Ike checks in when it's time to come back.

## Schedule-aware

Tell Ike when you work and it activates automatically — quiet outside those hours, no prompts on the weekend. "End the day" and "Work now" overrides let you take manual control on unusual days.

## Requirements

macOS 14 or later. Menu bar only — no Dock icon.

## Server

A Rails backend lives under [`server/`](server/) — Google sign-in, per-user
SQLite log, the same Today / Weekly / All activity views, and a JSON API the
menu bar app pushes into. See [`server/README.md`](server/README.md).

When connected (Preferences → Server → **Connect with Google…**), Ike keeps
writing its local JSONL as the source of truth and a background syncer pushes
each block to the server; idempotent on retry, offline-safe, and unsynced
entries drain on app launch.
