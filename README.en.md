[Tiếng Việt](README.md) · **English**

# siêu việt

Download development builds for macOS, iOS, Android, Windows and Ubuntu from
[GitHub Releases](https://github.com/legitminh/vietmoi/releases).
See [installation and build instructions](RELEASING.md) for architecture,
signing and qualification details; the iOS IPA requires re-signing.

The display name is **siêu việt** on macOS, iOS, Android, Windows, and Linux. Version 0.12.1
uses a five-point star for the app icon and the macOS input menu. Bundle IDs,
serialized output values, and the Mac `VietMoi.app` path remain stable for updates.
The launcher is `~/Applications/siêu việt.app`.

The native apps follow the local Keyflow / personal website design: monospace
type, monochrome paper, thin outlines, four-point key corners, and stable colors
for physical key positions. Light and dark appearances follow the system.
`Design/brand.json` is the source for the name, release version/build, theme values,
and star geometry. `Design/content.json` is the single Vietnamese/English interface
catalog; Vietnamese is the default and English is selectable in each app's settings.
`python3 scripts/generate-design.py` updates the Swift/Kotlin constants, Android
resources, release metadata, and platform display names; `--check` detects drift
during builds.
`Sources/Presentation/AppleTheme.swift` shares rendering between macOS and iOS;
Android's `AppTheme.kt` shares rendering between the app and IME. Apple icons are
rendered by `scripts/make-icons.swift` from the same geometry as Android. Engine,
layout, and mapping sources remain shared across every platform.

The touch keyboards contain only keys: the old preview/instruction strip is gone.
The iOS surface sizes itself from its rows and anchors the last row to the bottom;
the remaining globe/dictation area is owned by iOS. The Mac guide also has no
settings gear; settings are available from the siêu việt app.

A native Vietnamese keyboard with a shared engine and four rounds:

1. **Initial** (including ∅).
2. **Onglide + core vowel**, selected together with one key.
3. **Final** (including ∅), completing the unaccented preview.
4. **Tone**, applied to the core vowel, then commit the syllable and one space.

The iOS and Android apps/keyboards share this engine. Android calls the same
Swift core through JNI. Linux now has IBus and Fcitx 5 adapters verified in GTK/Qt
X11 hosts on ARM64 and x64. Windows x64/ARM64 packages now build natively and pass
checks against their packaged Swift engine and runtime. Actual TSF registration
and interactive typing remain unverified, with interactive testing deferred by request. See [desktop setup and
validation](Desktop/README.md) and the
[cross-platform architecture and development/testing plan](CROSS_PLATFORM.md)
for the decisions, migration order, support matrix, and release gates.

The first portability foundation is available as `SieuvietCore` (Swift package)
and `SieuvietEngine` (C-callable dynamic library). These use the existing engine
sources; the desktop adapters share C++ session policy around this library.
With Swift 6.3+ and Clang:

```sh
python3 scripts/test-portable.py
python3 scripts/test-package.py
```

The first command runs the existing core regression suites with `swiftc` on PATH.
The second tests the package and calls the built library from both C and C++.
The C contract is [`Sources/CABI/include/sieuviet.h`](Sources/CABI/include/sieuviet.h).
It exposes the construction engine; host composition and editing still require
native adapters and the shared-session work described in the plan.

All Vietnamese input first becomes a structured [`viet.phonetic.basis`](viet.phonetic.basis).
The basis stores initial, onglide, core vowel, tone, and final independently of
physical keys and display spelling. Sieuviet preserves the selected atoms and
normalizes emitted text to NFC Unicode. Unfinished input is underlined; Backspace
undoes one whole round. The preview remains unaccented until the last tone choice commits it.

## ASCII+ mapping

Physical keys refer to U.S. keyboard positions. The popup displays the action for
each current round. Its rows use aligned columns: a below q, semicolon below p, and Shift below q.

Initials: `b c ch d đ g z h k kh l m n ng nh p f r s t th tr v x ∅`.
Special bindings are `j → ch`, `y → d`, `d → đ`, `i → kh`, `q → ng`,
`w → nh`, `u → th`, `o → tr`, and `e → ∅`. Other initials use their own
letters. Standard ph is represented by **f**; standard gi is represented by **z**.

Round two uses the combined map below. The earlier separate core-vowel key map
does not apply to this round.

| Key | With onglide | Key | Without onglide |
|---|---|---|---|
| y | wă | w | ă |
| h | wa | s | a |
| b | wâ | z | â |
| u | wiê | e | iê |
| j | we | d | e |
| n | wê | x | ê |
| i | wơ | r | ơ |
| k | wo | f | o |
| m | wi | c | ô |
| | | t | ư |
| | | g | u |
| | | v | i |
| | | o | ươ |
| | | l | uô |
| | | a | oo |

The vowel round has **24 choices**. **wê uses n** and **wi uses m**. The commented-out
wô, wư, and wu combinations are unavailable; ươ and uô remain independent bare
nuclei. The p and q positions are unused in this round and do not advance it.
Semicolon is ordinary punctuation in every round; oo is selected with a.

| Tone | Key |
|---|---|
| ngang (unmarked) | s |
| sắc | d |
| huyền | f |
| hỏi | j |
| ngã | k |
| nặng | l |

Tone attaches inside the core atom, never to the onglide or final. The default
anchors are `iế`, `ướ`, `uố`, and `oó`; anchors remain configurable.

Finals: `∅ c ch m n ng nh p t o i`.
Special bindings are `e → ∅`, `j → ch`, `q → ng`, and `w → nh`.
Other finals use their own letters. Final **o** represents /w/; final **i**
represents /j/. They occupy the final round, not the onglide/core round.

| Four keys | Sieuviet output (then one space) |
|---|---|
| mses | ma |
| msed | má |
| msej | mả |
| dses | đa |
| xvns | xin |
| rwos | răo |
| tsos | tao |
| iues | khwiê |
| jles | chuô |
| mlnd | muốn |
| frej | fở |
| imoj | khwỉo |
| xaqs | xoong |
| sacd | soóc |

These examples use **siêu việt** output. Choose **quốc ngữ** in the output menu
to translate a completed phonetic basis to standard Vietnamese. The old
`vietstandard` selection migrates automatically to the new name.

## Quốc ngữ output

Both output modes show the same phonetic preview through the first three rounds.
Only the final tone choice translates and commits the whole word, with one space.
For example, round two shows `ngiê`, round three shows `ngiêng`, and the last
ngang choice commits `nghiêng `. The stored phonetic basis remains unchanged.
Space, an ASCII switch, or another early boundary keeps the incomplete phonetic
text without translating it or inventing missing atoms.

| Phonetic basis display | Completed quốc ngữ |
|---|---|
| răo | rau |
| tao | tao |
| khwiê | khuya |
| khwỉo | khuỷu |
| chuô | chua |
| fở | phở |
| zì | gì |
| cwả / kwả | quả |
| ngiêng | nghiêng |
| xoong | xoong |

The renderer uses your revised inventory and normal phonetic spelling, following
[Wikipedia's spelling tables](https://en.wikipedia.org/wiki/Vietnamese_alphabet#Spelling)
and [Hanoi finals](https://en.wikipedia.org/wiki/Vietnamese_phonology#Hanoi_finals):

- Initial f/z become ph/gi; g/ng use gh/ngh before front vowels; c/k use k before front vowels and qu with the w onglide. The shared i in gi+i/iê is written once.
- Onglide w becomes o before a/ă/e and u elsewhere, including after q. Rounded i/iê use y/ya/yê.
- Final o is the /w/ glide: write o after long a/e, u elsewhere. Short ă becomes a in au/ay; final i becomes y after ă/â, otherwise i. Long a stays distinct in ao/ai.
- Open iê/uô/ươ become ia/ua/ưa; closed forms retain iê/uô/ươ, with yê after u or at the start of a syllable. Explicit oo remains oo.
- Hanoi final c/ng after e/ê/i use ch/nh; e in these rimes is written a, as in ach/anh. Explicit ch/nh choices also remain available.
- Tone stays on the main vowel: hoá/huỷ, iế/uố/ướ, and open ía/úa/ứa. The existing standalone-i convention uses y; ordinary consonant+i uses i.

Older prototype exceptions (`ei → ay`, `êi → ây`, `buêi → uây`, and c+w → cua)
are superseded by the current phonetic atoms and normal spelling. Conversion
allows all construction choices; it does not use a dictionary or block unusual
combinations.

## Construction scope and phonology

The base inventory has the 14 nuclei in the supplied
[Vietnamese phonology reference](https://en.wikipedia.org/wiki/Vietnamese_phonology#Syllables_and_phonotactics),
plus the explicitly added oo choice. The combined round offers 15 unrounded
choices and 9 w-prefixed choices. All six tones and all listed finals remain
selectable. This intentionally allows extra combinations instead of enforcing a
dictionary or phonotactic filter; for example, selecting ngang with final t is
allowed even though it is outside normal Vietnamese stop-final tone patterns.

The map can construct onglide-plus-offglide exceptions such as khuỷu. Fixed iê,
ươ, and uô atoms cover their open and closed orthographic variants without
requiring separate ia, ưa, and ua atoms. The supplied initial and final distinctions
are preserved rather than merged according to a selected dialect. No claim is
made that every regional or marginal contrast has been exhaustively audited.

The oo extension allows forms such as xoong, boong, and soóc, without merging
these tokens into ordinary o. Dictionary examples: [xoong](https://vi.wiktionary.org/wiki/xoong),
[boong](https://vi.wiktionary.org/wiki/boong), [soóc](https://vi.wiktionary.org/wiki/so%C3%B3c).

## Editing and mode switching

- **Short isolated Left Shift tap:** toggle Sieuviet / literal ASCII on release. Keep the visible partial text and end its input cycle without adding a space; retain the selected mode across text fields. For example, `m` → Shift tap → `y` produces `my`. Holding Shift or using it with another key preserves normal Shift behavior. Right Shift is a regular modifier.
- **Space:** keep visible partial text, add one space, and start a fresh cycle. For example, `m` → Space produces `m `. Incomplete words and abbreviations are allowed.
- **Backspace:** undo one input round while composing, including deleting the first initial; native deletion otherwise.
- **Escape:** cancel unfinished input and restore any replaced selection where supported.
- **Fn+Backspace (forward Delete):** in ASCII+, clear partial input or erase the last verified committed cycle. Explicitly selected text uses native deletion instead.
- **Shift+Backspace / Shift+Delete:** cancel partial input and attempt to remove the preceding alphabetic cycle, trailing spaces, and its preceding separator; host support varies.
- **Return, Tab, navigation, shortcuts, and unmapped punctuation:** keep visible partial text, end its cycle, and retain native host handling. Host-requested composition flushes and focus changes also keep partial text without adding a separator.
- **Unavailable modal letters:** consume without advancing a round. Holding/repeating an atom key does not advance rounds.

Literal ASCII preserves case and hides the guide. The next isolated Shift tap
returns to Sieuviet. Shift state uses hardware HID state, excluding synthetic
state that can leave Delete logically down after selection deletion. The
same-field select/delete/toggle fix was physically confirmed in version 0.8.3
and is retained here. No global event monitor or new permissions are required.

Generated previews and commits reject control characters and private-use
function-key payloads. Editing commands are handled by keycode or macOS responder
selector, never by inserting their event payloads. The original macOS source identity and app
executable name remain VietMoi for update compatibility; output is siêu việt or quốc ngữ.

## Grid input and configuration

The grid4x8 layout also uses the new four rounds. Each round follows its inventory
order across non-reserved slots; the tone round uses the first six slots in
ngang/sắc/huyền/hỏi/ngã/nặng order. Left Shift remains the mode key, and grid m
clears a cycle. This is a separate physical layout from the ASCII+ map above.

Named atom mappings live in `Sources/Core/ASCIIPlusMapping.swift`. A profile can
persist an optional `asciiPlusKeymap`; native routing and guide labels use the
same map. The inventory and tone anchors live in `Sources/Core/PhoneticBasis.swift`.
The keymap schema is version 6. Version-5 default vowel bindings adopt the new
24-choice map; actual overrides and physical-key removals survive. A custom
binding to a removed rounded atom is retained as data but cannot select a vowel. Older profiles retain their identities and
output settings. Version-2 default vowel positions adopt the new map; actual
custom overrides and removed keys are preserved. Version-3 comma/oo defaults
move through semicolon to the current a position. Version-4 default final u moves to o; custom atom positions
follow the rename without overwriting existing key overrides. The oldest incompatible
vowel/tone maps reset to the new defaults, retaining applicable initial/final overrides. There is no
remapping editor in setup yet.

Completed phonetic bases are retained with editing metadata in memory, up to 128
cycles. Partial abbreviations preserve the rendered text without inventing a
completed basis or tone. Typed words are never written to a persistent history log. Selection
changes invalidate verified-deletion history. Automatic capitalization of
composed Vietnamese and Telex input remain unimplemented.

## Android app and keyboard

The Android app includes a native system keyboard, settings, and a test editor.
It supports both outputs and layouts, partial words, round-aware Backspace, ABC,
symbols, native editor actions, and attached keyboards with shared Shift tap rules.
The app writes an atomic settings snapshot; the separate IME process only reads
it at activation. There is no Internet permission or persistent typing history.

See [Android/README.md](Android/README.md) for setup, build/test commands, and the
isolated emulator. From this directory:

```sh
python3 scripts/android-emulator.py
python3 scripts/test-android.py
```

## iPhone app and keyboard

The mobile project includes a practice app and an additional iOS keyboard, with
both sieuviet and quốc ngữ output. They reference the same core source files and
ASCII+ map as the Mac build. The aligned guide rows are shared as well. The touch
interface includes ABC mode, numbers/symbols, Space, Return, and repeating
Backspace. Input/output selection lives only in the app’s Settings screen.

Open [`iOS/VietMobile.xcodeproj`](iOS/VietMobile.xcodeproj) in Xcode. See
[`iOS/README.md`](iOS/README.md) for free Personal Team installation, enabling the
keyboard, rebuild commands, and mobile validation. The extension works offline without Full Access. The app saves a settings
snapshot in an App Group; the keyboard reads it on activation and uses its cached
configuration while typing. The app can be closed.

## Build and install

Development requires macOS 13+ and the Swift/Xcode command-line tools. Users only
need the built app. Run from this directory:

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

The installer updates `~/Library/Input Methods/VietMoi.app`, switches away from
an active old instance before replacement, and preserves its registered input
source ID. The installer restores the input source if it was active before the update. First-time users
add siêu việt in System Settings → Keyboard → Text Input → Edit → +. macOS may need
logout/login to refresh its cache. Builds are locally ad-hoc signed; public
release requires Developer ID signing and notarization. Windows packages are
natively built and engine-smoke-tested; real-app TSF typing qualification remains
outstanding. See [desktop status](Desktop/README.md).

Tests enumerate all **39,600** combinations for safe NFC output, tone placement,
spacing, basis consistency, and grid/ASCII+ physical-path equivalence. Native
controller tests cover the round order, oo/a and punctuation routing, mode switching, selection
restoration/deletion, missing releases, duplicate modifier events, and control
payloads. They supplement, rather than replace, host-application verification.
