# Autoclicker

Minimal macOS autoclicker built with SwiftUI. Clicks at a configurable interval (10 ms – 10 s) with left, right, or double click. Toggle with **F6** or the button.

## Download

Grab `Autoclicker.zip` from [Releases](../../releases), unzip, and run:

```sh
xattr -cr Autoclicker.app   # unsigned build, clears Gatekeeper quarantine
open Autoclicker.app
```

## Build

```sh
./build.sh
open Autoclicker.app
```

Requires Xcode command line tools (`xcode-select --install`). The app needs **Accessibility permission** (System Settings → Privacy & Security → Accessibility) to post mouse events; it prompts on first launch.

## Notes

- Settings persist between launches.
- If built without a codesigning identity, the ad-hoc signature changes every build, so `build.sh` resets the stale Accessibility grant via `tccutil`.
