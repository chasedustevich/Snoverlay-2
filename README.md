<div align="center">
  <img src="Icon.png" width="90" alt="Snoverlay 2 Icon">
  <h1>Snoverlay 2 (Rootless)</h1>
  <p><strong>Falling snowflakes across iOS 15–16+ SpringBoard & Wallpapers</strong></p>
  <p>
    <img src="https://img.shields.io/badge/iOS-15.0%2B-blue.svg" alt="iOS 15.0+">
    <img src="https://img.shields.io/badge/Scheme-Rootless-success.svg" alt="Rootless">
    <img src="https://img.shields.io/badge/Arch-arm64%20%7C%20arm64e-orange.svg" alt="Architecture">
    <img src="https://img.shields.io/badge/Jailbreak-Dopamine%20%7C%20Palera1n-purple.svg" alt="Jailbreak">
    <img src="https://img.shields.io/badge/Version-1.1.0-brightgreen.svg" alt="Version">
  </p>
</div>

---

This was updated completely by Antigravity Gemini Flash 3.8 High to rootless with support for ios 15(?)+ on Dopamine. Tested on 16.5. All credit to Ryan Nair and leftyfl1p.

A lightweight, elegant iOS jailbreak tweak that renders falling snowflakes across your screen. Supports two snowfall modes: restricted directly to your **home/lock screen wallpaper** beneath your app icons, or as a **full-screen passive overlay** over all applications, with dedicated support for CarPlay lockout screens. Includes a Preferences pane in Settings with instant live reloading via Darwin notifications.

Originally created by **Ryan Nair** (`ryannair05`, superseding leftyfl1p's original Snoverlay). Completely modernized and updated for **iOS 15–16+ rootless jailbreaks (Dopamine, Palera1n)** by **Chase Dustevich**.

---

## ❄️ Features

* **Two Distinct Display Modes:**
  * **Wallpaper Only (Default):** Flakes drift softly directly over the static home and lock screen wallpapers behind your app icons and widgets.
  * **Full-Screen Overlay:** Flakes cascade across every app and interface window throughout SpringBoard.
* **Dual Snowfall Engines:**
  * **Standard Performance Engine (`CAEmitterLayer`):** Highly battery-efficient hardware-accelerated particle system with natural physics (drift, gravity, spin, velocity variance).
  * **High Quality Engine (`CABasicAnimation`):** Generates individually randomized `UIImageView` snowflakes animated with 3D Y-axis spinning and vertical translation.
* **Snowflake Styles & Density:** Choose between classic white and subtle blue snowflake styles, with fully adjustable flake density (15 to 200 flakes).
* **Live Dynamic Settings:** Preference changes made in the Settings app take effect immediately without requiring a respring, with an optional Respring button provided for convenience.
* **CarPlay Support:** Automatically cascades snowflakes across CarPlay lockout displays.

---

## 🛠️ Technical Architecture & The iOS 16 Fix

### 1. The iOS 16 `SBWindowScene` Challenge
Prior to iOS 16, a tweak displaying a full-screen SpringBoard overlay could create a window anywhere using `[[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds]`. UIKit automatically rendered and composited any standalone window onto the device display.

Starting with **iOS 16**, Apple heavily restructured SpringBoard's multi-window and scene pipeline:
* Windows in SpringBoard must be explicitly attached to an active **`UIWindowScene`** (specifically SpringBoard's primary `SBWindowScene`).
* If a `UIWindow` is initialized with legacy `initWithFrame:` without a scene, UIKit parks the window on an unattached internal dummy screen scene. Even when `hidden = NO` is set, the window server **never draws or composites it to the display**.
* Furthermore, `SBWindowScene` is often not yet connected at the moment `-[SpringBoard applicationDidFinishLaunching:]` executes. Creating the window prematurely results in a nil scene and an invisible overlay.

### 2. How Snoverlay 2 Solves This on iOS 16+
* **Scene Discovery & Attachment:** The overlay manager inspects `[UIApplication sharedApplication].connectedScenes` for a `UIWindowScene` tied to `[UIScreen mainScreen]`, preferring SpringBoard's internal `SBWindowScene`. The overlay window is created using `-[SnoverlaySecureWindow initWithWindowScene:]`.
* **Dynamic Connection Monitoring:** If the main `SBWindowScene` has not finished connecting when SpringBoard launches, `SnoverlayWindowManager` observes `UISceneWillConnectNotification` and `UISceneDidActivateNotification`, deferring window instantiation until the scene is fully connected. It also safely tears down on `UISceneDidDisconnectNotification`.
* **Root View Controller Architecture:** Instead of attaching views directly to the window, the overlay hosts a dedicated transparent `SnoverlayOverlayViewController`, ensuring proper rotation handling across all interface orientations and responsive layout updates in `viewDidLayoutSubviews`.
* **Zero Touch Interference:** The overlay window overrides private `_ignoresHitTest` to return `YES` and implements `hitTest:withEvent:` returning `nil`. This guarantees that touches, swipes, gestures, Control Center pulls, and Home bar interactions pass through seamlessly to underlying apps and SpringBoard without any delay or blocking.
* **Secure Context:** The overlay window sets `_shouldCreateContextAsSecure` and `_setSecure:YES` with window level `10,000,000` to maintain clean visual continuity across system alerts and transitions.

### 3. Native Rootless Compatibility
* **Rootless Filesystem Resolution:** In rootless environments (such as Dopamine on iOS 15/16), jailbreak assets reside under `/var/jb`. The tweak imports `<rootless.h>` and resolves snowflake image assets (`XMASSnowflake.png` and `XMASSnowflake1.png`) dynamically using `ROOT_PATH_NS(@"/Library/Application Support/Snoverlay")` with fallbacks.
* **Modern Package Scheme:** Configured with `THEOS_PACKAGE_SCHEME = rootless`, `TARGET = iphone:clang:latest:15.0`, and `ARCHS = arm64 arm64e`. Debian control is updated to architecture `iphoneos-arm64`.
* **PreferenceLoader Bundle Staging:** The preference loader specification is cleanly placed under `layout/Library/PreferenceLoader/Preferences/snoverlayprefs.plist`, which Theos stages directly under the rootless `/var/jb` hierarchy.
* **Rootless Respring Helper:** The Settings bundle incorporates a respring action executing `posix_spawn` with `ROOT_PATH("/usr/bin/killall")` against `backboardd`.

---

## 📱 Compatibility

* **iOS Versions:** iOS 15.0 through 16.x+ (tested on Dopamine, iOS 16.5).
* **Jailbreak Environments:** Dopamine, Palera1n (rootless), and any standard rootless setup.
* **Architectures:** `arm64`, `arm64e`.
* **Package Identifier:** `com.chasedustevich.snoverlay` (replaces and conflicts with legacy `com.ryannair05.snoverlay` and `com.leftyfl1p.snoverlay`).

---

## ⚙️ Configuration & Preferences

Preferences are available in **Settings → Snoverlay 2**:

| Key | Type | Default | Description |
|---|---|---|---|
| `enabled` | Boolean | `true` | Enables or disables the tweak. |
| `wallpaperOnly` | Boolean | `true` | Confines snowfall strictly to the static wallpaper behind icons. When disabled, snow falls full-screen over all applications. |
| `highQuality` | Boolean | `false` | When off, uses the battery-efficient `CAEmitterLayer` engine. When on, animates individual `UIImageView` snowflakes using `CABasicAnimation` 3D rotation and translation. |
| `numSnowflakes` | Integer | `160` | Number of flakes in high quality mode, or emitter birth rate divisor in particle mode (15–200). |
| `snowFlakeType` | Integer | `0` | Flake style: `0` = White (`XMASSnowflake.png`), `1` = Blue (`XMASSnowflake1.png`). |

*All configuration options update immediately via Darwin IPC notification `com.ryannair05.snoverlay/prefsupdated` without requiring a respring.*

---

## 💻 Building from Source

### Prerequisites
1. [Theos](https://theos.dev/) installed with `$THEOS` defined in your environment.
2. An iOS SDK (version 15.0 or later).

### Build & Package
```sh
# Build the rootless .deb package
make package

# Install directly to your jailbroken test device over SSH:
make package install THEOS_DEVICE_IP=<your-device-ip>
```

---

## 📜 Credits & Acknowledgments

* **Chase Dustevich** ([@chasedustevich](https://github.com/chasedustevich)) — iOS 15–16+ rootless modernization, `SBWindowScene` implementation, hit-test pass-through architecture, documentation.
* **Ryan Nair** ([@ryannair05](https://github.com/ryannair05)) — Snoverlay 2 creator, `CAEmitterLayer` engine, CarPlay implementation.
* **leftyfl1p** — Original Snoverlay tweak creator.
* **Bruno Andrade** — Inspiration for the `CustoWindow` passthrough and scene attachment pattern from S8Edge.
