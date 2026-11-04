---
name: phone-dev
description: Run Easyday on Derek's phone over Tailscale (no cable, any network) with hot reload, next to an emulator loop for checking work first. Use when Derek wants to try changes on the phone, says "ship it to my phone", "put it on my phone", "let's work on the app together", or when starting, reconnecting or fixing the phone or emulator dev loops.
---

# Phone + emulator dev flow

Derek uses **Easyday Dev** on the Pixel and talks to you in T3 Code. You change code, check it on the emulator, and
ship it to the phone when it is worth trying. Two `flutter run` loops run from the same checkout (`mobile/`):

| Loop | Device / serial | Control port | Started by |
|---|---|---|---|
| Emulator | `emulator-5554` (AVD `Pixel_9_Pro_API_36`) | `127.0.0.1:5181` | `node tool/dev.mjs` |
| Phone | `100.68.165.42:5555` (Pixel on Tailscale) | `127.0.0.1:5182` | `node tool/phone.mjs` |

The phone only changes when you reload its loop, so half-finished work never reaches it. Human docs:
`mobile/README.md`, "Phone + emulator: building it together".

## Start (all from `mobile/`)

1. Check what is already up: `curl -s localhost:5181/status`, `node tool/phone.mjs status`. Only one loop can own each
   port; reuse a running loop.
2. Emulator: if `adb devices` has no `emulator-5554`, boot it (PowerShell):
   `Start-Process "$env:LOCALAPPDATA\Android\Sdk\emulator\emulator.exe" -ArgumentList "-avd","Pixel_9_Pro_API_36","-no-boot-anim" -WindowStyle Minimized`
   and wait for `adb -s emulator-5554 shell getprop sys.boot_completed` to print 1.
3. Emulator loop, detached so it outlives the tool call (PowerShell):
   `Start-Process node -ArgumentList "tool/dev.mjs" -WindowStyle Hidden -WorkingDirectory (Get-Location)`, then poll
   `curl -s localhost:5181/status` until `"ready":true` (~30 s warm). Log: `build/dev.log`.
4. Phone loop: `node tool/phone.mjs` (connects, starts the loop detached, returns when the app runs; ~2 min the first
   time, install over Tailscale). Log: `curl localhost:5182/log?tail=40` or `build/dev-5182.log`.

## Work

- Edit, `flutter test` for logic, `curl -s localhost:5181/reload` (or `/restart` when state shape or `main` changed).
- See and drive the emulator: `bash tool/shot.sh name`, `bash tool/ui.sh [serial] [filter]`, `bash tool/tap.sh "Label"`.
  Look at the screenshots (zoom in) before calling something done.
- Ship: `node tool/phone.mjs reload` (keeps Derek's screen and state) or `node tool/phone.mjs restart` (app starts over:
  use it when a reload cannot show the change, and say so, since it drops Derek's place). Then tell Derek in one line
  what changed and that it is on the phone.
- "sent: Easyday Dev is in the background" is normal: Derek is in T3 Code, the code is on the phone, and the rebuild
  happens the moment the app is opened. Do not wait for it or bring the app to the front.
- See the phone if Derek asks about what is on screen: `bash tool/shot.sh name 100.68.165.42:5555`. A locked phone shows
  the always-on display.

## When something breaks

| Symptom | Fix |
|---|---|
| `phone not reachable on Tailscale` | Ask Derek to open Tailscale on the phone (Always-on VPN keeps it up) |
| `no adb port open` / port 5555 closed | The phone rebooted. Ask Derek to turn on Developer options › Wireless debugging and send the port shown under "IP address & port", then `node tool/phone.mjs start PORT`. On the same Wi-Fi it is found by mDNS with no port needed. Without a port the helper scans for ~2 min |
| `no authorised adb port` | Pairing is gone (new PC, cleared keys). Ask Derek for Wireless debugging › Pair device with pairing code: the port and the 6-digit code, dialog left open. Then `node tool/phone.mjs pair PORT CODE` straight away |
| `protocol fault` while pairing | adb older than 37: `sdkmanager "platform-tools"` (kill-server first) |
| Phone loop gone (`status` shows `dev: null`) | `node tool/phone.mjs` again; `reload` restarts it by itself (a fresh run installs the current code) |
| Emulator: `Can't find service: package`, adb shell hangs | Emulator wedged: `adb -s emulator-5554 emu kill`, cold boot with `-no-snapshot-load` |
| Emulator install: `not enough space` | `/data` is nearly full: uninstall stale packages (`adb -s emulator-5554 shell pm list packages -3`; never needed: `dev.derekurban.fitness*`) |
| Added a plugin, touched Kotlin or the manifest | Hot reload cannot carry it: `curl localhost:5181/stop` and `node tool/phone.mjs stop`, then start both again |

## Don't

- Send `adb shell input keyevent 4` on a root tab (exits the app; a cold start runs the installed snapshot, not the
  reloaded code).
- Port-scan the phone fast: closed ports drop packets, and more than ~300 probes in flight over Tailscale misses the
  open ones. Ask Derek for the port instead.
- Uninstall or touch `app.easyday` / `app.easyday.staging` on the phone: those are Derek's real installs and data.
  Easyday Dev (`app.easyday.staging.dev`) has its own data and starts at onboarding when freshly installed.
- Leave temporary test edits in files after checking them on the emulator: the next phone reload ships whatever is on disk.
