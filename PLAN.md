# Linux and Windows adapters — November 15, 2026

- [x] Implement IBus and Fcitx 5 adapters using the original Swift/C ABI engine.
- [x] Share desktop key routing/effects, ASCII+/grid selection and repeat/Shift policy.
- [x] Add native Linux and Windows settings with shared Vietnamese/English catalogs.
- [x] Build/run Linux ARM64 and x64 libraries/adapters; pass real daemon → GTK/Qt X11 typing tests.
- [x] Cross-build/link native Windows x64 and ARM64 TSF DLLs and settings/practice apps.
- [x] Add Windows native Swift/runtime build and registration scripts with mandatory pre-registration smoke tests.
- [x] Run shared regression and C/C++ ABI checks on Linux and macOS; update and verify the installed Mac app.
- [ ] Run the provided Windows Swift build, packaged runtime loading, TSF registration and actual-app tests on Windows. Interactive testing is deferred at the user's request.
- [ ] Qualify GNOME/KDE Wayland, browsers/terminals and native physical Windows hosts before declaring release support.
- [ ] Produce signed Windows release installers and distribution-specific Linux packages.

Commands, artifacts and explicit limits: [Desktop/README.md](Desktop/README.md).
The historical phases below retain their full release gates; implementation does not complete qualification.

# Android keyboard and shared vowel map — 0.11.0

- [x] Build a native Android settings/practice app and actual system IME in a separate process, backed by the original Swift engine through JNI.
- [x] Share guide rows/labels, symbols, and Shift detection; keep Android editor mechanics native.
- [x] Support both outputs/layouts, owned composition, partial boundaries, per-round undo, safe Clear, ASCII/symbols, editor actions and attached keyboards.
- [x] Build ARM64 and x86_64 libraries with a pinned local toolchain and repeatable build/test helpers.
- [x] Pass nine Android instrumentation tests, including every complete construction in both output modes and actual IME rotation/focus/settings tests.
- [x] Adopt the 24-choice vowel list: oo/a, wê/n, wi/m, with wô/wư/wu removed and final o preserved.
- [x] Migrate schema-5 default keymaps to schema 6 while preserving custom overrides and physical-key removals.
- [x] Update shared, Mac, mobile and Android fixtures; pass Apple regression suites and build both Apple apps.
- [ ] Qualify minimum/other Android API levels and remote physical Pixel/Samsung devices before public release.

# Cross-platform development — November 14, 2026

Architecture and testing decisions are in [CROSS_PLATFORM.md](CROSS_PLATFORM.md).
Keep one Swift core; introduce a versioned C bridge and native Android, Windows,
IBus, and Fcitx 5 adapters. The milestones below are not yet complete.

Foundation completed locally: a Swift package sharing the original core, portable
regression runner, storage/model separation, a checked C ABI with stable HID
positions, and direct C/C++ dynamic-library tests. Android IME/JNI loading and
deployment now pass; the remaining phase-0 gates concern Windows and Linux.

- [ ] Phase 0: prove package portability, native C/JNI loading, Android IME and Windows TSF composition, runtime deployment, and toolchain compatibility.
- [ ] Phase 1: normalize key IDs, share session/guide policy, add shared behavior fixtures, and migrate Apple clients without regressions.
- [ ] Phase 2: build the Android app/IME; validate emulators and remote physical devices without requiring phone ownership.
- [ ] Phase 3: build IBus/GNOME and Fcitx 5/KDE integrations; validate Wayland/X11 desktop hosts.
- [ ] Phase 4: complete Windows TSF, architecture-specific installers, and native host validation.
- [ ] Phase 5: qualify releases with the same core revision and platform compatibility evidence.

# Native mobile keyboard appearance — build 5

- [x] Keep the existing aligned/grid layouts and shared app/extension surface.
- [x] Use the system keyboard material and neutral adaptive keycaps.
- [x] Remove title/image crossfades and make pressed-state feedback immediate.
- [x] Pass 3 simulator UI tests and 43 mobile checks; inspect light/dark and extension screenshots.
- [x] Sign, install, and launch build 5 on the connected iPhone.

# Read-only mobile settings snapshot — build 4

- [x] Remove Full Access and shared Keychain settings.
- [x] Use an app-written App Group snapshot, read by the keyboard only at activation.
- [x] Verify Apple’s capability table: App Groups are supported by free accounts.
- [x] Select the Personal Team in Xcode for both targets and refresh the missing App Group provisioning.
- [x] Pass the physical iPhone settings-transfer test with RequestsOpenAccess=false.
- [x] Pass all 3 simulator UI tests and 43 mobile session/snapshot checks, including cache behavior and app-object lifetime independence.
- [x] Install and launch build 4 on the phone; verify both signed profiles carry the App Group and RequestsOpenAccess is false.

# App-only iPhone input/output settings — build 3

- [x] Remove configuration controls from both practice and system keyboards.
- [x] Add an app Settings screen for ascii+/grid4x8 input and sieuviet/quốc ngữ output.
- [x] Keep one shared settings value; the extension only reads it, between words.
- [x] Validate shared Keychain signing under the existing free development profile.
- [x] Test physical-device restrictions: Full Access is needed for the shared Keychain route; the current profile did not provision App Groups.
- [x] Handle UIKit returning nil for its declared-nonnull document identifier during client teardown.
- [ ] Finish integration checks and install the completed settings update on the phone.

# iPhone app and additional keyboard

- [x] Reuse core sources and share aligned guide rows between Mac and mobile.
- [x] Add one UIKit touch surface used by a practice app and keyboard extension.
- [x] Support both outputs, marked phonetic previews, abbreviations, ASCII, digits/symbols, and round-aware Backspace.
- [x] Keep the original extension offline without Full Access or paid App Group capabilities (app-only settings in build 3 require the Full Access switch for shared settings).
- [x] Add a reproducible Xcode project and build/install scripts for free development signing.
- [x] Pass mobile session tests, in-app portrait/landscape UI tests, and Mac regression checks.
- [x] Install and launch the development-signed app on the connected iPhone 14.
- [x] Verify the actual system-keyboard extension through its native text proxy: quốc ngữ output, per-round undo, and partial text across ASCII switching.

# Quốc ngữ completion and final o — 0.10.0

- [x] Replace the final u atom/key with o, retaining vowel-round u and onglide w.
- [x] Rename vietstandard to quốc ngữ and migrate saved output choices and default final mappings.
- [x] Render only completed bases; keep partial previews and abbreviations phonetic.
- [x] Read Wikipedia spelling/Hanoi rules and resolve the conflicting older prototype exceptions with the user: use normal phonetic spelling.
- [x] Implement contextual consonants, onglides/offglides, open/closed nuclei, Hanoi codas, and main-vowel tone placement.
- [x] Verify every complete construction, native editing, profile migrations, and physical mappings.
- [x] Build, sign, and install 0.10.0; verify the installed executable matches the tested build.

# Partial words and first-round deletion — 0.9.3

- [x] Preserve abbreviations on Space, mode switch, and ordinary host composition boundaries.
- [x] Undo the initial with Backspace even when a host delays its marked-text caret acknowledgement.
- [x] Handle native editing-command callbacks as well as raw Backspace events.
- [x] Retain hardware-based Shift recovery, explicit cancellation, and complete phonetic-basis behavior.
- [x] Verify controller regressions, core paths, mapping, and Shift detection; build and install.

# Updated vowel positions and tone last — 0.9.1

- [x] Apply the supplied 27-choice combined-vowel map, retaining oo on comma.
- [x] Use initial → combined vowel → final → tone, committing on tone selection.
- [x] Preserve unaccented final preview, core tone anchoring, and per-round Backspace.
- [x] Migrate saved defaults while retaining actual custom overrides/removals.
- [x] Verify every input path plus native editing/Shift and profile regressions.

# Four-round combined-vowel update — 0.9.0

- [x] Read the phonology reference and clarify mapping/coverage decisions.
- [x] Use initial → onglide + core vowel → tone → final + space.
- [x] Apply the supplied maps and s/d/f/j/k/l tone row; use e for empty final.
- [x] Add oo on comma beside m, with contextual punctuation handling and a second-o tone anchor.
- [x] Preserve typed basis state, configurable named atoms, and legacy profile migration.
- [x] Enumerate all 44,550 construction paths and retain controller/Shift regression coverage.
- [x] Keep all listed choices available instead of filtering by phonotactics.

# Selection/deletion Shift recovery — 0.8.2

- [x] Reproduce stale modifier state after selection/deletion in native-session tests.
- [x] Recover both Shift sides from fresh event/physical snapshots.
- [x] Preserve native selected-text deletion for both Delete keys in both modes.
- [x] Verify 233 native-session and 27 Shift timing/preference assertions; build, sign, install.
- [x] Confirm the user's physical select/delete/toggle sequence in the same field with 0.8.3.
- [x] Correct the actual key-state source: use hardware HID state rather than the logical combined table, which the physical trace/probe showed retaining Delete as down.

# Current work — Sieuviet 0.8.0

- [x] Introduce a stored, Codable phonetic basis before text rendering.
- [x] Use initial → onglide + tone → core vowel → final + space.
- [x] Apply the tentative inventory, including z, w onglide, and w/j finals.
- [x] Put tone inside the core atom and retain pre-core tone preview.
- [x] Separate named atoms, physical keymaps, and display formatting; persist optional per-profile ASCII+ remaps.
- [x] Reject generated controls and unexpected raw control payloads; preserve native editing commands.
- [x] Migrate vietmoi output profiles to sieuviet and enumerate all 93,600 revised paths.
- [ ] Collect host-application confirmation of the intermittent control-character report after updating.
- [x] Revisit standard spelling after Sieuviet input is confirmed (completed in 0.10.0).

The plan below is historical; earlier inventories and tone-suffix behavior are superseded.

# VietMoi macOS MVP

1. [x] Implement a dependency-free four-phase engine and physical 32-key map.
2. [x] Implement a native InputMethodKit controller with inline marked text and commit on input four.
3. [x] Display a non-activating 8×4 panel near the caret; update actions at each phase.
4. [x] Implement Shift mode switching, per-component Backspace, Escape cancellation, and verified cycle clearing; validate document operations with a protocol-conforming test client.
5. [x] Build an ad-hoc-signed app bundle, install in the user's Input Methods folder, and register with TIS.
6. [x] Validate engine coverage, build/signature, input-source discovery, and actual typing in a native text field.
7. [ ] Follow up on live cycle-clear behavior in host apps; automated TextEdit checks were unreliable after hot replacement. Do not treat protocol-client tests as full application compatibility verification.

MVP decisions: Swift core for a single-platform prototype; no external runtime. Preserve specification ordering and append o/u/ua/uô. Tone suffixes are custom notation, not standard Vietnamese spelling. No automatic phonotactic validation. ASCII mode allows literal m; Backspace removes characters. No capitalization. Windows TSF and standard-spelling conversion are subsequent work.

## Version 0.2 — setup UI

- [x] Provide a native app window named viet, shown on first launch and on explicit reopen.
- [x] Add a saved list of keyboard profiles with a default keyboard, add/remove controls, and selected profile.
- [x] Add the requested input and output dropdown choices; retain grid4x8/vietmoi as the typing engine and explain the other choices are saved configuration only.
- [x] Hide or close setup without terminating the input method.
- [x] Add a clickable gear below the virtual grid to reopen setup.
- [x] Install a launcher at `~/Applications/viet.app` while preserving the existing input-source identifier.
- [x] Validate native UI controls and profile persistence; retain passing document-session tests.

## Version 0.3 — ASCII+ input

- [x] Use the corrected ASCII+ onset, medial/tone, nucleus, and final bindings with the original four-stage cycle.
- [x] Switch the popup to a full ANSI/QWERTY layout with per-phase actions.
- [x] Apply the selected profile's input mode during native typing; reset incomplete input on mode changes.
- [x] Retain literal ASCII switching and use forward Delete/Fn+Backspace for cycle clear without reserving m.
- [x] Preserve the original MVP's additional o/u/ua/uô nuclei on documented spare keys.
- [x] Verify explicit examples, complete component coverage, grid/ASCII+ output equivalence, and native document-session behavior.
- [x] Build, locally sign, install, and register version 0.3.
- [x] User confirmed live ASCII+ popup/typing works; automated TextEdit input was not a reliable verification path.

## Version 0.3.1 — compact guide

- [x] Use e for the empty final, o for tr, and e for the empty onset to resolve the conflicting onset mapping.
- [x] Display three letter rows without physical-key annotations; shrink the panel and make both guide backgrounds translucent.
- [x] Save virtual-keyboard visibility per profile, retaining the settings gear when hidden and preserving older saved profiles.
- [x] Verify the native compact/gear-only views, settings access, updated mapping tests, and preference migration.

## Version 0.4 — standard Vietnamese output

- [x] Render structured syllables with standard spelling, tone placement, and NFC text.
- [x] Handle ei → ay, uia → uya, i/y and diphthong forms, ng/ngh, g/gh, c/k, gi, and qu.
- [x] Apply the saved output type to both input modes, marked text, and four-key commits with a trailing space.
- [x] Verify representative spellings, all six tones, Unicode invariants across the inventory, mode changes, cancellation, and cycle clearing.
- [x] Build the updated native app and document usage and remaining dictionary/phonotactic limits.
- [x] Install and inspect settings; user confirmed live standard-output typing of tay, khuya, and nghiêng.

## Version 0.5 — Shift tap versus hold

- [x] Switch modes on an isolated short Left Shift release; keep long holds and chords as normal Shift.
- [x] Track key releases and modifier sides, including either chord release order and keys held before Shift.
- [x] Add a global seconds field and Reset at the bottom of settings, with a compiled 0.20-second default and persisted custom values.
- [x] Preserve literal character case and pass Shift combinations to the host.
- [x] Verify timing boundaries, mode switching, composition behavior, shortcuts, focus changes, and preference validation.
- [x] Install the signed local build and inspect the timing controls in settings.
- [x] Correct the reported tap failure; user confirmed physical taps switch both ways after typing in version 0.5.1.
- [ ] Obtain separate physical-key confirmation of long holds and shifted-character behavior; controller tests cover both.

## Version 0.5.2 — preserve c + u

- [x] Restrict `qu` spelling to the explicit `qu` onset; preserve a selected `c/k` onset and `u` medial.
- [x] Add formatter and native-session regressions for `cuả`, while retaining explicit `quả` coverage.

## Version 0.5.3 — host-key passthrough

- [x] Pass keys outside the active input mode through to the host in ASCII+ and grid4x8.
- [x] Cancel partial composition before passthrough while retaining phase-invalid modal-key handling.
- [x] Verify punctuation, Space, unused numbers, function keys, and repeat behavior in both modes.

## Version 0.5.4 — ASCII+ pre-vowel remap

- [x] Move empty-medial tone choices to `w e r y u i`, u-medial choices to `s d f h j k`, and o-medial choices to `z x c b n m`.
- [x] Keep engine tone indices stable while honoring the explicit `∅ + ngã → i` mapping.
- [x] Update examples and verify complete grid/ASCII+ equivalence plus native controller behavior.

## Version 0.5.5 — persistent literal ASCII mode

- [x] Preserve the Shift-selected ASCII/Vietnamese mode across input-box activation and deactivation while cancelling unfinished composition locally.
- [x] Share mode across InputMethodKit controllers so changing text clients cannot reset it.
- [x] Hide the entire floating panel in literal ASCII and restore it only after Shift returns to Vietnamese mode.
- [x] Add native controller regressions for focus changes and both mode transitions.

## Version 0.5.6 — inline mode-switch artwork

- [x] Bundle the supplied U.S. flag SVG without rasterizing it.
- [x] Replace grid4x8's Shift/ASCII text with the flag in the existing bottom-row key.
- [x] Add the same flag key immediately before `z` on ASCII+'s bottom input row.
- [x] Verify the asset is packaged unchanged and the resulting app signature is valid.

## Version 0.5.7 — previous-cycle deletion and compact guide

- [x] Remove the visible Tap Shift annotation while retaining accessible labeling for the flag key.
- [x] Make Shift+Backspace cancel partial input and delete the preceding alphabetic cycle plus its trailing spaces in every mode.
- [x] Leave punctuation cases to normal host Backspace behavior. (The initial separator-preserving range was superseded in 0.6.2.)
- [x] Remove the redundant keyboard/profile title row and shrink both guide layouts by its height.
- [x] Verify grid, literal ASCII, Unicode, whitespace, punctuation, and partial-composition deletion cases.

## Version 0.5.8 — inline settings and annotation-free guide

- [x] Move the settings gear to the upper-left of the live cycle-state row.
- [x] Remove the bottom key-help display and every remaining visible Tap Shift annotation.
- [x] Shift both input blocks into the reclaimed space and reduce each panel height by another 28 points.
- [x] Retain the 44×44 gear-only view when a profile's virtual keyboard is disabled.

## Version 0.5.9 — macOS input-source icon

- [x] Replace the previous V menu artwork with the requested filled star (`★`).
- [x] Register the icon as a macOS template image for adaptive menu rendering.
- [x] Verify a transparent 16×16 TIFF, plist registration, and the signed app bundle.

## Version 0.6.0 — standard êi/uêi spelling

- [x] Render `bêi` as `bây` in standard output.
- [x] Render the explicitly requested `buêi` exception as `uây`.
- [x] Cover both rewrites across all six tones and through native ASCII+ input.
- [x] Retain passing full-inventory, grid/ASCII+ equivalence, and native controller suites.

## Version 0.6.1 — standalone i/y spelling

- [x] Render a completed onsetless, medial-less, coda-less `i` as `y` in standard output.
- [x] Cover all six tones: `y, ý, ỳ, ỷ, ỹ, ỵ`.
- [x] Preserve i when a final is present, including the `ín` regression.
- [x] Verify the rule through native ASCII+ typing and the full inventory suite.

## Version 0.6.2 — corrected Shift+Delete range

- [x] Delete the cycle's preceding separator space along with its letters and trailing spaces.
- [x] Make both `abc nmq   |` and `abc nmq|` become `abc|` in one action.
- [x] Handle both macOS Backspace (51) and forward Delete (117) keycodes with Shift.
- [x] Retain identical behavior in Vietnamese and literal ASCII modes.

## Version 0.6.3 — real-client Shift+Delete handling

- [x] Recognize Shift+Delete from tracked modifier transitions even when Delete's key event omits the Shift flag.
- [x] Use the IMK plain-string API as a fallback when attributed document access is unavailable.
- [x] Add real-event-shaped and document-access-fallback controller regressions.

## Version 0.6.4 — denied-document fallback and diagnostics

- [x] Stop clearing recent commits before Shift+Delete attempts.
- [x] Reconstruct the deletion range from contiguous recent commits when both IMK text-reading APIs fail.
- [x] Query physical left/right Shift state directly in addition to event and tracked state.
- [x] Add a metadata-only diagnostic line for physical confirmation; never log typed text.

## Version 0.7.0 — inline tone composition preview

- [x] Display the selected tone immediately after the initial/medial, before a nucleus exists.
- [x] Use U+02DC SMALL TILDE as the raised standalone ngã indicator (`nh˜`).
- [x] Underline marked composition explicitly through InputMethodKit.
- [x] Replace the temporary indicator with normal standard-Vietnamese tone placement once the nucleus is selected.
- [x] Preserve final vietmoi output characters without duplicating the preview indicator.

## Version 0.7.1 — committed-text Shift+Delete command route

- [x] Handle InputMethodKit `deleteBackward:` and `deleteForward:` command selectors outside active composition.
- [x] Use physical Shift state because command selectors do not include modifier flags.
- [x] Share the exact deletion implementation with the raw-event route.
- [x] Pass ordinary unshifted Delete commands through to the host.
