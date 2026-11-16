# siêu việt for iPhone

Open [VietMobile.xcodeproj](VietMobile.xcodeproj) in Xcode. The VietMobile scheme
builds an iPhone/iPad app and embeds its VietKeyboard custom keyboard extension.
Deployment target: iOS 16 or newer. UI tests require iOS 17 or newer.

The app opens a practice editor using the same touch keyboard as the extension.
Open **Cài đặt** in the siêu việt app to choose the input type (**ascii+** or
**grid4x8**), output (**siêu việt** or **quốc ngữ**), and interface language.
Vietnamese is the default; English is available for learners. The live keyboard
has no configuration controls or instruction strip. The ascii+ layout follows
the Mac's aligned guide: a below q, semicolon below p, and the Shift mode switch
below q. Keys use the shared outlined Keyflow style and sit at the bottom of the
custom keyboard surface. Tap the displayed atom; each key chooses the current
round's component.

- Four rounds: initial → onglide/core vowel → final → tone, then one space.
- Quốc ngữ translates only after the tone choice completes the basis.
- Backspace undoes a pending round, including a whole initial; otherwise it deletes normally. Hold to repeat.
- Space and mode switching preserve partial text. A quick Shift tap switches ASCII/Vietnamese and remembers that mode across text fields and keyboard restarts.
- Hold Shift to capitalize only the first character of each key’s text (nh → Nh). Releasing Shift immediately returns to normal typing; it never capitalizes a later key. Double-tap Shift for Caps Lock, which uppercases all characters (nh → NH); tap Shift to exit. Vietnamese atoms retain their case through tone selection and quốc ngữ spelling.
- The space bar is blank and Return uses an icon; both retain localized accessibility labels.
- `123` and `#+=` are always available directly from text. Tap either to toggle its panel; hold it to type temporarily on that panel, then release to restore the previous layout.
- Both modes retain the new final o (/w/), selected by the o position, and the 24-choice vowel map (oo on a, wê on n, wi on m).

To use it in other apps, install the app, then open iPhone Settings → General →
Keyboard → Keyboards → Add New Keyboard → **siêu việt**. In a text field, hold the
system globe key and select siêu việt. The app's system-keyboard editor tab lets
you test the installed extension separately from the built-in practice keyboard.
The app's **Enable keyboard** button repeats these steps.

The app atomically saves a small settings snapshot in its App Group container.
The keyboard has read-only access and loads this snapshot when activated; typing
uses an in-memory copy. The app does not need to remain open, and settings do not
change midway through a word. No Keychain sharing or Full Access is used.

The extension runs offline with `RequestsOpenAccess = false`. It saves only its
ASCII/Vietnamese mode in its own local preferences, separately from the practice
editor's mode. It never writes to the shared container or stores typed text there. There is no networking, server,
analytics, or persistent typing history.

Apple uses the system keyboard for secure/password and certain phone fields,
and host apps may disallow third-party keyboards.

## Free development installation

A free Apple Account's Personal Team can install development apps on your own
phone. Apple currently limits these profiles to seven days; rebuild and reinstall
to renew them. App Store and TestFlight distribution require a paid membership.

1. Connect the iPhone with a cable, unlock it, and trust the Mac if prompted.
2. Enable Settings → Privacy & Security → Developer Mode. Restart and confirm enabling it afterward.
3. Open the project in Xcode, select **VietMobile**, and choose the connected iPhone as destination.
4. In Signing & Capabilities, select your Personal Team for **both VietMobile and VietKeyboard**. Keep automatic signing enabled. Change bundle IDs together if Apple says they are unavailable; the extension ID must begin with the app ID.
5. Run. If iOS requests developer trust, open Settings → General → VPN & Device Management and trust your development identity, then open viet again.
6. Enable the keyboard as described above.

Xcode may need you to sign in under Xcode → Settings → Accounts and accept the
free developer agreement. A paid membership is not required. Apple supports App Groups for free Apple
Accounts. Select the Personal Team for both app and extension, and enable the same
`group.com.minh.sieuviet.ios` group under Signing & Capabilities. Let Xcode register
the group and refresh the profiles. An old provisioning profile may lack this
entitlement even though the capability is available; that mismatch does not mean
Full Access or a paid account is necessary.

CLI equivalents from the repository's `vietmoi` directory:

```sh
bash scripts/build-ios.sh simulator
bash scripts/build-ios.sh device TEAM_ID DEVICE_ID
bash scripts/install-ios.sh DEVICE_ID --no-build
```

A device build without TEAM_ID is an unsigned compile check and cannot be
installed. A signed build is at
`build/iOS-device/Build/Products/Debug-iphoneos/VietMobile.app` and includes
`PlugIns/VietKeyboard.appex`. The install script checks the signature and embedded
profile before installation and launches the app. It does not publish anything.

## Shared code and validation

The Xcode targets reference the existing files in `Sources/Core`; they do not
copy or fork the engine, phonetic inventory, orthography renderer, profile types,
or ASCII+ maps. The Mac and iPhone also share `ASCIIKeyboardLayout.guideRows`.
`Sources/Mobile` adds a small document adapter and a reusable UIKit surface.
The app and extension both compile those same source files. Mobile input/output
configuration is a Codable value independent of the live touch surface. The Mac's IMK adapter
remains separate because its document callbacks differ from UIKit's.

`MobileInputSession` owns marked text through an adapter for either a UITextView
or the extension's UITextDocumentProxy. It reconciles field/caret changes without
replaying an old preview at the new location. Typed text stays in the host field;
completed phonetic bases stay in the shared engine's in-memory state.

```sh
bash scripts/test-mobile.sh
bash scripts/test-ascii-plus.sh
bash scripts/test-controller.sh
bash scripts/test-ios-ui.sh SIMULATOR_ID
```

The UI-test helper installs and selects the extension in a booted simulator's
keyboard preferences, preserving its other keyboards. It then tests both the
practice surface and the actual system extension. It never changes a physical
phone's keyboard preferences.

The project has no package dependencies. `scripts/generate-ios-project.py`
recreates its checked-in project and shared scheme when source membership changes.
`scripts/make-ios-icon.swift` reproduces the app icon with Core Graphics/Core Text.

References: [custom keyboards](https://developer.apple.com/documentation/uikit/creating-a-custom-keyboard),
[text interactions](https://developer.apple.com/documentation/uikit/handling-text-interactions-in-custom-keyboards),
[Personal Team limits](https://developer.apple.com/help/account/basics/about-your-developer-account),
[Developer Mode](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device).

The physical-device settings-transfer test can be run with:

```sh
xcodebuild -project iOS/VietMobile.xcodeproj -scheme VietMobile \
  -destination 'platform=iOS,id=DEVICE_ID' -derivedDataPath build/iOS-device \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
  DEVELOPMENT_TEAM=TEAM_ID -parallel-testing-enabled NO \
  -only-testing:VietMobileUITests/KeyboardUITests/testDeviceConfigurationTransfer test
```

The installed viet keyboard should already be selected for that test. Full Access
must remain off; the embedded extension’s plist disables it as well.
