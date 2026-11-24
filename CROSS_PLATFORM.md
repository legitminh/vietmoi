# Sieuviet across iOS, macOS, Android, Windows, and Linux

Decision date: November 14, 2026. Status: architecture decided and initial shared
foundation, Android keyboard and native desktop adapters implemented. Updated
November 15, 2026: Linux X11 GTK/Qt tests pass on ARM64 and x64; Windows native
x64/ARM64 products cross-build, while Windows Swift/TSF runtime verification
remains pending. Interactive Windows testing is deferred at the user’s request.

## Implementation status

The repository now includes a Swift package referencing the original engine
sources, portable profile values separated from UserDefaults storage, one logical
binding lookup shared by the legacy Mac mapping and new HID-facing API, a public
Swift engine facade, and a C-callable dynamic library. C declarations are checked
against Swift implementations at compile time using `@c @implementation`.

This is the construction-engine boundary, not the full document/session contract
below. Android now consumes shared guide geometry/labels and uses a native editor
adapter with activation-time settings snapshots. Cross-host edit acknowledgements,
the full capability-aware session contract and migrating Apple clients to package
imports remain future work. `Desktop/common/Session.hpp` now shares desktop
routing/effects; native IBus, Fcitx 5 and Windows TSF adapters own document APIs.
See [desktop implementation, commands and limits](Desktop/README.md).
The Apple apps still compile the same shared files through their established
build paths. No phonetic or spelling implementation was copied into a platform.

From the `vietmoi` directory:

```sh
python3 scripts/test-portable.py
python3 scripts/test-package.py
SIEUVIET_DOCKER_CONTEXT=orbstack bash scripts/test-linux.sh
```

The first two commands are also intended for Linux/Windows hosts with Swift 6.3+
and Clang installed. Linux now passes them; Windows Swift execution is still unverified. `.swift-version` pins
the current development/test toolchain to 6.4.2. The Linux helper runs these suites
in the matching official Swift image, with read-only sources, writable build
outputs, and no container network access. It does not exercise desktop input.

Current verification: all seven legacy suites pass against the 24-choice map;
eight package tests cover 79,200 complete paths across both outputs; C and C++
each pass 200 ABI checks on macOS and Linux. Desktop policy checks pass against
the actual Swift dynamic library. The Linux adapters pass real IBus/Fcitx → GTK 3
and Qt 5 X11 typing tests on ARM64 and x64 (x64 under emulation). Android's nine installed-IME/JNI tests pass, including
79,200 native construction paths. ARM64 and x86_64 libraries build, and Mac/iOS
simulator app builds succeed. See [Android setup and tests](Android/README.md).

The shared vowel inventory is now 24 choices: oo on a, wê on n, wi on m, and no
wô/wư/wu. Final o is unchanged. Keymap schema 6 migrates old defaults while
preserving physical-key removals and actual custom overrides. Rendering rules
remain shared. Android uses the same Shift detector and symbol pages as Apple.

## Decision

Keep one Swift implementation of Sieuviet's behavior. Package the existing core
with Swift Package Manager and expose a small, versioned C interface for native
platform adapters. Apple targets import the same Swift package directly. Android
uses Kotlin with a JNI bridge; Windows uses C++/COM with Text Services Framework
(TSF); Linux uses IBus and Fcitx 5 adapters. Each adapter translates OS events and
text operations; it must not implement Vietnamese construction or spelling.

This is a technical choice based on the existing code and current tooling. Swift
has an official Android SDK and a supported C export attribute, `@c`, starting
with Swift 6.3. Windows also has official Swift toolchains. These capabilities
make reuse feasible. The Android IME/JNI integration is now verified on the
local emulator; Windows TSF loading remains an unverified gate. See [Swift C exports](https://www.swift.org/blog/swift-6.3-released/),
[Android SDK setup](https://www.swift.org/documentation/articles/swift-sdk-for-android-getting-started.html),
and [Windows toolchains](https://www.swift.org/install/windows/).

A Rust or C++ rewrite would replace a small, already tested engine and require
migrating both Apple clients. Do not introduce a second production engine. If the
portability gate below finds an unsolved distribution, memory, or runtime problem,
revisit the core language once, with measured evidence and the existing Swift
tests as the migration oracle.

## What the repository already shares

| Existing source | Responsibility | Planned treatment |
| --- | --- | --- |
| `Sources/Core/PhoneticBasis.swift` | Inventory, typed atoms, tones, NFC and text validation | Keep one implementation |
| `Sources/Core/StandardVietnamese.swift` | Quốc ngữ rendering | Keep one implementation |
| `Sources/Core/KeyboardEngine.swift` | Four rounds, previews, commits, undo | Keep engine; separate grid input and document-range helpers |
| `Sources/Core/ASCIIPlusMapping.swift` | Named bindings, migration, lookup | Keep maps/migration; remove Mac key-code dependency |
| `Sources/Core/ASCIIKeyboardLayout.swift` | Guide geometry and Mac key positions | Shared logical layout; Mac code translation moves to adapter |
| `Sources/Core/KeyboardProfiles.swift` | Profile model plus UserDefaults storage | Split portable model/migration from platform storage |
| `Sources/Core/KeyboardPreferences.swift` | Preferences and Shift tap detector | Share detector; inject preferences and physical observations |
| `Sources/Mobile/MobileInputSession.swift` | Touch routing and document reconciliation | Extract portable session policy with capability tests |
| `Sources/macOS/InputController.swift` | IMK events, editing, modifier recovery, history | Keep IMK mechanisms; gradually delegate common policy |

The iOS app and extension already compile the same core and mobile sources. The
Mac and iOS guide already share row definitions. Preserve this work.

The gaps are Mac key codes in shared structures, manual source lists in shell
scripts/Xcode generation, and different editing policies in Mac/mobile sessions.
For example, Mac retains up to 128 committed cycles; mobile tracks its latest
commit. Do not silently erase these differences while extracting a common session.
Document each capability and preserve current Apple behavior during migration.

## Boundaries that prevent duplication

```text
 Native keys / touch / focus / selection / settings snapshot
                         |
                 Native OS adapter
                         |
     Shared session: normalized events -> effects + guide state
                         |
     Shared engine, atoms, keymaps, rendering, migrations
                         |
                 Native OS adapter
                         |
           OS composition / commit / UI update
```

The shared library owns:

- Initial → onglide/core vowel → final → tone; unfinished phonetic previews;
  completion in sieuviet or quốc ngữ; NFC and exactly one completion space.
- Inventory, tone placement, all ASCII+/grid bindings, unavailable-key behavior,
  per-round Backspace, partial boundaries, and mode-switch policy.
- A guide model: stable key IDs, row positions, widths, current atom labels,
  enabled state, and mode. Native views render this model rather than carrying
  their own mapping tables.
- Settings validation, portable serialization and migration, and rules for when
  a new settings snapshot may become active. Keep a pending word on its existing
  configuration; make profile-switch boundary behavior explicit and tested.
- Shared editing decisions, composition ownership, bounded in-memory cycle
  metadata, and the conditions for attempting verified deletion.

Adapters own rendering, accessibility integration, OS lifecycle callbacks,
physical-key translation, persistence locations, signatures, installers, and
executing document effects. UIKit, Android Views, AppKit, COM, GLib, and Fcitx APIs
stay outside the core. Native views can differ in safe areas, themes, haptics,
and accessibility while consuming the same key/guide model.

Use a stable physical-position ID, such as a USB HID keyboard usage, instead of
Mac virtual key codes. The API must distinguish physical position, literal text,
and semantic commands. Touch sends the same stable position IDs or commands.
Keep existing profile labels (`q`, `;`, etc.) as US-position aliases when reading
schema 5; never reinterpret saved mappings as OS key codes. Test non-US layouts:
Sieuviet positions stay fixed while literal ASCII/native passthrough follows its
documented platform behavior.

### Shared session and host contract

Define normalized events for key down/up, modifiers and monotonic timestamps,
repeat, touch activation, Space, Backspace, cancel, clear, toggle mode, boundary,
focus changes, document observations, and settings updates. Responses include
consume/passthrough and ordered effects: set composition, commit, end composition,
restore an owned replacement, request native deletion/action, or verified cycle
deletion. The shared state also returns the current guide and phase.

Do not reduce the adapter contract to “replace the previous N characters.” Hosts
can reject edits, provide incomplete context, or move the caret asynchronously.
Tag events/effects with a session generation and operation ID; report edit success,
failure, and any available host revision back to the session. Ignore stale
callbacks and invalidate ownership on focus/selection changes. Model unavailable
observations explicitly. Serialize mutations on the host's required event thread;
do not make asynchronous network or disk calls while typing.

Capability flags describe surrounding-text access, reliable selection/ranges,
marked-text support, replacement/restoration, verified cycle deletion, native-key
forwarding, and key-release visibility. If a host cannot verify the text and
selection, clear must leave surrounding text intact. An unsupported operation is
reported explicitly and falls back to ordinary editing where safe. Keep the
physical-state workaround for Mac's missing releases in the Mac event adapter;
share the timestamp/chord tap detector. Prove isolated Left Shift tap support for
each desktop framework rather than adding a global keyboard hook.

### C interface

Expose opaque per-session handles and a deliberately small API: ABI version,
create/destroy, settings snapshot, dispatch event, acknowledge host effects, and
read state/guide/effects. Use fixed-width values, explicit enums, UTF-8 buffers
with lengths, and documented buffer ownership/lifetime. No Swift objects,
exceptions, platform ranges, or Swift `String` ABI cross this boundary. Export
through supported `@c`, with a checked C header and ABI contract tests.

Keep ranges in a named unit: UTF-8 bytes for transport lengths, UTF-16 offsets
where the host uses them, and explicit conversion for Unicode scalar/grapheme
operations. Never equate Swift character counts with Android/Windows offsets or
Linux surrounding-text offsets. Test combining sequences and emoji adjacent to
Vietnamese. One session owns one composition; changing focus cannot carry a word
into another editor. Keep global mode preference separate from composition state.

## Platform choices and initial support

| Platform | Implementation | Initial development/test environment |
| --- | --- | --- |
| iOS/iPadOS | Existing UIKit app and keyboard extension, direct Swift import | Existing simulator and physical iPhone |
| macOS | Existing AppKit/InputMethodKit, direct Swift import | This Mac and existing host tests |
| Android | Kotlin `InputMethodService`, native Views keyboard, shared library through a thin JNI bridge | ARM64 emulator on this Apple Silicon Mac; x86_64 emulator in CI |
| Windows | C++ TSF text service DLL and native settings/guide | Windows 11 ARM64 VM locally; Windows x64 runner and interactive VM |
| Linux GNOME | IBus engine adapter using its native API | Ubuntu LTS GNOME desktop VM, Wayland and Xorg sessions |
| Linux KDE | Fcitx 5 C++ addon using the same C library | KDE Plasma desktop VM, Wayland and X11 sessions |

Android's framework provides `InputMethodService` and `InputConnection`; use
composing-text APIs and explicit editor actions. Keep a practice screen, but test
the separately installed system IME in another editor process. Settings live in
the containing app, as on iOS. Start with Android 10/API 29 minimum as a product
target, current stable compile/target SDK, ARM64 devices, and x86_64 test builds;
confirm that complete toolchain/ABI combination in the portability gate.
[Android input-method documentation](https://developer.android.com/develop/ui/views/touch-and-input/creating-input-method).

Windows needs TSF integration, edit sessions, composition ranges, key sinks,
language-bar/mode state, and correct activation/deactivation. A key-replacement
utility is insufficient for this composition workflow. Build separate ARM64 and
x64 DLLs, match the consuming process architecture, and test x64 apps under ARM
emulation too. Initial support excludes 32-bit apps; adding them requires an x86
toolchain/runtime decision and matching TSF binary. Keep Swift initialization
outside `DllMain`. Validate secure fields, app-container access, registration,
runtime loading, upgrades, and uninstall in disposable VMs. Users choose their
default input source through Windows settings.
[Microsoft IME requirements](https://learn.microsoft.com/en-us/windows/apps/develop/input/input-method-editor-requirements).

Implement IBus first for GNOME, then Fcitx 5 for KDE. Both adapters call the same
library. This is a defined support matrix, not a claim that one “Linux build”
covers every compositor. Verify GTK, Qt, browser, Electron, and terminal clients
on both display protocols. Linux containers cover builds/unit tests; they do not
replace a desktop session. Publish native packages with their runtime dependencies,
starting with Debian/Ubuntu, then an RPM family after its desktop tests pass.
See [Fcitx addon development](https://fcitx-im.org/wiki/Develop_an_simple_input_method)
and its [Wayland integration notes](https://fcitx-im.org/wiki/Using_Fcitx_5_on_Wayland).

Preserve the current Apple deployment targets. Toolchain modernization must not
silently raise the minimum OS version. First Android release covers phones and
tablets, touch and attached hardware keyboards; Wear OS and Android TV need
separate UI work. Linux virtual consoles and arbitrary compositor combinations
are outside the initial desktop support matrix.

## Testing Android without owning a phone

1. Use an ARM64 Android Virtual Device on the Mac for daily work. Maintain images
   for the minimum supported API, a representative intermediate API, and current
   stable Android; include phone/tablet, rotation, light/dark, font scaling, and
   gesture/three-button navigation. Pin image and tool versions for reproduction.
2. Install and select the real IME in disposable test devices. Use instrumentation
   and UI Automator to tap its actual key views in a separate host app. Assert
   every round's visible composition and committed text. Typing expected Unicode
   directly into a field does not test the keyboard. Restore the previous IME in
   test teardown.
3. Use Android Device Streaming for interactive checks on a remote Pixel and
   Samsung before beta and release. A remote physical device supplies OEM/lifecycle
   coverage without purchasing a phone. First prove that the selected service
   permits enabling this third-party IME and testing its settings/lifecycle.
   [Device Streaming documentation](https://developer.android.com/studio/run/android-device-streaming).
4. Add automated physical-device runs through Firebase Test Lab if its device
   permissions support our IME fixture. Keep streaming/manual runs as the fallback
   when a hosted lab restricts input-source changes. Lab instrumentation supports
   Espresso/UI Automator, but this alone does not prove IME activation works.
   [Test Lab instrumentation](https://firebase.google.com/docs/test-lab/android/instrumentation-test).

Use synthetic phrases in lab tests. A borrowed physical device or volunteer beta
tester can cover real hardware-keyboard/long-session behavior if the remote lab
cannot. Emulator success alone is enough for development, but not the physical
device release gate. Remote lab setup needs account access and an agreed usage
budget at execution time; this plan does not provision services or incur charges.

## One test contract for all five operating systems

**Core tests:** retain all 39,600 construction combinations, NFC/control rejection,
tone anchors, both outputs, exactly-one-space completion, grid/ASCII+ equivalence,
custom keymaps and old schema migrations. Run the same suite natively on macOS,
Linux, Windows, and in Android native test binaries, not only on the Mac.

**Behavior fixtures:** introduce versioned, platform-neutral event traces with
reviewed expected phase, preview, effects, committed text, and mode after every
step. Include `msed → má `, `mlnd → muốn `, `rwos → răo / rau ` by output mode,
`xaqs → xoong `, round Backspace, unavailable letters, repeats, `m + Space`,
`m + toggle + y → my`, and semicolon punctuation outside round two. Expectations
must be explicit reviewed fixtures, not regenerated automatically from whichever
implementation is under test. Native adapters translate traces to their actual
events and compare observable effects.

**Host tests:** selected text and cancellation, first-round deletion, empty onset,
caret movement between rounds, delayed/missing acknowledgements, edit failure,
focus loss and editor teardown, configuration changes mid-word, process restart,
missing key-up/duplicate modifiers, Shift holds/chords, hardware repeats,
emoji/combining text, native shortcuts, secure fields, Return/Search/Send actions,
and bounded/unknown surrounding context. Test typing in two fields and two apps
to catch leaked state. Define and report capability-dependent results instead of
quietly skipping cases.

**Compatibility and performance:** exercise native plain/rich text, browser
inputs/textareas/contenteditable, Electron, and terminals on desktops; Android
EditText, Compose, WebView, browser and messaging-style fields. Measure cold start,
per-key processing, render latency, resident memory, and repeated activation.
Establish device-specific budgets in the first bridge build; protect Apple's
baseline and reject typing-path I/O or unbounded history growth. Keep keyboard
runtime offline with no persistent typed-text log or new network permission.

Every bug gets a shared trace if it affects behavior, plus an adapter regression
if it involves an OS callback. A linguistic change lands once in the Swift core;
all clients rebuild from that exact revision. An OS-specific rendering/callback
change remains local but runs the shared fixtures. Do not copy updated tables
manually between projects.

## Build and release discipline

Use one repository and a Swift package referencing `Sources/Core` in place; do not
copy those files into each platform directory. Split model/session/storage files
as needed. Gradle builds Android's wrapper and packages the matching Swift native
library; CMake builds the Windows/Linux adapters against the same exported header.
Lock compiler/SDK/NDK/JDK/Gradle/CMake versions as a tested tuple, with checksums
and reproducible commands. Android cross-compilation requires a matching open-source
host Swift toolchain and Swift SDK; the Xcode-provided compiler alone is not the
Android setup.
[Swift Android toolchain requirements](https://www.swift.org/documentation/articles/swift-sdk-for-android-getting-started.html).

| Stage | Required checks |
| --- | --- |
| Every relevant change | Core and shared-session suites on macOS/Linux/Windows; bridge ABI and fixture tests; all platform compile/package checks |
| Every keyboard behavior change | Real iOS extension simulator test; real Android IME emulator test; Windows TSF and Linux adapter contract tests |
| Scheduled or before release | Full API/device matrix; interactive Windows/Linux desktop host tests; Android remote physical devices; existing physical Apple checks |
| Release | Clean-machine install/enable/type/update/uninstall, runtime dependency loading, capability report, performance results and platform signing checks |

Build-only or headless hosted CI is not proof of OS-level IME compatibility.
Interactive desktop testing needs logged-in VM sessions or suitable desktop
runners. Existing Docker/VM applications on the Mac do not establish that those
environments are configured or usable. Windows x64 hosted builds supplement the
local ARM64 VM; do not assume the ARM64 VM validates every x64 host.

Record core revision, behavior-fixture version, C ABI version, settings schema,
adapter version and toolchain in each artifact and its test report. Expose the
core revision in app diagnostics. Make shared-core changes trigger every platform
pipeline. If a platform cannot pass, report it as unsupported for that release;
do not release an old behavior under the same compatibility claim. Installed
clients receive changes through their platform updates, not automatically at
runtime. Keep release signing separate from PR checks.

## Implementation order and exit gates

### 0. Prove portability before building new keyboards

- Add a Swift package and portable test entry points; separate storage from models.
- Compile/run the existing construction tests on Linux and Windows.
- Export a minimal C bridge; call it from C/C++ on all desktop targets and JNI on
  Android ARM64/x86_64. Check error handling, strings, ownership, and loader paths.
- Load the library in a minimal actual Android IME service and Windows TSF DLL;
  prove composition, one commit, repeated activation, and runtime deployment.
- Verify Android minimum API and native ABI support; measure binary size/startup
  and memory, especially whether the shared changes affect the iOS extension.
- Pin a working toolchain tuple and create reproducible commands. If these gates
  fail, resolve the common-core decision before growing platform-specific UIs.

### 1. Normalize events and consolidate shared policy

- Introduce stable position IDs and one guide model; preserve existing profile maps.
- Establish shared behavior fixtures, then extract the portable session using
  explicit host capabilities and edit acknowledgements.
- Migrate iOS and macOS separately. Keep the established Apple source identities,
  settings behavior, Shift recovery and safe-deletion checks.
- Exit: all current suites, actual iOS extension UI tests, and targeted physical
  Apple host checks pass. No production logic/table has been forked.

### 2. Deliver the Android keyboard

- Add Kotlin app/settings/practice view and `InputMethodService`, rendering the
  shared guide. Wire JNI, editor actions, composition, lifecycle, repeat and ABC.
- Add separate-process host fixtures and full IME emulator automation.
- Exit: both outputs/layouts, attached-keyboard behavior, all API/ABI gates,
  installation/update, and remote physical Pixel/Samsung checks pass.

### 3. Deliver Linux desktop integrations

- Ship IBus for GNOME first; then Fcitx 5 for KDE, sharing the same compiled core.
- Add package/dependency checks and a documented per-desktop setup path.
- Exit: declared Wayland/X11 + GTK/Qt/browser/terminal matrix passes in desktop
  VMs, including mode switching, focus boundaries, and safe deletion fallbacks.

### 4. Complete Windows TSF

- Expand the phase-0 proof into the full text service, native settings/guide,
  signed release packaging, architecture-specific registration and upgrade flow.
- Exit: ARM64/x64 native hosts and x64 emulated hosts pass, including composition,
  selection, shortcuts, modifier recovery and clean install/update/uninstall.

### 5. Qualify and maintain releases

- Run the shared and platform matrices against one core revision, record gaps,
  and publish only supported combinations after platform packaging is ready.
- For every later implementation change: update core/contract once, add a shared
  regression trace, rebuild all adapters, and run their integration gates.

These are dependency gates rather than calendar estimates. The first concrete
development task is phase 0; a successful Mac compile cannot substitute for it.

## Baseline and environment checked for this plan

On November 14, 2026, the existing seven command-line suites passed locally:
178,254 engine checks; 44,641 ASCII+ checks; 133,835 quốc ngữ checks; 34 profile
checks; 27 Shift checks; 294 Mac document-session checks; 43 mobile checks.
These include the then-current 44,550 composition paths. Native-session doubles are
not physical host-application verification. The later foundation work also passed
the package/C/C++ checks and Apple builds listed above. The installed Apple
keyboards were not replaced; no new physical-device or iOS UI test was run.

At the initial planning baseline, this host was Apple Silicon with Apple Swift 6.4.2. Android `adb` and emulator
binaries and platform SDKs 35/36 are present. The default AVD directory was absent,
and the emulator inventory command failed under the sandbox. No Swift Android
SDK or open-source host toolchain was found in the default checked locations;
the Windows VM inventory could not be read successfully. No Android AVD or
Windows/Linux desktop VM had been verified ready at that stage. The dedicated
Sieuviet_API_36 Android AVD and matching isolated Swift/NDK tools have since been
created and verified; see the current status above.

Historical environment issue, since resolved: OrbStack initially answered Docker requests as Linux/aarch64. An attempted pull
of the official `swift:6.4.2` image stalled; subsequent Docker inspection/version
requests also stopped responding. The test commands were interrupted without
restarting the user's runtime. OrbStack now works, and the pinned ARM64/x64
Swift images build the Linux core and adapters successfully. Existing user
containers were left alone. The X11 GTK/Qt integration matrix now passes;
Wayland desktop qualification, Windows Swift DLL/TSF runtime tests, physical
Android lab checks and public release packaging remain outstanding.
