[Tiếng Việt](README.md) · **English**

# siêu việt for Android

Native Android app and system keyboard, with the original Swift engine compiled
for ARM64 and x86_64. Minimum Android 10/API 29; compiled/targeted at API 36.
The current development device is an Android 16/API 36 ARM64 emulator on the Mac.
Other API levels and physical/OEM devices still need release qualification.

## Using the keyboard

The app's **Thử bàn phím** screen uses the actual installed input method in a
separate process. **Cài đặt** selects ascii+/grid4x8, siêu việt/quốc ngữ, and the
interface language. Vietnamese is the default; English is available for learners.
There are no configuration pickers or instruction strips on the keyboard itself.

- Four rounds: initial → onglide/vowel → final → tone, then exactly one space.
- Both modes use phonetic previews; quốc ngữ converts only on tone completion.
- Backspace undoes a round, then deletes native text by grapheme. Hold to repeat.
- Space and ABC preserve partial words. Escape cancels an owned composition.
- ABC, uppercase, and shared number/symbol pages support literal input. Return
  follows the editor's action or inserts a newline.
- A short isolated Left Shift tap toggles literal mode on an attached keyboard;
  holds, chords and Right Shift retain native behavior. Repeated atom keys do not
  advance rounds. The tap detector is shared with the Apple implementation.
- Grid Clear deletes only the latest commit whose surrounding text verifies.
  Unknown context never permits deletion of an assumed prior word.

The revised vowel map has 24 choices: **oo → a, wê → n, wi → m**, with wô/wư/wu
removed. Final **o** is unchanged. Examples of physical ASCII+ key sequences:

| Keys | sieuviet | quốc ngữ |
| --- | --- | --- |
| msed | má | má |
| frej | fở | phở |
| rwos | răo | rau |
| imoj | khwỉo | khuỷu |
| xaqs | xoong | xoong |

One space follows each completed word. Touch users select the displayed atoms.
When using the Mac keyboard with the emulator, use the Mac's ABC input source so
the desktop input method does not transform keys before Android receives them.

## Build and test on this Mac

Commands below run from the repository's `vietmoi` directory. Android SDK 36,
build-tools 36.0.0, the emulator, and the Google Play ARM64 API 36 image are already
installed in `~/Library/Android/sdk`. Override `ANDROID_HOME` for another location.
Java 25 and the checksum-pinned Gradle 9.8.1 wrapper build AGP 9.5.0's native Kotlin
support; there are no third-party UI runtime dependencies.

```sh
python3 scripts/setup-android-native.py
python3 scripts/build-android.py --tests
python3 scripts/android-emulator.py
python3 scripts/test-android.py --no-build
```

The bootstrap puts the matching open-source Swift 6.4.2 compiler, Android Swift
SDK and NDK r30 under `build/android-tools`. It verifies the SDK checksum and
toolchain package signature. It extracts the compiler locally, without changing
Xcode, system toolchains or shell defaults. Initial downloads are several GB.
The Android SDK/system image itself must be installed separately.

The build helper packages both `arm64-v8a` and `x86_64` by default. Use
`--abis arm64-v8a` for an ARM64-only APK. It invokes the same native build from
Gradle, so changing shared sources also rebuilds the Android engine.

Artifacts:

- App: `Android/app/build/outputs/apk/debug/app-debug.apk`
- Tests: `Android/app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk`
- Native libraries/manifest: `build/android-native/<abi>/`
- Test result: `build/android-instrumentation.log`

These are locally development-signed builds, not a published store release.
The universal debug APK is approximately 129 MB because it contains the Swift,
Foundation/ICU and C++ runtimes for two architectures. ARM64 alone is about 65 MB.
All 38 packaged native libraries have at least 16 KB LOAD alignment.

Native tools can be overridden with `SIEUVIET_SWIFT_TOOLCHAIN` (root containing
`usr/bin/swift`), `SIEUVIET_SWIFT_SDKS` (artifact-bundle directory), and
`ANDROID_NDK_HOME`. The bootstrap currently automates macOS; other build hosts
must supply those paths themselves.

## Emulator and manual installation

The helper creates only **Sieuviet_API_36**, serial **emulator-5556**, under
`build/android-avd`. It leaves other emulators and physical devices alone.
`--headless` supports automated tests; omit it for the visible window. Use
`--restart` to restart this same AVD with a window after headless testing.
Emulator diagnostics are in `build/android-emulator.log`.

Install the APK, enable **Sieuviet** in Android keyboard settings, then select it
using the app's **Select keyboard** button. In the dedicated emulator, equivalent
commands are:

```sh
adb -s emulator-5556 install -r Android/app/build/outputs/apk/debug/app-debug.apk
adb -s emulator-5556 shell ime enable com.minh.sieuviet.android/.SieuvietInputMethod
adb -s emulator-5556 shell ime set com.minh.sieuviet.android/.SieuvietInputMethod
adb -s emulator-5556 shell am start -n com.minh.sieuviet.android/.MainActivity --ez openKeyboard true
```

No Google account or paid service is needed for the local emulator.

## Shared code and validation

`Sources/Core` owns atoms, default mappings, schema migration, rendering, guide
rows/labels, symbol pages and Shift detection. `Sources/Bridge` exposes the C ABI.
Android's C++ JNI bridge only transfers handles/UTF-8 and calls that ABI. Kotlin
owns Android Views, editor operations, lifecycle and scan-code translation; it
has no Vietnamese spelling or custom mapping table.

The containing app writes one atomic settings snapshot. The IME reads its base
file at activation and uses an in-memory configuration. Typing makes no settings
reads/writes. The APK has no Internet permission, analytics or typing-history log.

The test runner installs the real IME and checks actual native editor text.
Tests include both outputs/layouts, every phase, partial boundaries, settings
transferred between processes, safe Clear, selection restoration, focus changes,
emoji deletion, native Return, symbols/case, physical typing/Shift, aligned columns
and rotation. Native JNI tests execute all **79,200** complete paths across the two
outputs. The JUnit suite restores the previous enabled/default IME state.

```sh
python3 scripts/test-android.py
python3 scripts/test-package.py
python3 scripts/test-portable.py
```

Pass `--serial DEVICE_ID` to target another explicitly selected test device, or
`--class fully.qualified.Class#method` for a targeted regression. The runner checks
JUnit's output because `adb am instrument` can return exit code zero for failed
tests. Remote physical Pixel/Samsung checks remain a release gate; emulator and
x86_64 compile success are not physical-device compatibility evidence.
