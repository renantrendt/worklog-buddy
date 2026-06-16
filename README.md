<div align="center">

<img src="docs/hero.png" width="180" alt="Worklog Buddy">

# Worklog Buddy

**A tiny macOS menu-bar buddy that nudges you to log your working hours.**

Every interval a little pixel frog pops onto your screen. Click it and it poofs away
until the next nudge — a gentle, hard-to-ignore reminder so you don't lose track of time.

### 🎨 [See all the expressions →](https://renantrendt.github.io/worklog-buddy/)

</div>

---

## Features

- 🐸 **A 50px pixel buddy** that appears on a schedule and fades away with a poof when clicked.
- 🖱️ **Drag it anywhere** — drop it where you like and it reappears there next time.
- 📊 **Menu-bar control** with a live countdown (`Next nudge in 23 min`), snooze, and pause.
- ⏰ **Active hours & days** so it never nags you at 2 a.m. or on weekends.
- 🎚️ **Preferences** for interval, placement, buddy size, and sound.
- 🪶 Native **Swift + AppKit**, a single source file, no Xcode project and no runtime dependencies.

## Expressions

The buddy has a range of moods — a wink when you dismiss it, a grumpy face if you ignore it,
hearts when you finally log your hours, and more.

**[Browse the live expression gallery →](https://renantrendt.github.io/worklog-buddy/)**

## Build & run

Requires macOS with the Swift toolchain (Xcode or the Command Line Tools).

```bash
./build.sh          # compiles Sources/main.swift into WorklogBuddy.app
open WorklogBuddy.app
```

The app lives in the menu bar (no Dock icon). Click the winking icon for options, or
**Show buddy now** to preview it immediately.

## How it works

- A lightweight timer checks every few seconds whether it's time to nudge, but only inside
  your configured **active hours and days**.
- When it's time, a borderless, always-on-top window pops in (fade + slide) at your chosen spot.
- A **click** poofs it away and schedules the next nudge; a **drag** repositions it.
- All settings persist via `UserDefaults`.

## Project layout

| Path | Purpose |
|------|---------|
| `Sources/main.swift` | The entire app — pixel art, scheduling, menu bar, preferences. |
| `build.sh` | Compiles and bundles `WorklogBuddy.app`. |
| `Info.plist` | Bundle metadata (`LSUIElement` = menu-bar agent). |
| `docs/` | The GitHub Pages expression gallery. |

## License

MIT
