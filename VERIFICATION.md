# MVP verification — October 29, 2026

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
