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
