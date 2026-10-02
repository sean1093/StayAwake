# StayAwake

**English** · [繁體中文](README.zh-TW.md)

> A macOS menu bar app that keeps your display awake and nudges the mouse while you are idle,
> so Microsoft Teams never flips your status to "Away".

<div align="center">

[Download latest](https://github.com/sean1093/StayAwake/releases/latest) · [Issues](https://github.com/sean1093/StayAwake/issues)

</div>

---

## Features

- **Display stays on**: while running, neither the display nor the system sleeps on idle (same effect as `caffeinate -d`).
- **Teams stays "Available"**: new Teams switches to "Away" when the screen locks or the Mac sleeps. StayAwake keeps the idle
  screen saver from starting, so the screen never locks on its own.
- **Mouse nudge while idle**: once you have been idle for the configured time, the mouse moves 1 pixel right and straight back,
  resetting the system idle time. You cannot see it and the cursor ends where it was; while you are using the Mac it never moves.
- **Adjustable idle time**: 30 seconds, 1 minute (default), 2 minutes, 4 minutes, all under the common 5-minute idle cutoff for presence and screen savers.
- **Lives in the menu bar**: no Dock icon, one click to pause or resume.
- About 200 lines of native Swift, no third-party dependencies.

## Requirements

- macOS 13 Ventura or later (tested on macOS 26)
- Apple Silicon or Intel (universal binary)

## Install

### Option 1: one command (recommended)

Open Terminal and run:

```sh
curl -fsSL -o /tmp/StayAwake.zip https://github.com/sean1093/StayAwake/releases/latest/download/StayAwake.zip \
  && ditto -x -k /tmp/StayAwake.zip /Applications \
  && open /Applications/StayAwake.app
```

Files downloaded with `curl` are not marked as "downloaded from the internet", so macOS does not block this app even though it is not notarized by Apple.
If you cannot write to `/Applications` (no admin rights), replace both `/Applications` with `~/Applications`.

### Option 2: manual download

1. Download `StayAwake.zip` from [Releases](https://github.com/sean1093/StayAwake/releases/latest),
   unzip it, and drag `StayAwake.app` into Applications.
2. The first launch is blocked because the developer cannot be verified (the app has no paid Apple Developer ID).
   Click **Done**, open **System Settings → Privacy & Security**, scroll down to "Security", click **Open Anyway**, and confirm.

   Alternatively, remove the quarantine flag in Terminal and open it normally:

   ```sh
   xattr -dr com.apple.quarantine /Applications/StayAwake.app
   ```

### Grant Accessibility permission (needed to move the mouse)

macOS only lets apps move the mouse after you grant them Accessibility permission.

1. On first launch StayAwake asks for it. Click **Open System Settings**.
2. In **System Settings → Privacy & Security → Accessibility**, turn on **StayAwake**.
3. When the menu bar icon changes from ⚠️ to a filled coffee cup, you are done. No restart needed.

StayAwake only uses this permission to post mouse-move events. It never records your keyboard or mouse input.

## Usage

After launch StayAwake sits in the menu bar at the top right of the screen and starts working immediately.

| Icon | State |
|---|---|
| Filled coffee cup | Running: display stays on, mouse is nudged while idle |
| Outlined coffee cup | Paused: normal sleep settings apply again |
| ⚠️ Triangle | Accessibility not granted: display still stays on, but the mouse is not nudged |

The menu is in Traditional Chinese:

| Menu item | Meaning |
|---|---|
| StayAwake 運作中 / 已暫停 | Status: running / paused |
| 上次移動滑鼠：… | Time of the last mouse nudge, so you can see it is working |
| 保持清醒 | Keep awake (checked = running, uncheck to pause) |
| 閒置多久後移動滑鼠 ▸ 30 秒 / 1 分鐘 / 2 分鐘 / 4 分鐘 | Nudge the mouse after being idle for 30 s / 1 / 2 / 4 min (remembered) |
| ⚠️ 尚未授權「輔助使用」，滑鼠不會移動 | Accessibility not granted, the mouse will not move |
| 開啟「輔助使用」設定… | Open the Accessibility settings |
| 結束 StayAwake (⌘Q) | Quit |

### Start at login

**System Settings → General → Login Items** (called "Login Items & Extensions" on newer macOS), click **+** under "Open at Login", and pick StayAwake.

## How it works

- **No sleep, no auto-lock**: `ProcessInfo.beginActivity(options: [.userInitiated, .idleDisplaySleepDisabled])`
  holds `PreventUserIdleDisplaySleep` and `PreventUserIdleSystemSleep`. While it is held, macOS does not start the idle screen saver
  (`loginwindow` logs `PMNoDisplaySleepEnabled so do not launch screen saver`), so the screen is not locked by it. Check it with:

  ```sh
  pmset -g assertions | grep StayAwake
  ```

- **Idle time reset**: every 5 seconds StayAwake reads the system idle time (time since the last keyboard or mouse input); past the
  threshold it posts two HID-level mouse events, 1 pixel right and back, which resets it to zero. Apps that judge presence by idle
  time therefore see you as active.

**Tested** on a MacBook (macOS 26, new Teams) whose MDM starts the screen saver after 5 idle minutes and locks immediately:
without StayAwake the screen locked at 300 seconds and Teams went "Away" within about a second; with StayAwake, 6 hands-off
minutes passed with no lock, Teams stayed "Available", and the mouse was nudged about every 65 seconds.

## FAQ

**Permission is on, but the icon still shows ⚠️?**
After an update or a rebuild the app signature usually changes, so the old grant no longer applies (System Settings may still show it as on).
Quit StayAwake from its menu, run this, then open the app and grant permission again:

```sh
tccutil reset All io.github.sean1093.StayAwake
```

**Teams still shows "Away"?**
Locking the screen, closing the lid, or putting the Mac to sleep always makes Teams show "Away". That is not idleness, and StayAwake cannot prevent it.
Also make sure the icon is not ⚠️ and the idle time is under 5 minutes.

**Can't turn on Accessibility on a company Mac?**
Changing this permission requires an administrator, and some managed Macs restrict it. StayAwake then still keeps the display awake, but cannot move the mouse.

**Will it get in my way?**
No. It only moves the mouse after you have been idle for the configured time, and the cursor returns to where it was.

## Update

1. Choose **結束 StayAwake** (Quit) from the menu.
2. Clear the old grant (each version has a different signature, so the old grant does not apply):

   ```sh
   tccutil reset All io.github.sean1093.StayAwake
   ```

3. Run the [install](#install) command again and grant permission once more.

## Uninstall

```sh
pkill -x StayAwake
rm -rf /Applications/StayAwake.app
tccutil reset All io.github.sean1093.StayAwake
defaults delete io.github.sean1093.StayAwake
```

## Build from source

Requires Xcode or the Command Line Tools (`xcode-select --install`) with Swift 6 or later.

```sh
git clone https://github.com/sean1093/StayAwake.git
cd StayAwake
./build.sh
open build/StayAwake.app
```

`build.sh` compiles arm64 and x86_64, merges them into a universal binary, signs it ad hoc,
and produces `build/StayAwake.app` and `build/StayAwake.zip`. A rebuild usually changes the signature; if the ⚠️ icon comes back, see the [FAQ](#faq).

```
Sources/StayAwake/
  KeepAwake.swift     prevents sleep, detects idleness, nudges the mouse
  AppDelegate.swift   menu bar UI
  main.swift          entry point
Info.plist            app settings (LSUIElement: no Dock icon)
build.sh              build, sign, package
```

### Publishing a release

1. Bump `CFBundleShortVersionString` in `Info.plist`.
2. Build and upload to a GitHub Release. Keep the asset name `StayAwake.zip` so the install command always fetches the latest version:

   ```sh
   ./build.sh
   gh release create v1.0.1 build/StayAwake.zip --title "v1.0.1" --notes "What changed"
   ```

## License

[MIT](LICENSE)
