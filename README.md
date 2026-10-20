# ABreak

A lightweight macOS menu bar break reminder that **stays out of the way while your Mac is being remote-controlled** (UURemote and similar tools), in meetings, or while you watch video.

Inspired by [LookAway](https://lookaway.app). ABreak is an independent project, not affiliated with LookAway, and contains none of its code or assets.

## Features

- Break every 45 minutes (30 s short breaks, a 3 min long break every 4th), with a heads-up before each break
- Full-screen break screen with countdown; skip button after 3 s, or press Esc twice to skip immediately; Lock Screen button
- Posture reminder every 20 minutes (a short "sit up" animation, click-through)
- Smart pause: the timer pauses and any running break is dismissed when
  - this Mac is being remote-controlled (UURemote by default; any host process name is configurable)
  - you are remote-controlling another device (the client app is in front)
  - the microphone or camera is in use (meetings, calls)
  - video is playing (some app keeps the display awake)
  - an app from your list is in front, or (opt-in) any fullscreen app is in front
- Idle detection: stepping away pauses the timer; a long absence counts as a break
- **No permissions required**: no Screen Recording, Accessibility, or Microphone access

Requires macOS 14.2 or later (Apple silicon or Intel).

## Install

1. Download `ABreak-x.y.z.zip` from the [latest release](https://github.com/ejjcc/abreak/releases/latest) and unzip it.
2. Move `ABreak.app` to `/Applications`.
3. Open it. ABreak is not notarized by Apple, so the first launch is blocked:
   - macOS 15 and later: open **System Settings → Privacy & Security**, scroll down and click **Open Anyway** next to the ABreak message, then confirm.
   - macOS 14: right-click `ABreak.app` → **Open** → **Open**.
   - Or from Terminal: `xattr -dr com.apple.quarantine /Applications/ABreak.app`

ABreak lives in the menu bar with a live countdown:

| Menu bar | Meaning |
|---|---|
| eye `44:59` | working, time to the next break |
| crossed eye `00:24` | on a break, time left |
| pause `44:59` (dimmed time) | smart or manual pause; the time is frozen and resumes when the pause ends (hover for the reason) |
| moon `44:59` (dimmed time) | you are away; the timer waits |

Open **Settings…** from its menu to adjust intervals and smart pause, switch the menu bar timer between `44:59`, `45m`, or icon only, and turn on **Launch at login**.

### Build from source

Requires Xcode or the Command Line Tools (`xcode-select --install`).

```sh
git clone https://github.com/ejjcc/abreak.git
cd abreak
scripts/build-app.sh --install    # builds, copies to /Applications, launches
```

## Remote-control detection

Remote desktop tools keep their host process running all the time, so "process is running" says nothing. ABreak watches the host process (`UURemoteServer` by default) and treats a session as live when it opens media connections (≥2 established TCP or any UDP socket), uses ≥3% CPU, or holds a display-sleep assertion. Two consecutive hits (about 4 s) start the pause; it ends 20 s after the last hit.

For other tools, add their host process name under **Settings → Smart Pause → Remote host processes**. To check what ABreak sees during a session:

```sh
/Applications/ABreak.app/Contents/MacOS/ABreak --probe
```

## Troubleshooting

- Pause/resume decisions are logged to `~/Library/Logs/ABreak.log` (menu → **Open Log**).
- **Preview Posture Reminder** in the menu shows the animation immediately.
- Uninstall: quit ABreak, delete `/Applications/ABreak.app`, and optionally `defaults delete cc.ejj.abreak`.

## Development

```sh
scripts/test.sh                                  # unit tests (swift-testing)
scripts/build-app.sh                             # -> build/ABreak.app
UNIVERSAL=1 VERSION=1.2.3 scripts/build-app.sh --zip
ABreak --preview posture|break                   # show a component right away
```

Pushing a `v*` tag builds a universal app and publishes a GitHub release.
