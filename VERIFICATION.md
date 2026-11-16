# Linux and Windows adapters — November 15, 2026

- Implemented IBus, Fcitx 5 and Windows TSF using the same Swift engine and C ABI. Shared C++ desktop session policy handles ASCII+/grid routing, repeat, Shift, undo and effect application. No linguistic tables were copied into adapters. wê remains on n, wi on m, and final o is unchanged.
- Linux ARM64 and x64 (emulated on Apple Silicon), Swift 6.4.2 / Ubuntu 26.04: native engine, IBus and Fcitx addons compile/load. All four actual X11 framework/toolkit combinations (IBus/Fcitx × GTK 3/Qt 5) pass both outputs, both layouts, unavailable keys, undo, cancel, native selection replacement, verified cycle deletion, focus reset and Left Shift mode tests.
- Native settings read the shared brand/content catalogs, default to Vietnamese and persist English independently of layout/output. Qt's reused input context required refreshing changed settings at idle word boundaries. Unicode commit proof checks refuse deletion at another cursor/context even when the suffix is identical.
- Linux passes 158,458 engine, 39,692 ASCII+, 118,985 quốc ngữ, 40 profile and 27 Shift checks; eight package tests include 79,200 complete paths across outputs. C and C++ each pass 200 ABI checks. macOS passes the same eight package tests, both 200-check ABI clients, desktop policy checks, 296 native document-session checks and 46 mobile lifecycle checks.
- Windows x64 and ARM64: real PE TSF DLLs, settings/practice executables and session-test executables compile/link with verified LLVM-MinGW 20261104. PE machine/import inspection is saved beside artifacts. The native Windows Swift DLL build, its runtime loading, TSF registration and real-app typing have not executed on Windows. Interactive Windows testing is explicitly deferred by the user; cross-build success is not runtime qualification.
- Added native Windows build/package/registration helpers and Linux default/system-prefix staging, isolated Docker test commands and toolkit fixtures. See [desktop instructions and qualification gaps](Desktop/README.md). Neither a signed Windows release nor universal Linux support is claimed.
- Built, signed and installed macOS 0.12.0 (37) after the shared changes. The installer verifies the running `~/Library/Input Methods/VietMoi.app` executable, signature and matching build fingerprint while preserving input-source selection. No user Docker service or unrelated container was restarted.

Earlier dated entries below are historical verification results.

# Android keyboard and shared 24-choice mapping — 0.11.0, November 14, 2026

- Added a native Kotlin app, settings and test editor, plus an InputMethodService in a separate keyboard process. A thin C++ JNI bridge calls the original Swift engine; no Vietnamese mapping or spelling table was ported into Kotlin. Android consumes shared guide descriptors, symbol pages and the extracted common Shift tap detector.
- Implemented native composition/commit, partial boundaries, per-round and grapheme Backspace, repeat, selection restoration, guarded cycle deletion, focus changes, Return actions, ASCII/case/symbols, and physical keys. The containing app writes atomic settings; keyboard activation reads the base snapshot without backup repair or typing-path I/O. The manifest has no Internet permission.
- Prepared isolated, matched Swift 6.4.2/Android SDK/NDK r30 tools under build, verified the SDK checksum and the Apple-trusted/notarized toolchain package signature, and kept Xcode/system compiler defaults intact. ARM64 and x86_64 native libraries build; all 38 packaged libraries have at least 16KB LOAD alignment. The version/checksum-pinned Gradle wrapper produces the universal development APK.
- User confirmed wi on m, wê on n, and final o unchanged. Updated the common inventory to 24 choices in the supplied order, moved oo to a, and excluded wô/wư/wu. Schema 6 updates old defaults while preserving physical-key removals and actual custom overrides; old custom excluded atoms remain serialized but cannot route to another vowel.
- Passed 158,458 engine checks over 39,600 paths; 39,692 ASCII+ checks; 118,985 quốc ngữ checks; 40 profile checks; 27 Shift checks; 296 Mac session checks; 43 mobile checks. Seven package tests pass over 79,200 paths across both outputs, plus 177 checks each against the dynamic library from C and C++.
- All nine Android instrumentation tests pass after the remap, including 79,200 constructions through the actual Android Swift/JNI library, real IME typing in a separate host process, both outputs/layouts, settings transfer, selection cancellation, emoji deletion, field switching, partial Space/ABC, Return, symbols/case, physical Shift taps, column alignment and landscape typing.
- Rotation testing exposed the practice editor extending underneath the IME on Android 16; handling IME window insets fixed the incorrect taps. API-30 inset calls have Android-10 fallbacks. Mac and iOS simulator apps build with the updated common sources and 0.11.0 version. Existing physical Apple installations were not replaced in this pass.
- Final 0.11.0 build (Android versionCode 2) passes Android lint and the nine-test installed-IME suite, including unavailable grid-key handling. The dedicated emulator is restarted with its desktop window, Sieuviet selected, and a clean test editor.
- Current device qualification is the dedicated Android 16 ARM64 emulator. x86_64 compilation is verified; x86_64 execution, other API levels and physical/OEM checks remain release work. See Android/README.md for commands and limitations.

# Shared-core portability foundation — November 14, 2026

- Added `Package.swift` with the original core sources, an exported Swift engine facade, and a C-callable dynamic library. Split portable profile values/migrations from the UserDefaults-backed store. Legacy Mac key-code lookup and the HID-facing API now use the same logical bindings.
- Added a portable runner for the existing five core suites and a package/ABI runner. The C header is imported by Swift and checked against its `@c @implementation` exports. C and C++ clients link the actual dynamic library and test UTF-8 buffer sizing, nontruncating copies, invalid arguments, per-instance ownership, both output modes, and lifecycle commands.
- Passed all existing suites: 178,254 engine checks; 44,641 ASCII+ checks; 133,835 quốc ngữ checks; 34 profile checks; 27 Shift checks; 294 Mac session checks; 43 mobile checks. Five new package tests pass, including 89,100 complete construction paths across both outputs. C and C++ each pass 164 ABI checks.
- The Mac app and iOS simulator app compile successfully after the profile split and regenerated source membership. The installed apps were not replaced; physical-device and iOS UI tests were not rerun in this pass.
- Added the version-pinned Linux container test command. The initial Linux test attempt could not reach testing: the Swift image pull stalled and OrbStack's Docker daemon stopped responding to inspection requests. Only the test-related client commands were interrupted. Linux execution, Windows/Android loading, and native IME adapters remain unverified. See `CROSS_PLATFORM.md` for the full development/test plan and remaining phase gates.

# Native mobile keyboard appearance — build 5, November 14, 2026

- Removed the surface's solid background override so the system keyboard material continues behind the keys and system globe/dictation controls. Added neutral light/dark keycaps, regular-weight labels, subtle shadows, and immediate pressed states. Preserved every key frame, layout choice, and typing action.
- Replaced system-style buttons with shared custom key buttons and wrapped round rendering in performWithoutAnimation. Titles, images, and state changes have no crossfade or transition delay. Backspace hold/repeat timing remains intentional.
- Passed all 3 simulator UI tests (alignment/landscape, both outputs/editing, actual system extension) and 43 mobile composition/snapshot checks. Visually inspected light/dark practice keyboards and the real system-extension screenshot, including its seamless bottom material.
- Built, signed, installed, and launched 0.10.0 build 5 on the connected iPhone. Settings remain app-only and RequestsOpenAccess remains false.

# Read-only mobile settings — build 4, November 14, 2026

- Corrected the earlier assumption that a provisioning mismatch made App Groups unavailable to the free account. Apple’s current iOS capability table lists App Groups for Apple Developer (free), and Xcode provisioned the group after the Personal Team was selected for both targets. Signed profiles now contain group.com.minh.sieuviet.ios.
- Replaced shared Keychain settings with an atomic app-written JSON snapshot in that App Group. The keyboard reads only on activation, then uses cached enums while typing. It never initializes or writes the file. The app can exit and the saved configuration persists. RequestsOpenAccess is false and all Full Access instructions have been removed from the active interface/docs.
- Passed the physical iPhone settings-transfer test with Full Access disabled: app-selected quốc ngữ produces phở/rau; changing the app to sieuviet produces răo; app-selected grid4x8 produces má. Input/output controls remain exclusively in the containing app.
- Installed and launched build 4 on the iPhone. Verified its signature, both App Group provisioning profiles, and RequestsOpenAccess=false.
- Passed all 3 simulator UI tests and 43 mobile composition/snapshot checks. Added explicit tests for settings surviving the app object, cached typing without polling, refresh on activation, reading a read-only snapshot, and invalid-file fallback.

The build-3 entry below records the superseded approach and its failure; it is not the current security requirement.

# App-only mobile settings — build 3, November 14, 2026

- Moved input/output selection into the containing app’s Settings screen. No configuration picker remains on either live keyboard. The app offers ascii+/grid4x8 input and sieuviet/quốc ngữ output. Telex remains unavailable.
- Added one Codable input/output configuration and a shared Keychain item. The app alone writes it; the extension reloads it on activation and between words, preserving an in-progress word’s rules. No typed text or phonetic bases are shared or logged.
- The current free Personal Team profile signs the shared Keychain entitlement. The physical phone could not read it in the restricted keyboard sandbox; the simulator could. Read-only App Group provisioning was checked but the current profiles did not accept that entitlement. The installed build requests the iOS Allow Full Access switch for settings sharing. The code remains offline.
- Added dynamic grid rows using the existing shared engine, whole-word verified grid Clear, and full alphabet access in literal ASCII regardless of selected layout.
- Found and fixed UIKit returning nil for the declared-nonnull document identifier during teardown: check the public Objective-C getter before UUID bridging and ignore disconnected-client callbacks.
- Passed 37 mobile session checks and all three simulator UI tests, including settings changed only in the app propagating to the actual extension, both output modes, grid typing/Clear, Backspace, ASCII switching, portrait/landscape, and absence of live configuration pickers. Signed and installed build 3; physical settings-transfer confirmation is pending the user’s Allow Full Access switch.

# iPhone app and keyboard — November 14, 2026

- Added a native UIKit practice app plus an embedded custom keyboard extension. Both reference the existing core files and the same mobile surface/session; the compact guide rows are now shared with the Mac view. No engine, inventory, keymap, or spelling implementation was forked.
- Added output selection, inline marked phonetic previews, whole-word quốc ngữ conversion, per-round Backspace with touch repeat, partial-word preservation on Space/ASCII/boundaries, uppercase literal ASCII, two digit/symbol pages, Return, and system keyboard switching.
- No App Groups, Full Access, networking, external packages, or typing log. Added local UserDefaults privacy manifests to app and extension.
- Passed 27 mobile session/document lifecycle assertions, 294 Mac native-session checks, 44,641 mapping checks across 44,550 equivalent paths, and two in-app iPhone UI tests covering both outputs, editing, aligned columns, and landscape. Visually inspected the simulator layout.
- The actual simulator system-keyboard extension also passes its integration UI test and compact-height assertion: phở/rau, undoing an initial, and m → ASCII → y. Visual review found an oversized remote root; its height is now constrained on UIInputViewController.view, with the shared touch surface pinned inside it. The test invokes the embedded extension via a system-keyboard UITextView, rather than the in-app custom input view. A simulator helper selects the enabled extension without removing other keyboards, because globe taps otherwise cycle recent languages.
- Both simulator and arm64 iPhone builds succeed. Signed app and keyboard profiles were generated for the connected iPhone 14; signature verification succeeds and the app was installed. Personal Team provisioning expires November 21, 2026. After the user enabled Developer Mode and trusted the development identity, devicectl successfully launched the installed app on the physical iPhone. The final compact-height build was signed and installed as an update under the same identity.

# Version 0.10.0 — November 14, 2026

- Replaced final u with o (/w/), including the physical o key, guide, grid inventory, and saved default mappings. Keymap schema 5 preserves custom positions, removed defaults, and an occupied custom o key. Core vowel u and onglide w remain distinct atoms.
- Renamed vietstandard to quốc ngữ, migrating the old saved selection. Both layouts retain phonetic previews until the fourth-round tone choice renders and commits the completed basis. Space, Shift switching, and host flushes keep partial phonetic text without converting it.
- Read the Wikipedia spelling and Hanoi-final sections linked in README. The user resolved the conflicting prototype exceptions in favor of normal phonetic spelling. The renderer applies f/ph, z/gi, shared gi+i, c/k/qu, g/gh, ng/ngh, contextual o/u and i/y glides, open/closed diphthongs, Hanoi front-vowel codas, and main-vowel tone placement. Stored phonetic atoms are preserved; unusual constructions remain allowed.
- Passed 133,835 quốc ngữ checks across all 44,550 completed paths, 178,254 Sieuviet checks, 44,641 ASCII+ mapping checks, 34 profile migration/persistence checks, 27 Shift checks, and 294 native controller checks including delayed caret metadata, partial-word preservation, conversion timing, translated-range deletion, and the prior same-field Shift fix. Built and installed 0.10.0 (35); its installed signature verifies and executable matches the tested build. Native protocol-client tests do not constitute physical host-application confirmation.

# Version 0.9.3 — November 13, 2026

- Added partial commits: Space preserves the preview and inserts one space; a Shift mode toggle preserves it without a separator. Exact native-session regressions cover `m + Space → m ` and `m + Shift tap + y → my`, plus partial vowel/final previews in both input layouts.
- Reproduced a first-round Backspace failure with a host that acknowledges the marked caret asynchronously. Track the intended caret after setMarkedText and accept delayed selection metadata only when the live marked range confirms composition ownership. Backspace now undoes the initial through either raw events or macOS editing commands, including replacement selections and multi-character initials.
- Host flushes, focus changes, Return/Tab, navigation, shortcuts, and punctuation preserve visible partial text. Escape/Clear remain explicit cancellation. Partial abbreviations do not create a completed phonetic basis. The confirmed hardware HID Shift-state correction is retained.
- Passed 283 native document-session/Shift checks, 178,254 engine checks over all 44,550 complete paths, 44,637 ASCII+ mapping checks, 74,412 standard-renderer checks, 27 profile checks, and 27 Shift timing checks. Built and installed 0.9.3 (34); the installed signature verifies and its executable matches the tested build. Host-client regressions simulate callback behavior; physical application confirmation of this release remains separate.

# Version 0.9.2 — November 13, 2026

- Moved the oo vowel choice from comma to semicolon, active only in the combined-vowel round. Comma is ordinary punctuation in every round.
- Aligned all guide rows to the same columns: a below q, semicolon below p, and Shift below q. The oo guide cell occupies the physical semicolon position after l.
- Version-4 keymaps migrate saved comma/oo defaults to semicolon while retaining custom overrides and removals. Input order and the Shift hardware-state fix are unchanged.
- Passed 44,637 ASCII+ mapping checks across all 44,550 paths, 249 controller checks, and 27 profile checks. Built and installed 0.9.2; the installed signature verifies and its executable matches the tested build.

# Version 0.9.1 — November 13, 2026

- Applied the updated combined-vowel key map exactly, including q=wă, a=wa, w=wiê, y=iê, t=ă, g=a, p=ươ, and l=uô. Comma still selects oo.
- Changed the four rounds to initial → onglide + core vowel → final → tone. The third round previews the entire unaccented syllable; the fourth tone choice accents the core, commits the word, and adds one space. Backspace before tone selection undoes the final.
- Updated both input layouts, guide/settings text, basis contract, examples, and regression sequences. Samples: mged → má, rtus → rău, tgus → tau, iwes → khwiê, x,qs → xoong (each followed by a space).
- Keymaps now serialize as version 3. Version-2 default vowel positions adopt the new layout while actual overrides and explicitly removed keys remain intact. Earlier profile migration remains supported.
- Passed 178,244 engine assertions across all 44,550 paths; 44,636 ASCII+ mapping/equivalence assertions; 249 native controller assertions; 26 profile migration/persistence assertions; 27 Shift assertions; and 74,412 standard compatibility assertions. Installed 0.9.1; its signature verifies and the installed executable matches the tested build.

# Version 0.9.0 — November 13, 2026

- Changed the four rounds to initial → combined onglide/core vowel → tone → final + space. The second round selects a typed VietnameseVowelAtom; previews are unaccented until the third round. Backspace undoes a whole round.
- Applied the supplied initial, combined-vowel, and final maps, with s/d/f/j/k/l for ngang/sắc/huyền/hỏi/ngã/nặng and e for an empty final. Initial ph is now f; only w is an onglide; finals u/i denote /w,j/.
- Added the explicitly requested oo atom on comma. Comma is modal only during the combined-vowel round; it remains ordinary punctuation elsewhere. The guide shows it beside m while keeping Shift beneath q. Tone goes on the second o, as in soóc.
- Reviewed the supplied Wikipedia phonology article and verified lexical examples xoong, boong, and soóc. The user chose to permit every listed combination rather than enforce phonotactic filtering. No full-dialect or complete-lexicon coverage claim is made.
- New keymaps serialize with version 2. Legacy profiles remain intact; actual initial/final custom overrides migrate where applicable, while incompatible old vowel/tone maps adopt the new layout.
- Passed 178,241 engine assertions, including all 44,550 supplied construction paths; 44,635 ASCII+ assertions, including physical-key/grid equivalence for every path; 249 native controller assertions; 22 profile migration/persistence assertions; 27 Shift assertions; and 74,412 compatibility-renderer assertions.
- Confirmed the final display notation with the user: finals remain u/i, so standard rau is Sieuviet rău.
- Retained the physically confirmed hardware-HID key-state fix, control-character guards, selection deletion, mode persistence, and the left-aligned guide bottom row. Installed 0.9.0, verified the installed signature, and confirmed its executable matches the tested build.

# Version 0.8.4 — November 13, 2026

- Shifted the entire ASCII+ guide bottom row left by one key cell. Its Shift/flag cell now shares q's x position; the middle row keeps its stagger.
- Built and locally signed the app. Physical bindings and composition behavior are unchanged.

# Version 0.8.3 — November 13, 2026

- The physical 0.8.2 retest still failed. Its public modifier trace showed both Shift transitions continuing to reach IMK after selected-text Delete, but mode no longer changed. Delete's key-down arrived without its key-up.
- A targeted native probe then confirmed `key=51 combined=true hardware=false` on this Mac while Delete was released. The tap detector was retaining this key because the default key-state provider queried `.combinedSessionState`, which includes logical/synthetic sources, rather than the hardware table.
- Changed the production key-state provider to `.hidSystemState`. This lets the existing held-key reconciliation remove the logically stuck Delete and preserves chord rejection using real hardware state. No global observer, event injection, or new permissions were added.
- Replayed missing Delete key-up plus duplicate Shift transitions in both modes, with four consecutive toggles per text client. Passed 243 native document-session assertions and 27 Shift timing/preference assertions; the signed 0.8.3 build is installed. The user confirmed the same-field select/delete/Shift sequence now works in both modes. Temporary diagnostics were disabled after confirmation.

# Version 0.8.2 — November 13, 2026

- Added a failing native-session regression for Shift+selection → missed Shift release → host selection deletion → repeated Left Shift taps, starting in both Sieuviet and literal ASCII. A cached Right Shift flag previously disqualified every later tap until the input session was reactivated; a cached Left Shift flag also prevented the next press from starting a fresh tap.
- Reconcile both cached Shift sides from side-specific flagsChanged snapshots, and clear stale modifier/tap state when an unshifted key/mouse event and the physical key state both show release. Genuine holds and chords keep their existing behavior.
- Explicit nonempty selections now take the host's normal Backspace/forward Delete path before cycle clearing in either mode. This also fixes ASCII+ swallowing forward Delete on selected text.
- Added selection/deletion coverage for both modes, both layouts, both Shift sides, both Delete keys, mouse selection, missing releases, repeated taps within one field, and intact neighboring text. Passed 233 native-session assertions and 27 Shift-detector/preference assertions. The signed installed binary matches the built binary.
- Opt-in ShiftDiagnostics log only lifecycle/modifier/editing metadata, with no text or printable keycodes. Physical post-install verification is pending; the original NSLog diagnostic was redacted by macOS, so no physical root-cause claim is based on that trace.
- The earlier Chrome explanation was a source-level hypothesis and does not explain all instances. This release fixes a reproduced session-state defect without global event monitoring or new permissions.

# Version 0.8.1 — November 13, 2026

- Swapped only the ASCII+ initial bindings: physical z now selects z; physical j selects ch. Both native routing and guide labels derive from that map. Examples: zwae → za + space, jwao → chao + space.
- Passed 93,634 ASCII+ assertions, 168 native controller assertions, and the signed macOS build.
- Investigated Notework using its local source and the running application inventory. The installed Notework window is a Chrome PWA (`com.google.Chrome.app.npfegmlojobknojmjmdegilnhjgpmbbe`). Its app handlers do not intercept standalone Shift. Chromium's Cocoa keyEvent method forwards non-keyDown events to the web renderer and returns before interpretKeyEvents. Sieuviet currently receives Shift only via IMK flagsChanged callbacks; therefore this Chromium path explains the missing Shift-only toggle. This is a source-level diagnosis, not a captured physical event trace in Notework.
- Chromium source: https://chromium.googlesource.com/chromium/src.git/+/HEAD/content/app_shim_remote_cocoa/render_widget_host_view_cocoa.mm (keyEvent:wasKeyEquivalent:, non-keyDown early return before interpretKeyEvents).
- No Notework source, dependency, or global-input permissions were changed. Reliable Shift-only switching in this host requires a native modifier-observation path independent of Chromium; that is not implemented in this mapping update.

# Sieuviet verification — November 13, 2026

## Version 0.8.0 phonetic basis and control-character boundaries

- Added the serializable `VietnamesePhoneticBasis` contract documented in `viet.phonetic.basis`. Each cycle stores explicit initial, onglide, core vowel, tone, and final atoms before rendering. The latest completed basis and bounded editing history stay in memory.
- Replaced vietmoi output with Sieuviet, migrating saved profile names automatically. The tentative inventory now uses z instead of gi, removes qu and the previously appended vowels, adds w onglide and w/j finals, and keeps tone on the configured core-vowel character. Every completed cycle adds one separator space.
- ASCII+ maps named atoms independently of inventory offsets; per-profile serializable maps drive both event routing and guide labels. The new w onglide/tone keys are q/t/o/p/a/g (ngang/sắc/huyền/hỏi/nặng/ngã). Grid mode exposes these choices on its final row without using its Shift or Clear positions.
- Engine and IMK boundaries reject generated controls/private-use function characters. Unknown C0/C1 event payloads are consumed without insertion; recognized editing/navigation keycodes retain command behavior. The reported intermittent host-specific U+0008/escape insertion has not been independently reproduced, so these safeguards and regression results do not establish every application's live behavior.
- Passed 374,434 engine assertions across all 93,600 Sieuviet paths, 93,634 ASCII+ assertions including equivalent bases/displays for every path, 166 native document-session assertions, 17 profile persistence/migration assertions, 27 Shift assertions, and 70,362 existing standard-renderer assertions. Standard spelling remains deferred; this release does not claim full standard support for the revised phonetic inventory.
- Installed the signed 0.8.0 update and verified its installed plist version and deep signature. A disposable NSTextView synthetic-event probe bypassed IMK and inserted literal test keys, so it was not accepted as live validation. Physical host typing still needs confirmation.
- The macOS source identity remains `com.minh.inputmethod.VietMoi` for update compatibility. Version 0.8.0 builds and is locally ad-hoc signed.

The following entries are historical verification notes for earlier implementations and inventories.

# MVP verification — October 30, 2026

## Version 0.7.1 committed-text Shift+Delete command route

- The live diagnostic contained no raw-event entry after a completed cycle, confirming macOS was not calling `handleEvent:` in that state. InputMethodKit's SDK documents a separate `didCommandBySelector:client:` keybinding route for responder commands such as `deleteBackward:`.
- VietMoi now handles shifted `deleteBackward:` and `deleteForward:` through that route, checks physical Shift state directly, and calls the same deletion function used during active composition. Unshifted commands return false to the host.
- Native regressions cover both command selectors outside composition and ordinary unshifted passthrough. Controller checks pass 148, grid checks pass 95,499, ASCII+ checks pass 95,527, standard-output checks pass 95,634, and Shift timing checks pass 27. Version 0.7.1 builds successfully with a valid plist and signature.

## Version 0.7.0 inline tone composition preview

- Tone selection is now visible immediately in marked text. Raised spacing indicators are separate from committed vietmoi suffixes; ngã uses U+02DC SMALL TILDE, producing `nh˜` after `nh + ngã` without combining the mark onto h.
- All marked composition is sent as an explicitly single-underlined attributed string. Standard output removes the temporary spacing indicator when a nucleus arrives and places the tone on the correct vowel.
- Added engine, standard-preview, native marked-text, underline, cancellation, and Backspace regressions. Grid checks pass 95,499, standard-output checks pass 95,634, native controller checks pass 145, ASCII+ checks pass 95,527, and Shift timing checks pass 27. Version 0.7.0 builds successfully with a valid plist and signature.

## Version 0.6.4 denied-document fallback and diagnostics

- Fixed a concrete fallback bug: recent commit history was cleared before Shift+Delete tried to use it. The handler now preserves contiguous recent commits through the attempt and reconstructs the deletion range from them when both attributed and plain document reads fail.
- Shift detection now also queries the combined-session physical state of left/right Shift. A regression types `abc nmq` through literal ASCII, disables both document-reading APIs, and still deletes to `abc`.
- Added a diagnostic containing only keycode, Shift-state booleans, handled status, and selection range; typed text is never logged. This will distinguish event-delivery failures from document-operation failures during physical testing.
- Native controller checks pass 143, standard-output checks pass 95,633, ASCII+ checks pass 95,527, and Shift timing checks pass 27. Version 0.6.4 builds successfully with a valid plist and signature.

## Version 0.6.3 real-client Shift+Delete handling

- The reported live failure exposed two assumptions not covered by the earlier mock: Delete carrying `.shift` on its own event and attributed substring access always being available. Shift is now detected from tracked left/right modifier state as well as event flags, and document reads fall back to `string(from:actualRange:)`.
- Added regressions where Shift arrives in a separate flagsChanged event and Delete has no Shift flag, plus a client that rejects attributed text but supports plain strings. Both exact deletion examples still pass for Backspace and forward Delete.
- Native controller checks pass 142 and Shift timing checks pass 27. Version 0.6.3 builds and installs successfully with a valid plist and signature. Automated live UI verification was unavailable because macOS ScreenCaptureKit failed to start; physical confirmation is still required.

## Version 0.6.2 corrected Shift+Delete range

- Corrected the deletion boundary to include the single separator space immediately before the alphabetic cycle. Both `abc nmq   |` and `abc nmq|` now become `abc|` in one handled event.
- Shift works with both macOS Backspace keycode 51 and forward Delete keycode 117. The operation still cancels partial composition first, works in every mode, treats spaces without an earlier cycle as a no-op, and leaves punctuation cases to the host.
- Native controller checks pass 140, standard-output checks pass 95,633, and Shift timing checks pass 27. Version 0.6.2 builds successfully with a valid plist and signature.

## Version 0.6.1 standalone i/y spelling

- A completed standard-output syllable whose only segment is i now uses orthographic y. All tones emit `y, ý, ỳ, ỷ, ỹ, ỵ`.
- The rewrite waits until the final choice is known and applies only with no onset, medial, or coda; `ín` remains `ín`. Native ASCII+ verifies `e e i e → ý `.
- Standard-output checks pass 95,633, native controller checks pass 138, grid checks pass 95,497, and ASCII+ checks pass 95,527. Version 0.6.1 builds successfully with a valid plist and signature.

## Version 0.6.0 standard êi/uêi spelling

- Added standard-output `êi → ây` and `uêi → uây`, including the explicitly requested `buêi → uây` display exception. `bêi` now emits `bây`.
- Direct formatter families cover all six tones. Native ASCII+ regressions verify `b s r i → uây ` and `b w r i → bây `.
- Standard-output checks pass 95,625, native controller checks pass 137, grid checks pass 95,497, and ASCII+ checks pass 95,527. Version 0.6.0 builds successfully with a valid plist and signature.

## Version 0.5.9 macOS input-source icon

- Replaced the generated V artwork with the requested `★` and retained the existing `tsInputMethodIconFileKey` / `tsInputMethodAlternateIconFileKey` registration.
- Added `TISIconIsTemplate = true` so macOS can recolor the icon for its current menu appearance.
- The built `MenuIcon.tiff` is 16×16 with alpha. The plist validates, the star was visually inspected at enlarged scale, and the app's deep signature verifies.

## Version 0.5.8 inline settings and annotation-free guide

- Moved the settings gear to the upper-left, on the same line as the live composition/cycle display. The gear-only profile view remains 44×44 points.
- Removed the footer view and its key explanations entirely. Both key blocks moved down 28 points into the reclaimed area; grid4x8 is now 584×288 points and ASCII+ is 512×200 points.
- Native controller checks pass 135 and ASCII+ checks pass 95,527. Version 0.5.8 builds successfully with a valid plist and signature.

## Version 0.5.7 previous-cycle deletion and compact guide

- Removed the visible Tap Shift footer annotation. The flag key retains its accessibility label. Removed the virtual keyboard's profile/title row and reduced both visible panel heights by 28 points.
- Shift+Backspace works before mode-specific handling: it cancels partial input and deletes trailing U+0020 spaces plus the contiguous Unicode-alphabetic cycle to their left. Version 0.6.2 extends that range through the preceding separator space. If punctuation is immediately left of the caret, the event passes to the host unchanged. Spaces with no earlier cycle are a handled no-op.
- Native controller checks pass 135, including grid4x8, literal ASCII, accented Vietnamese, multiple spaces, document-start text, punctuation fallback, and partial composition. ASCII+ checks pass 95,527; standard-output checks pass 95,610; and Shift timing checks pass 27. Version 0.5.7 builds successfully and its plist and signature validate.

## Version 0.5.6 inline mode-switch artwork

- The supplied `united-states-svgrepo-com.svg` is bundled unchanged as `UnitedStatesMode.svg` and loaded directly by AppKit for vector rendering.
- The flag replaces the text inside grid4x8's existing bottom-left mode key. ASCII+ now places the same flag key before `z`, on the same bottom row as the rest of that input block.
- ASCII+ checks pass 95,527 and native controller checks pass 125. Version 0.5.6 builds successfully; the packaged SVG matches the source resource byte-for-byte and the app's deep signature verifies.

## Version 0.5.5 persistent literal ASCII mode

- Shift-selected literal ASCII is now process-wide input-method state rather than per-document engine state. Input-box changes cancel unfinished composition and reset Shift press tracking, but preserve the selected mode.
- Literal ASCII hides the floating panel completely. A subsequent isolated Shift tap returns to Vietnamese mode and restores the guide (or gear-only view when that profile has its virtual keyboard disabled).
- Native controller checks pass 125, including stored ASCII mode through deactivate/activate and the stored return to Vietnamese. Grid checks pass 95,497; ASCII+ checks pass 95,527; standard-output checks pass 95,610; and Shift timing checks pass 27. Version 0.5.5 builds successfully.

## Version 0.5.4 ASCII+ pre-vowel remap

- Remapped the three pre-vowel/tone rows to `w e r y u i` (empty), `s d f h j k` (u), and `z x c b n m` (o).
- The six positions mean ngang, sắc, huyền, hỏi, nặng, ngã, so the explicit empty-pre-vowel + ngã case maps to `i` while the engine's established tone indices remain unchanged.
- Grid checks pass 95,497; profile checks pass 13; ASCII+ checks pass 95,527 including all 95,472 grid-equivalence paths; standard-output checks pass 95,610; Shift checks pass 27; and native controller checks pass 120. Version 0.5.4 builds successfully and its bundle plist and ad-hoc signature validate.

## Version 0.5.3 host-key passthrough

- Keys outside the active modal input space now pass through in ASCII+ and grid4x8. This covers Space, comma, period, slash, semicolon, quotes, brackets, backslash, grave, minus, equals, unused numbers, function keys, and repeating punctuation.
- Host keys cancel incomplete composition before passing through. Letters that belong to ASCII+ overall but are invalid in the current phase remain consumed without advancing.
- Native controller/Shift checks pass 120, including passthrough in both modes, cancellation, function keys, repeat behavior, and modal repeat suppression. Grid checks pass 95,497 and Shift preference checks pass 27. Version 0.5.3 builds and installs successfully; registration returned 0 and the installed signature verifies.

## Version 0.5.2 c + u spelling correction

- Fixed standard output rewriting `c + u + a + hỏi` as `quả`; it now preserves the selected components as `cuả`. The explicit `qu` onset still produces `quả`.
- Added direct formatter and native controller regressions. Standard-output checks pass 95,610, controller/Shift checks pass 69, grid checks pass 95,497, and ASCII+ checks pass 95,508. Version 0.5.2 builds and installs successfully; registration returned 0 and the installed signature verifies.

## Version 0.5.1 Shift tap correction

- User reported that quick Shift taps did not switch modes in 0.5.0.
- Addressed two cancellation paths: stale held-key observations after a missing ordinary key-up, and unconditional tap cancellation on composition-flush callbacks. Fresh Shift presses reconcile prior held-key observations using the current macOS key state; real chords remain disqualified.
- 27 timing/preference checks and 67 controller checks pass, including missing key-up simulation, recovery after a chord, genuinely held keys, and composition flushes between modifier events. Version 0.5.1 builds successfully.
- Version 0.5.1 installed successfully and its signature verifies. The user confirmed that physical Left Shift taps now switch to ASCII and back after typing.

## Version 0.5 Shift tap/hold

- Left Shift switches modes only on an isolated release before the configured duration. Holds and chords do not switch. Key-up tracking covers keys held before Shift and Shift released while another key is down. Device-specific flags distinguish left/right Shift overlap.
- Shift combinations pass through as host modifiers. Shift chords cancel partial composition; holding Shift alone preserves it. Literal ASCII retains case.
- Global timing preference defaults to 0.20 seconds (QMK's default, not a universal OS standard), accepts 0.01–5 seconds, persists across launches, and has a Reset control.
- 24 timing/preference checks and 63 document-session/Shift interaction checks pass. These include threshold boundaries, custom duration, both release orders, pre-held keys, both Shift keys, navigation, punctuation, shortcuts, focus changes, and existing text-composition behavior.
- Version 0.5.0 builds and installs successfully; native registration returned 0 and the installed signature verifies.
- Visually inspected the installed settings window: Left Shift tap limit shows 0.20 seconds with a Reset button and the tap/hold explanation. Concurrent user interaction prevented automated editing of the field; persistence/reset behavior is covered by the preference tests. The user subsequently reported quick taps did not switch; see 0.5.1.

## Version 0.4 standard Vietnamese output

- Both input modes honor the selected vietstandard output setting. Composition displays standard spelling and accents; the fourth input commits one syllable plus one space.
- Explicit spelling/tone cases cover tay/tai, khuya, nghiêng, nghĩa, giếng, quả/của, quý, thuyền, yến, yêu, muốn, được, and modern hoà/thuỷ/khoẻ tone placement.
- Standard formatter: 95,608 checks pass, including 95,472 inventory paths checked for NFC encoding and exactly the selected tone. These inventory paths include linguistically invalid combinations and are not a dictionary-coverage claim.
- Existing grid tests pass 95,497 checks; ASCII+ tests pass 95,508. Native document-session tests pass 35, including saved output selection, standard marked text, repeated syllables and spaces, output changes while composing, clearing, cancellation, selection restoration, and ASCII bypass.
- Version 0.4.0 builds and installs successfully; native registration returned 0 and the installed signature verifies.
- Inspected the installed app through its popup gear. The active profile is ascii+ → vietstandard, and settings shows the updated standard-output description.
- Automated TextEdit input in a new disposable document arrived literally as `tqei`, matching the earlier automation limitation. The user subsequently confirmed physical typing of `tqei`, `iaue`, and `qqkq` correctly produces `tay khuya nghiêng ` with the installed version.

## Version 0.3.2 standalone hỏi

- Vietmoi hỏi now emits U+003F (`?`) as a separate suffix character rather than U+0309 combining hook above. Grid and ASCII+ guides show the same standalone symbol.
- ASCII+ `mrae` produces `ma?`. Native document-session checks verify three separate characters and cycle clearing with the new suffix.
- Grid tests pass 95,497 checks, ASCII+ tests pass 95,508, and native document-session tests pass 24. App build succeeds.

## Version 0.3.1 compact guide and visibility

- User confirmed that version 0.3 ASCII+ typing and popup work.
- Empty final now uses e; initial o selects tr. Empty onset uses e too, resolving the source document's conflicting assignment of o to both tr and empty.
- ASCII+ guide is 512×256 points (previously 760×368), with only three staggered letter rows, action labels, and no physical-key annotations. Unused letter positions remain blank to preserve the keyboard shape.
- Both guide backgrounds are drawn at 76% opacity; action text stays fully opaque.
- Each profile saves Show virtual keyboard. Off displays only a 44×44-point settings gear. Older saved profiles decode with visibility enabled.
- Visually inspected the actual guide/settings views in an isolated native preview: initial and medial/tone layouts, gear-only popup, gear reopening setup, and checkbox changing from on to off. Preview preferences are separate from the installed app's preferences.
- ASCII+ tests pass 95,508 checks, native document-session tests pass 22, and profile persistence/migration tests pass 13. App build succeeds.
- Version 0.3.1 installed in the existing per-user Input Methods bundle; native registration returned 0 and the installed signature verifies. U.S. input remains selected after installation.

## Version 0.3 ASCII+ input

- Uses the updated source document: initial o selects the empty onset; medial/tone rows are qwerty/asdfgh/zxcvbn; nucleus u selects ia; the stray m nucleus is removed.
- Preserves the previous prototype's extra o/u/ua/uô nuclei on spare c/l/w/v keys.
- ASCII+ tests: 95,506 checks pass, including all 95,472 comparisons with grid-mode output.
- Existing grid engine tests: 95,497 checks pass.
- Native document-session adapter: 22 checks pass, including ASCII+ Space/final handling, tone entry, ia, m as a phoneme, Fn+Backspace, mode changes during a partial cycle, literal ASCII switching, and ignored unmapped keys.
- Build and per-user installation succeeded; native TIS registration returns 0.
- After unlocking, the setup UI was inspected and ASCII+/vietmoi selection was confirmed. Automated TextEdit key entry produced literal `mqa `; the user subsequently confirmed actual typing and the popup work.
- Removed automatic setup reopening on application activation; explicit app reopening and the popup gear still open setup. Rebuilt and installed; the installed signature verifies.

## Version 0.2 setup UI

- Built and installed the native app with display name viet; retained the original input-source identifier.
- First launch displayed the setup window with Default keyboard, grid4x8 input, and vietmoi output.
- Visually inspected setup and the popup's lower-right settings gear.
- Clicked the popup gear and verified that setup reopened.
- Added Keyboard 2, selected telex and vietstandard in its dropdowns, verified both menus' exact options, then removed that temporary profile. The default configuration remained intact.
- Profile persistence/deletion tests: 10 checks pass, including independent saved dropdowns, selected-profile restoration, deletion fallback, last-profile protection, and malformed-preference recovery.
- Existing native document-session tests: all 12 checks pass.
- At version 0.2, other input/output engines were saved configuration only; version 0.3 adds ASCII+ typing. Telex and vietstandard remain future work.

## Version 0.1 input method

- Swift build succeeds on this Apple Silicon Mac.
- Local app-bundle signature verifies with `codesign --verify --strict`.
- Installed bundle is approximately 156 KB (system frameworks and development build cache excluded).
- `TISRegisterInputSource` returns 0 and the native input-source list contains VietMoi.
- System Settings lists VietMoi under Vietnamese; added to the user's Input Sources.
- Live TextEdit typing produced `ma ma´xin ` from the corresponding four-key sequences.
- User independently confirmed that `r111` produces `ma ` and displays the popup.
- Visually inspected the native 8×4 popup, including current key actions and reserved bottom-corner controls.
- Engine: 95,497 checks pass, including all 95,472 inventory paths.
- Document-session adapter: 12 checks pass, covering insertion, clear, cancellation, restored selection, moved caret, mode switching, cached marked-range metadata, and delayed selection updates after commit.

## Remaining compatibility work

Automated live cycle-clear checks in TextEdit did not reliably remove the current cycle after repeated input-method replacements. The same operations pass against the protocol-conforming test document. The implementation conservatively refuses deletion when host text/caret data does not verify. This remains an application-level check to complete; use ordinary Backspace where cycle clear is unavailable.

Repeated development installs can leave a stale macOS input-method connection. The installer switches away before replacing VietMoi; users should select it again afterward. If an old composition or literal keys remain, log out and back in. This is a local, ad-hoc-signed prototype, not a notarized public release. Windows is not implemented.
