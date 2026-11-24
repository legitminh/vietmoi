[Tiếng Việt](RELEASING.md) · **English**

# siêu việt 0.12.2 (build 39)

Development builds for macOS, iOS, Android, Windows and Ubuntu. Shared linguistic
sources are in `Sources/Core`; native hosts and keyboard adapters use that engine.
The repository includes all source needed to build the apps and keyboards.

## Downloads and installation

| Download | Requirements and installation |
| --- | --- |
| `macos-universal.zip` | macOS 13+, Apple Silicon or Intel. Ad-hoc signed, without Developer ID notarization. Copy `VietMoi.app` to `~/Library/Input Methods/`, open it, then add **siêu việt** in System Settings → Keyboard → Text Input. macOS may require explicit local approval or a new login. Existing users should use the repository's `scripts/install.sh` to preserve registration and restart the input method. |
| `ios-unsigned.ipa` | iOS/iPadOS 16+. Optimized device app with its keyboard extension. **Unsigned: re-sign both app and extension with your Apple account and matching App Group entitlement before installation.** This is not an App Store, TestFlight, or directly installable OTA release. For the simplest development installation, open `iOS/VietMobile.xcodeproj` in Xcode and select your signing team for both targets. Enable the keyboard in Settings → General → Keyboard → Keyboards. |
| `android-universal-debug.apk` | Android 10+ (API 29), ARM64 or x86_64. Development signed. Install the APK, allow installation from the chosen source when prompted, and enable/select siêu việt in Android keyboard settings. No Internet permission or Full Access is needed. |
| `windows-x64.zip` / `windows-arm64.zip` | Matching Windows 10/11 architecture. Extract to a permanent directory. Includes the real Swift engine/runtime, TSF adapter, settings app and engine smoke test. Run `install.ps1` from an elevated, matching-architecture PowerShell, then choose siêu việt with Win+Space. `install.ps1 -Uninstall` removes registration. These unsigned development packages have native engine smoke tests; interactive TSF typing remains unqualified. |
| `ubuntu-26.04-amd64.deb` / `ubuntu-26.04-arm64.deb` | Ubuntu 26.04 with matching architecture. Run `sudo apt install ./sieuviet-*.deb` with the single package matching your machine. Includes IBus/Fcitx 5 adapters, settings, Swift engine/runtime and dependency metadata. Enable siêu việt through IBus or Fcitx 5 after installation; use one framework per session. Log in again if necessary. Other Ubuntu releases are not qualified. Remove with `sudo apt remove sieuviet`. |

Vietnamese is the default in the bundled documentation and installer messages. Use `./install.ps1 -Language en` on Windows or `SIEUVIET_LANGUAGE=en bash scripts/install.sh --no-build` when installing from source on macOS for English messages.

Settings and typing remain local. Interface language defaults to Vietnamese;
English is selectable in the app. See each platform's README for usage and tests.

## Reproduce the builds

On macOS with Xcode, Android SDK and the pinned Swift/Android tools installed:

```sh
python3 scripts/test-portable.py
python3 scripts/test-package.py
bash scripts/test-controller.sh
bash scripts/test-mobile.sh
bash scripts/package-apple-android.sh
```

The Android bootstrap is `python3 scripts/setup-android-native.py`. Build tools
and Gradle caches are local to `build/`. See `Android/README.md` for prerequisites.
The APK uses the local Android development signing key, which is not published.

On the matching Ubuntu 26.04 architecture, using `Desktop/linux/Dockerfile`:

```sh
python3 scripts/build-linux.py --prefix /usr --destdir build/linux-system-root
python3 scripts/package-ubuntu.py
```

Windows uses `.github/workflows/windows-build.yml` or a matching-architecture
Visual Studio Developer PowerShell with Swift from `.swift-version`:

```powershell
./scripts/build-windows.ps1 -Architecture x64
# Native Windows ARM64:
./scripts/build-windows.ps1 -Architecture ARM64
```

Run the native desktop integration suites described in `Desktop/README.md`.
Full macOS host, physical mobile, Windows interactive, and Wayland compatibility
qualification remains separate from successful compilation and engine checks.

## Publish

Commit the local source to `legitminh/vietmoi`, run the Windows workflow for that
commit, and collect both verified native packages alongside the local builds in
`build/releases`. Include this installation guide, third-party notices and
`SHA256SUMS`. Publish version `v0.12.2` as a prerelease while these signing and
qualification limits apply. Never publish development signing keys, provisioning
profiles, SDKs, build caches, emulator data, or personal settings.
