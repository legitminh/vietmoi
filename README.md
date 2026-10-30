# viet — macOS keyboard app

Native, offline four-keystroke Vietnamese syllable input with an 8×4 floating guide. No runtime downloads, account, Accessibility permission, or global key logger is needed. The app uses macOS InputMethodKit; ordinary keystrokes reach it when it is the selected input method in a supporting text field.

## Setup and keyboard profiles

Open `~/Applications/viet.app`. The first launch opens a native setup window with a default keyboard and two dropdowns:

- **Input type:** `grid4x8`, `ascii+`, `telex`.
- **Output type:** `vietstandard`, `vietmoi`.

The default is `grid4x8 → vietmoi`. Add keyboards with **Add keyboard**, remove them with the minus button, and choose one with **Select**. At least one keyboard is retained. The list, selected profile, and dropdown values save automatically in this app's local preferences.

Each profile has a **Show virtual keyboard** checkbox. Turn it off to show only a small settings gear while typing; the gear reopens setup. This preference saves independently for each keyboard. Existing profiles keep the guide enabled when upgrading.

Both `grid4x8` and `ascii+` now drive actual typing, using the same four-stage cycle with either vietmoi or standard Vietnamese output. Telex remains a saved input choice for a future update. Changing the selected profile, input type, or output type cancels unfinished input and starts the new mode at its initial phase.

Choose **Hide & keep typing**, or close the setup window, to keep the input method running in the background. Click the **gear at the upper left of the keyboard popup**, beside the live cycle-state display, to reopen setup. It does not replace any input key. Reopening the app also opens setup. Setup is not automatically shown on every subsequent input-method session.

## Shift tap and hold

Left Shift has two roles:

- **Tap alone:** release it before the configured limit to switch between Vietnamese and literal ASCII. The mode changes on release, never on key-down.
- **Hold:** release at or after the limit to keep the current mode. Holding alone preserves unfinished composition.
- **Use with another key or modifier:** behave as ordinary Shift, with no mode switch, regardless of release order. A key already held when Shift starts also disqualifies the tap. Shift+letters, Shift+number punctuation, Shift+arrows, Shift+Tab, and modified shortcuts go to the host application. A Shift chord cancels any unfinished Vietnamese composition before the host handles it.

The global **Left Shift tap limit** field at the bottom of settings accepts **0.01–5 seconds** and saves when editing finishes. It applies to all profiles and survives relaunch. **Reset** restores the program's shipped **0.20-second** default, based on [QMK's 200ms TAPPING_TERM default](https://docs.qmk.fm/tap_hold); there is no universal OS-wide threshold. Invalid values preserve the previous setting. A press uses the limit that was active when it started.

Right Shift remains a normal modifier. Deactivation, another modifier, or a mouse click cancels a pending tap; an ordinary composition-flush callback does not. At the next Shift press, macOS key-state queries reconcile previously observed held keys, so a missing key-up event cannot permanently disable taps. No global keyboard hook, delayed key replay, or held-key timer is used.

Literal ASCII/Vietnamese mode is shared across input boxes and remains selected through focus changes. Moving to another field cancels only an unfinished syllable; it does not change modes. Literal ASCII hides the entire floating panel because the physical keyboard needs no guide. The panel returns after the next isolated Shift tap switches back to Vietnamese mode.

In Vietnamese mode, the Left Shift/mode-switch position uses the bundled U.S. flag artwork instead of a `Shift` or `ASCII` text label. It remains inside the input block: the first key of grid4x8's bottom row and immediately before `z` on ASCII+'s bottom row.

## Build and install

Requires macOS 13+ and Apple's Swift compiler/Xcode command-line tools **for development only**. Users only need the compiled app.

```sh
bash scripts/test.sh
bash scripts/test-controller.sh
bash scripts/test-profiles.sh
bash scripts/test-ascii-plus.sh
bash scripts/test-standard.sh
bash scripts/test-shift.sh
bash scripts/build.sh
bash scripts/install.sh --no-build
```

Installation is per-user at `~/Library/Input Methods/VietMoi.app`; no administrator password is needed. The installer registers the bundle, but does not switch your active keyboard.

In **System Settings → Keyboard → Text Input → Edit → +**, search for **viet**, or look under **Vietnamese**. The existing VietMoi source keeps its identifier during this update. Add and select it using the input menu. If macOS has cached the list, log out and back in once. Keep an ordinary input source enabled so you can always switch back.

The registered macOS input-source icon is `★`. It is bundled as a transparent 16×16 template image so macOS can recolor it for the menu bar, dark mode, and selected menu states.

The app is locally ad-hoc signed. Public distribution will need Developer ID signing and notarization; this MVP does not claim to be a public release. The build targets the current Mac's architecture. Windows is not implemented.

## ASCII+ input

In setup, choose **ascii+** for the selected keyboard's input type, then **Hide & keep typing** and select viet as your macOS input source. The popup changes to an compact three-row QWERTY guide. Only letter positions appear, with the action for the current stage and no physical-key annotations, number row, punctuation keys, or space bar. Both keyboard guides have a 76% opaque background with full-opacity text. Key positions follow a US keyboard; this does not switch away from the viet input method.

The cycle is unchanged: **initial → medial/tone → nucleus → final**. The fourth input commits. Examples (`e` selects an empty final; no Space keypress is needed):

| Keys | Output |
|---|---|
| `m w a e` | `ma ` |
| `m e a e` | `ma´` |
| `x w i n` | `xin ` |
| `z w a o` | `chao ` |
| `a w a e` | `đa ` |
| `m w u e` | `mia ` |
| `t w e i` | `tei ` |

Initial substitutions: `a → đ`, `z → ch`, `j → gi`, `i → kh`, `q → ng`, `y → nh`, `f → ph`, `w → qu`, `u → th`, `o → tr`, and `e → ∅`. Other listed consonants retain their letters. The source document currently also assigns o to the empty onset; the implementation uses e for empty onset/final to avoid that collision while honoring o → tr.

Medial/tone keys follow the source specification:

| Medial | ngang | sắc | huyền | hỏi | nặng | ngã |
|---|---|---|---|---|---|---|
| ∅ | w | e | r | y | u | i |
| u | s | d | f | h | j | k |
| o | z | x | c | b | n | m |

The last two physical positions are deliberately **nặng, then ngã**; for example, `i` selects an empty medial with ngã.

Nucleus substitutions: `s → ă`, `d → â`, `r → ê`, `o → ô`, `p → ơ`, `y → ư`, `h → ưa`, `j → ươ`, `u → ia`, `k → iê`. `a`, `e`, and `i` retain their values. To preserve the previous prototype's complete vowel inventory, the additional nuclei absent from the ASCII+ document use spare keys: **`c → o`, `l → u`, `w → ua`, `v → uô`**. All appear in the popup.

Final substitutions: `z → ch`, `q → ng`, `y → nh`, and **e → ∅**. Other listed finals retain their letters. The revised spec's `i` and `ia` have distinct keys (`i` and `u`), and the removed stray vowel `m` is not implemented.

- **Left Shift tap:** toggle literal ASCII and ASCII+ on release; cancel an unfinished cycle. Literal ASCII hides the entire floating panel until the next tap.
- **Backspace:** undo a component while composing; ordinary character deletion otherwise.
- **Shift+Backspace / Shift+Delete:** in every mode, cancel partial input and remove in one action: spaces immediately left of the caret, the contiguous alphabetic cycle before them, and one separator space before that cycle. Thus both `abc nmq   |` and `abc nmq|` become `abc|`. Physical Shift state is tracked independently because some IMK clients omit Shift from Delete's own event. If attributed document access is unavailable, the controller falls back to the client's plain-string API. If punctuation is immediately left of the caret, leave Backspace behavior to the host application.
- **Fn+Backspace** (forward Delete): clear the current cycle, or attempt verified deletion of the last committed cycle. Unlike grid mode, `m` is always available as a phoneme key.
- **Escape:** cancel partial input.
- **Return/Tab/navigation/shortcuts:** cancel partial input and pass the command through.

Keys outside the ASCII+ input alphabet pass through to the host normally, including Space, numbers, comma, period, slash, brackets, quotes, and other punctuation. They cancel an unfinished syllable before the host inserts them. A letter that belongs to ASCII+ but is unavailable in the current phase is still consumed as an invalid modal choice, so it cannot leak into composed text. Shift combinations also pass through normally. Both input layouts use the selected output format. The examples above use vietmoi output.

## Standard Vietnamese output

Choose **vietstandard** in the selected profile's Output type dropdown. Both grid4x8 and ASCII+ use the same formatter. Four keys still complete a syllable. Standard output adds **one space after every completed syllable**, including those with marked tones, so consecutive cycles form readable text without another Space keypress. Literal ASCII mode passes text through without adding spaces. Standard spelling and tone marks appear in marked text once the nucleus is selected; the final input can change a diphthong's spelling.

| ASCII+ keys | Standard output |
|---|---|
| `t w e i` | `tay ` |
| `i s u e` | `khuya ` |
| `q w k q` | `nghiêng ` |
| `m e a e` | `má ` |
| `m y a e` | `mả ` |
| `h c a e` | `hoà ` |
| `u h i e` | `thuỷ ` |
| `w y a e` | `quả ` |
| `m e v n` | `muốn ` |
| `b s r i` | `uây ` |
| `b w r i` | `bây ` |
| `e e i e` | `ý ` |

The formatter uses the selected onset, medial, nucleus, final, and tone directly:

- `e + i → ay`, preserving the difference between `tei → tay` and `tai → tai`. `â + i → ây`, `ê + i → ây`, and `u + ê + i → uây`; short `ă + i/u → ay/au`. The requested `b + u + ê + i` display exception emits `uây`, while `b + ê + i` emits `bây`.
- `i → y` after a medial; `u + ia → uya`. Closed iê becomes yê after a medial or with no onset (`khuyên`, `yên`). Open/closed forms ia/iê, ua/uô, ưa/ươ follow the coda, including final glides (`tiêu`, `tươi`).
- A completed onsetless `i` with no medial or final is written `y`, including all tones (`y, ý, ỳ, ỷ, ỹ, ỵ`). A coda keeps `i`, so `ín` does not become `ýn`.
- `ng/ngh`, `g/gh`, and `c/k` follow the next written vowel. Thus `ng + iê + ng → nghiêng`. The onset `gi` shares its i with an i-initial nucleus (`gì`, `giếng`). Only the explicit `qu` onset produces `qu`; a separately selected `c/k` onset and `u` medial remain distinct, so `c + u + a + hỏi → cuả` rather than `quả`.
- Tones attach to the main vowel: the first vowel of open ia/ya/ua/ưa, the second of closed iê/yê/uô/ươ. Medials and final glides do not receive the tone. This uses the pronunciation-based `hoà/thuỷ/khoẻ` convention described by [UniKey](https://www.unikey.org/support/ukmanual.html), rather than the alternative `hòa/thủy/khỏe` placement. Emitted text is NFC Unicode.

Spelling background: [Vietnamese phonology and orthography, Cơ sở tiếng Việt](https://dulieu.itrithuc.vn/media/dataset/2020_08/cosotiengviet.pdf), and [Vietnamese reference grammar in the Mon-Khmer Studies archive](https://sealang.net/archives/mks/pdf/13-14%3A1-367.pdf).

This is a deterministic syllable formatter, not a dictionary or a word predictor. It preserves the selected phonemes and does not reject impossible syllables or tones with stop finals. Lexical i/y variants, names, and word-boundary meaning cannot all be inferred from these components; i changes to y only under the structural rules above. Shift combinations produce ordinary literal characters; automatic capitalization of composed Vietnamese syllables is not implemented. The tone suffix characters used by vietmoi do not appear in standard output.

## Physical map

```text
1      2      3      4      5      6      7      8
q      w      e      r      t      y      u      i
a      s      d      f      g      h      j      k
Shift  z      x      c      v      b      n      m
```

Mappings use physical Mac keycodes (US-QWERTY positions), independent of the label printed by another layout. **Left Shift** toggles modes only after a short isolated tap is released. Holding it or using it with another key preserves normal Shift behavior. Right Shift is always a regular modifier. Hold/repeat does not advance Vietnamese phases.

The bottom-left and bottom-right keys are reserved in Vietnamese mode:

- **Left Shift tap:** toggle ASCII/Vietnamese on release; cancel an unfinished cycle.
- **m:** clear an unfinished syllable; otherwise remove the most recent completed cycle at this caret when document access allows verification.
- **Backspace:** undo one component while composing; normal character deletion otherwise.
- **Shift+Backspace / Shift+Delete:** remove the preceding alphabetic cycle, spaces after it, and its single preceding separator space in one action. This is identical in Vietnamese and literal ASCII modes.
- **Escape:** cancel an unfinished cycle.
- **Return, Tab, navigation, application shortcuts:** cancel an unfinished cycle and pass the command to the application.
- **Space, punctuation, unused numbers, and other keys outside grid4x8:** pass through normally and cancel an unfinished syllable first. Repeats continue to work. Keys inside the 4×8 grid retain their modal actions.

In ASCII mode, `m` is literal and Backspace deletes a character. A short isolated Left Shift tap returns to Vietnamese. Shift+letters/punctuation and Command/Control/Option shortcuts pass through normally. Literal ASCII preserves character case, persists when focus moves to another input box, and hides the floating panel completely.

The popup follows the caret where the host provides a valid rectangle, otherwise it appears near the bottom of the screen. It is a non-activating guide with a clickable settings gear on the same top line as the cycle-state display. Clicking the gear deliberately opens and focuses setup; the rest of the guide does not take keyboard focus. The redundant keyboard/profile title row and all bottom key-help annotations are omitted. The action keys and compact composition preview show all four phases dynamically:

1. Initial, including ∅.
2. Medial + tone: row one ∅, row two u, row three o. In each row, columns 1–6 mean ngang, sắc, huyền, hỏi, ngã, nặng. Columns 7–8 are unused.
3. Nucleus.
4. Final, including ∅. The fourth key commits.

## Try these sequences

Select VietMoi in a plain text editor, then press each physical key separately:

| Keys | Output | Meaning |
|---|---|---|
| `r111` | `ma ` | ma, with a space suffix for ngang |
| `r211` | `ma´` | má in custom notation |
| `z166` | `xin ` | xin |
| `311q` | `chao ` | chao |
| `g144` | `tei ` | tay in the specification's custom spelling |
| `21y6` | `con ` | con |
| `h1u1` | `thu ` | thu |
| `r1i1` | `mua ` | mua |
| `r2a6` | `muôn´` | muốn in custom notation |

With **vietmoi** selected, output follows the prototype specification: raw components followed by a tone suffix, with no extra space after marked tones. Hỏi uses the standalone question mark `?` (U+003F), so ASCII+ `myae` produces `ma?`; it does not combine with the preceding letter. A literal question mark and hỏi, like a literal period and nặng, remain indistinguishable after export. Internal phase state never relies on parsing these suffixes.

Initial/nucleus/final inventory ordering follows the specification. The missing `o`, `u`, `ua`, and `uô` nuclei are appended to enable common words. `tay` is entered as `t + e + i`, displayed as `tei`. No automatic phonotactic filtering or pronunciation-based rewriting is applied.

## Scope and limits

The engine supports all 95,472 combinations in its inventory; these are input paths, **not** a claim that all are linguistically valid. Engine tests cover the phases, sample outputs, mode changes, invalid keys, cancellation, and conservative deletion checks. Document-session tests use a protocol-conforming test document for actual insertion, selection restoration, cycle clearing, and ASCII switching; they do not replace live host-application checks. macOS document access varies by application: if a completed cycle cannot be verified, clear refuses to erase it; ordinary Backspace still works. Cursor/focus changes invalidate deletion history. Replaced selections are restored when cancelling a marked composition where the client supports it.

Compatibility still needs checking in each target application. Secure fields and applications that do not support third-party input methods may retain system input behavior. This prototype does not perform global event interception or synthesize keystrokes.

## Source layout

- `Sources/Core/KeyboardEngine.swift`: Foundation-only engine, layout, and deletion validation.
- `Sources/Core/StandardVietnamese.swift`: component-aware spelling and tone placement.
- `Sources/Core/KeyboardPreferences.swift`: global tap-duration preference and isolated Shift-tap detection.
- `Sources/Core/KeyboardProfiles.swift`: saved keyboard configurations and selected profile.
- `Sources/Core/ASCIIKeyboardLayout.swift`: physical ANSI/QWERTY layout.
- `Sources/Core/ASCIIPlusMapping.swift`: per-stage ASCII+ key bindings.
- `Sources/macOS/InputController.swift`: native text composition and event routing.
- `Sources/macOS/KeyboardPanel.swift`: non-activating guide.
- `Sources/macOS/ASCIIKeyboardView.swift`: standard ASCII guide and dynamic action labels.
- `Sources/macOS/SettingsWindow.swift`: setup window, keyboard list, and dropdown controls.
- `Resources/Info.plist`: input-source registration metadata.
- `Resources/UnitedStatesMode.svg`: bundled U.S. flag artwork for the mode-switch key.
- `scripts/`: build, test, install, input-source inspection.
- `PLAN.md`: implementation plan.

The core is Swift for this MVP to avoid extra build dependencies. Its inventories and behavior can later be moved into a shared Rust or C++ library for Windows TSF without changing the four-phase design.

See `VERIFICATION.md` for live test evidence and remaining host-application checks, including cycle-clear behavior in TextEdit after hot updates.

## Updating and removal

Switch to another input source before rebuilding/reinstalling. The installer also switches to U.S. input if VietMoi is currently selected, then restarts only VietMoi. Select VietMoi again after installation. If you see literal keys or an old composition after an update, switch away and back; if the connection remains stale, log out and back in. To remove it, first remove VietMoi from Input Sources in Settings, then move `~/Library/Input Methods/VietMoi.app` to Trash and log out/back in if it remains cached.

Framework references: [Apple InputMethodKit](https://developer.apple.com/documentation/inputmethodkit), [IMKServer configuration](https://developer.apple.com/documentation/inputmethodkit/imkserver/init(name:bundleidentifier:)), [notarization](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).
