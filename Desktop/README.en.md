[Tiếng Việt](README.md) · **English**

# siêu việt on Linux and Windows

These adapters use the original Swift engine through `Sources/CABI/include/sieuviet.h`.
There is no C++ copy of Vietnamese construction, spelling, vowel mappings, grid
inventory, or Shift timing. The 24-choice map includes **wê on n**, **wi on m**,
and the existing final **o**. `Desktop/common/Session.hpp` shares desktop routing,
repeat handling, undo, ASCII mode, partial boundaries and effect application.
`Design/brand.json` and `Design/content.json` generate desktop branding and
Vietnamese/English copy alongside the Apple and Android outputs.

## Verified status

- Linux ARM64 and x64: shared Swift `.so`, IBus executable and Fcitx 5 addon
  compile and run. Actual X11 daemon → GTK 3 / Qt 5 field tests cover both output
  spellings, ASCII+ / grid, unavailable keys, per-round undo, cancel, mode
  switching, selection replacement, safe cycle deletion and focus changes.
  x64 executes through container emulation on the Apple Silicon development host.
- Windows x64 and ARM64: native GitHub runners build the real Swift engine DLL,
  TSF DLL, settings/practice app and session tests. Both packaged engines pass
  32 desktop policy checks with the toolchain removed from the runtime search
  path. Packages include Swift and Visual C++ runtimes and registration scripts.
  **Actual TSF registration and interactive typing remain unverified.**
  Interactive Windows testing is deferred at the user's request. Downloads are
  development prereleases, with installation and qualification limits in
  [RELEASING.md](../RELEASING.md).
- GNOME/KDE Wayland sessions, browsers, terminals, other Linux distributions and
  physical Windows hosts remain qualification work. Xvfb tests are real toolkit
  integrations, not a substitute for that desktop/application matrix.

## Linux build and tests

Requires Swift from `.swift-version`, CMake, Ninja, Clang, pkg-config, patchelf,
IBus development files, Fcitx 5 development files, GTK 3 / Qt 5 development files,
Python 3 / PyGObject. `linux/Dockerfile` supplies these on the matching official
Swift Ubuntu 26.04 image. Keep the build distribution's glibc/Fcitx dependencies
in mind: these binaries are not a universal Linux package. Build on the target
supported distribution when packaging it.

From the project root, the reproducible Mac-hosted check is:

```sh
SIEUVIET_DOCKER_CONTEXT=orbstack bash scripts/test-desktop-linux.sh
SIEUVIET_DOCKER_CONTEXT=orbstack SIEUVIET_LINUX_PLATFORM=linux/amd64 bash scripts/test-desktop-linux.sh
```

The build image downloads development dependencies. Test containers have no
network and mount sources read-only; only their architecture-specific build
folder is writable. Existing containers and desktop input settings are untouched.
Outputs, test logs and settings screenshots are under `build/linux-desktop-*`.
The older `scripts/test-linux.sh` remains the smaller core-only check.

On Linux directly:

```sh
python3 scripts/build-linux.py
SIEUVIET_ENGINE_PATH="$PWD/build/linux-stage/lib/sieuviet/libSieuvietEngine.so" \
  build/linux-native/desktop-session-tests
python3 scripts/test-linux-desktop.py
python3 scripts/test-linux-settings.py
```

The default stage is usable for isolated tests. Its metadata contains absolute
stage paths. To stage a system installation with correct paths without writing
the host's `/usr`, use:

```sh
python3 scripts/build-linux.py --prefix /usr --destdir build/linux-system-root
```

Development archives from this verification run are at
`build/linux-desktop/sieuviet-linux-arm64-0.12.1-dev.tar.gz` and
`build/linux-desktop-x64/sieuviet-linux-x64-0.12.1-dev.tar.gz`. They contain the
system-prefix tree for the tested Ubuntu 26.04 environment, not a universal
Linux installer. The GitHub prerelease now also provides Ubuntu 26.04 `.deb`
packages for both architectures, with bundled Swift runtimes and dependency
metadata. Both packages passed installation and installed-engine smoke checks.

The staged tree contains `/usr/lib/sieuviet` with the engine and its Swift runtime,
IBus component metadata/executable, the Fcitx addon in Fcitx's configured library
directory, settings launcher and shared catalogs. Package/install that tree on a
matching Linux system. Staging alone does not enable a keyboard. Select **Sieuviet**
in GNOME's input sources for IBus or Fcitx 5 Configuration for Fcitx; use one
framework in a login session. Relaunch the framework or log in again after
installation. The build helper does not change the default input source.

Settings are at `$XDG_CONFIG_HOME/sieuviet/settings.conf` (normally
`~/.config/sieuviet/settings.conf`). `sieuviet-settings` provides native GTK
controls. Vietnamese is the default interface language. Settings refresh on
activation and at idle key boundaries, accommodating toolkit plugins that reuse
an input context. An in-progress word keeps its existing layout/output.

The IME uses native preedit and commits exactly once. Backspace undoes a round;
Escape cancels the owned preedit; a quick isolated Left Shift tap switches to
literal ASCII. Delete clears the current cycle or the last commit only when the
client's surrounding text, cursor, selection and recorded commit proof agree.
Unsupported or changed surrounding text safely refuses that deletion. Toolkit
reset discards stale pending state; it never replays text into a new field.
Focus finalization can differ with the toolkit's preedit/reset notifications.
Neither settings nor adapters log typing or contact a server.

## Windows build and tests

The implementation is an in-process C++ TSF text service with COM factories,
profile registration, key/edit sinks, owned composition ranges, selection-aware
replacement, native boundaries, safe last-commit deletion and a nonactivating
guide. It requests edit cookies before changing a document. It does not use
clipboard replacement, synthetic typing or global keyboard hooks. Engine loading
happens during TSF activation, outside `DllMain`.

The native cross-build check, using a verified LLVM-MinGW distribution, is:

```sh
python3 scripts/build-windows-cross.py --toolchain /path/to/llvm-mingw
```

It builds both architectures under `build/windows-{x64,arm64}-cross`. Each has
`windows/SieuvietTSF.dll`, `windows/SieuvietSettings.exe`,
`desktop-session-tests.exe`, PE architecture/import inspection and an explicit
`build-report.json`. The script cannot build or run a Windows Swift DLL on macOS.
The checked LLVM-MinGW release is 20261104; the macOS universal UCRT archive's
SHA-256 is `66cbd5178c4a71b0d473e68ede172f8eb7d15d023e67f39201d0a69e21f6bf3c`.

On Windows, install the matching official Swift toolchain and Visual Studio C++
build tools/Windows SDK. In a matching-architecture Developer PowerShell:

```powershell
.\scripts\build-windows.ps1 -Architecture x64
# Or native Windows ARM64:
.\scripts\build-windows.ps1 -Architecture ARM64
```

This builds the real Swift DLL and native targets, packages runtime DLLs, then
runs the desktop policy tests against that packaged library. These commands have
run successfully on native x64 and ARM64 GitHub runners. The smoke test must pass
before registration. Keep the package at its final installation path. Run its
`install.ps1` elevated with matching-architecture PowerShell; it smoke-tests the
engine again before `regsvr32`. It does not select Sieuviet as the default.
Choose Sieuviet with **Win+Space** and open `SieuvietSettings.exe` for settings and
a native practice field. `install.ps1 -Uninstall` removes TSF/COM registration;
close hosts before deleting the package. Settings remain in
`%APPDATA%\Sieuviet\settings.conf`.

Before calling Windows supported, run native Swift builds/loading, TSF
registration/unregistration, activation cycles, x64/ARM64 real-app typing,
selection/caret/focus changes, shortcuts, Shift/repeat, Unicode-adjacent deletion,
password fields and upgrade checks. Native Swift builds/loading and packaged
runtime smoke checks now pass on both architectures. 32-bit hosts and
AppContainer/Store applications are not qualified. Signed public installers
remain future work; unsigned development packages are published on GitHub.

## Making a keyboard change

1. Change the Swift engine/mapping once and add a shared reviewed fixture.
2. Regenerate design catalogs if content/branding changed.
3. Run `test-portable.py`, `test-package.py` and the desktop session checks.
4. Rebuild Apple, Android, Linux and Windows adapters from that same source state.
5. Run each native integration suite and record any platform that was not tested.

Keep OS event codes, UTF-8/UTF-16 conversion, composition ownership, focus and
installation in the adapters. Do not add linguistic tables to them. Apple hosts
still compile the original Swift files directly; migrating their package imports
and unifying the full acknowledged document-session contract remain separate work.
