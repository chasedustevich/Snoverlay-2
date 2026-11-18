# AGENTS.md — Snoverlay 2

Snoverlay 2 is an **iOS jailbreak tweak** built with **Theos**, originally created by Ryan Nair (`ryannair05`, replacing leftyfl1p's original Snoverlay) and modernized for **iOS 15–16+ rootless jailbreaks (Dopamine, Palera1n)**. It renders falling snowflakes on an iPhone, either as a **full-screen overlay** or restricted to the **home/lock screen wallpaper** (`SBFStaticWallpaperView`), with additional support for CarPlay lock-out screens. It includes a **Settings (PreferenceLoader) bundle** that supports live preference updates via Darwin notifications without requiring a respring.

- Package ID: `com.ryannair05.snoverlay` (see `control`, current version `1.1.1`). Conflicts and Replaces `com.leftyfl1p.snoverlay` and `com.chasedustevich.snoverlay`.
- Scheme: **rootless only** (`THEOS_PACKAGE_SCHEME = rootless`, `iphoneos-arm64`, installs under `/var/jb`).
- Depends on: `mobilesubstrate`, `preferenceloader`, `firmware (>= 15.0)`
- Primary test environment: Dopamine, iOS 16.5
- Origin fork: `https://github.com/chasedustevich/Snoverlay-2`
- Upstream: `https://github.com/ryannair05/Snoverlay-2`
- Author: Ryan Nair (with attribution to leftyfl1p)

## Layout

| Path | Purpose |
|---|---|
| `Tweak.xm` | Main tweak entry: `SnoverlayWindowManager` (manages window and `SBWindowScene` attachment), `SnoverlaySecureWindow` (hit-test passthrough), `SnoverlayOverlayViewController`, `SBFStaticWallpaperView` hook, CarPlay hook, and Darwin notification relay. |
| `FallingSnow/XMASFallingSnowView.h/.m` | Snowflake view implementation. Houses both the `CAEmitterLayer` particle engine (default) and the `CABasicAnimation` view-based engine (high quality). Resolves assets via `<rootless.h>`. |
| `Snoverlay.plist` | Substrate filter. Injects into `com.apple.springboard` and `com.apple.CarPlayApp`. |
| `Makefile` | Root Theos makefile (tweak + `snoverlayprefs` subproject) targeting iOS 15.0 rootless. |
| `control` | Debian package control metadata (`iphoneos-arm64`, version 1.1.1). |
| `layout/Library/Application Support/Snoverlay/` | Bundled snowflake image assets (`XMASSnowflake.png` and `XMASSnowflake1.png`). |
| `snoverlayprefs/` | PreferenceLoader bundle `snoverlayprefs` (`SNOWRootListController.h/.m`, Respring helper). |
| `snoverlayprefs/Resources/Root.plist` | Preference specifiers (switches for enable, wallpaper-only, high quality; slider for snowflake count; segmented control for style; respring button). |
| `snoverlayprefs/layout/Library/PreferenceLoader/Preferences/snoverlayprefs.plist` | PreferenceLoader entry staged directly into `/var/jb`. |
| `snoverlayprefs/Resources/Info.plist` | Bundle metadata for the preference pane. |
| `snoverlayprefs/Makefile` | Subproject build file for the preference bundle. |
| `README.md` | Comprehensive user and technical documentation. |
| `CODE_OF_CONDUCT.md` | Community guidelines and contact information. |

## How it works

1. **SpringBoard Hook & Window Scene Attachment (`Tweak.xm`):**
   - Hooks `SpringBoard -applicationDidFinishLaunching:` to invoke `SnoverlayWindowManager`.
   - On iOS 16+, SpringBoard requires all displayed windows to attach to an active `SBWindowScene` (`UIWindowScene`).
   - `SnoverlayFindMainWindowScene()` finds the `SBWindowScene` on `UIScreen.mainScreen`.
   - If available, `SnoverlaySecureWindow` is initialized with `-initWithWindowScene:`; if not yet connected, `SnoverlayWindowManager` observes `UISceneWillConnectNotification` and `UISceneDidActivateNotification` and instantiates the window as soon as the scene connects.
   - On iOS 15, if no window scene is present, it safely falls back to `initWithFrame:[UIScreen mainScreen].bounds`.
   - The window is hosted by `SnoverlayOverlayViewController`, locked to level `10000000.0` with `_setSecure:YES` and `hidden = NO` (never `makeKeyAndVisible`).

2. **Touch Passthrough & Hit Testing:**
   - `SnoverlaySecureWindow` overrides `_ignoresHitTest` returning `YES` and implements `hitTest:withEvent:` returning `nil`. All touches and gestures pass through cleanly to underlying SpringBoard views and applications.

3. **Wallpaper Hook (`SBFStaticWallpaperView` in `Tweak.xm`):**
   - Hooks `_setupContentViewWithOptions:` and `_setupContentView`.
   - Calls `snoverlay_updateSnowView` to dynamically evaluate `enabled` and `wallpaperOnly` preferences.
   - Observes `com.ryannair05.snoverlay/prefsupdated` to add or tear down the wallpaper snowflake view in real-time.

4. **CarPlay Hook (`Tweak.xm`):**
   - Dynamically resolves class in `%ctor`: `CARLockOutViewController` on iOS 13+, falling back to `SBStarkLockOutViewController` on older iOS.
   - Hooks `viewDidAppear:` and `viewWillDisappear:` to manage the snow view on CarPlay lockout screens.

5. **Snowfall Rendering (`XMASFallingSnowView.m`):**
   - Two distinct rendering modes:
     - **Standard Mode (`highQuality == false`):** Uses a `CAEmitterLayer` with `kCAEmitterLayerLine` emitting `CAEmitterCell` particles across the screen width. Natural physics with drift, velocity, gravity, and spin. Battery-friendly.
     - **High Quality Mode (`highQuality == true`):** Populates `flakesArray` with individual `UIImageView`s. Animates each flake using two `CABasicAnimation`s: vertical translation (`transform.translation.y`) and 3D rotation (`transform.rotation.y`).
   - Assets are loaded from rootless paths using `ROOT_PATH_NS(@"/Library/Application Support/Snoverlay")`:
     - White snowflake: `XMASSnowflake.png`
     - Blue snowflake: `XMASSnowflake1.png`

6. **Preferences & Live IPC (`snoverlayprefs`):**
   - Specifiers read and write directly to `com.ryannair05.snoverlay` via `NSUserDefaults` / cfprefsd.
   - On change, specifiers post Darwin notification `com.ryannair05.snoverlay/prefsupdated`.
   - `Tweak.xm` `%ctor` registers a Darwin observer that relays the event to `NSNotificationCenter defaultCenter` on the main thread.
   - `SnoverlayOverlayViewController`, `SBFStaticWallpaperView`, and `XMASFallingSnowView` all observe this notification and update immediately without requiring a respring.
   - `SNOWRootListController` provides a "Respring" navigation bar button and specifier cell executing rootless `posix_spawn` with `ROOT_PATH("/usr/bin/killall")` `backboardd`.

## Preference keys (`com.ryannair05.snoverlay`)

| Key | Type | Root.plist default | Fallback / Behavior |
|---|---|---|---|
| `enabled` | bool | `true` | If `false`, removes subviews and cancels snow animations everywhere. |
| `wallpaperOnly` | bool | `true` | If `true`, window overlay is disabled (snow only on wallpaper). If `false`, window overlay is activated across all apps. |
| `highQuality` | bool | `false` | If `false`, uses `CAEmitterLayer`. If `true`, uses individual `UIImageView`s with `CABasicAnimation`. |
| `numSnowflakes` | integer (15–200) | `160` | Number of flakes in high-quality mode; emitter birth rate (`count >> 3`) in particle mode. |
| `snowFlakeType` | integer (0 or 1) | `0` | `0` = White snowflake (`XMASSnowflake.png`), `1` = Blue snowflake (`XMASSnowflake1.png`). |

## Build / install

Requires [Theos](https://theos.dev/) with `$THEOS` set and an iOS 15+ SDK.

```sh
make                                              # build
make package                                      # package rootless .deb (iphoneos-arm64)
make package install THEOS_DEVICE_IP=<device-ip>  # install over SSH, resprings SpringBoard
```

Makefile settings: `TARGET = iphone:clang:latest:15.0`, `ARCHS = arm64 arm64e`, `THEOS_PACKAGE_SCHEME = rootless`, and `GO_EASY_ON_ME = 1`. Never commit a device IP; pass `THEOS_DEVICE_IP` on the command line.

## Conventions and gotchas

- **ARC enabled (`-fobjc-arc`)**: Snoverlay 2 uses ARC throughout both the tweak and preferences bundle.
- **Rootless paths:** Never hard-code `/Library/...` for jailbreak assets. Always use `<rootless.h>` `ROOT_PATH_NS` or stage via `layout/`.
- **Windows must be scene-attached** on iOS 16+. Do not use standalone `initWithFrame:` for the SpringBoard overlay window.
- **Touch passthrough:** Ensure `_ignoresHitTest` returns `YES` and `hitTest:withEvent:` returns `nil` so the overlay never intercepts gestures.
