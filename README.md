# Prize Bond Checker

Offline-first Flutter FYP that checks Pakistani prize bond numbers against a bundled catalog of simulated draws across all eight denominations. It includes camera OCR, automatic checks at app startup, and PDF draw reports.

**Final-year project, BS Software Engineering (Virtual University of Pakistan), graded 4.0/4.0 (A+).**

## Overview

Checking prize bonds by hand means comparing six-digit numbers against long draw lists for each denomination. The app demonstrates that workflow using professor-approved simulated results. You can scan or enter bond numbers, save them, and check them against the local catalog without an internet connection.

## Features

- **OCR scanning:** reads 6-digit bond numbers in real time from a live camera stream with Google ML Kit text recognition, using a throttled frame stream and custom rotation handling
- **All 8 denominations:** Rs. 100, 200, 750, 1,500, 7,500, 15,000, 25,000 and 40,000
- **Offline-first storage:** a local Hive data layer with 7 type adapters; draw status recalculates automatically by date
- **Automatic checks:** saved bonds are checked against the local catalog when the account is unlocked
- **Notifications:** a four-channel notification system built on Awesome Notifications
- **Bulk verification:** import bond numbers from TXT or CSV files
- **PDF export:** styled draw reports
- **Security:** account-specific local data, a device-protected PIN verifier, and limited PIN attempts
- **Admin workflow:** an approval flow for administrative actions
- **Connectivity awareness:** a live online/offline indicator

## Architecture

Layered **presentation → business logic → data** structure:

```text
lib/
├── config/      # app configuration and constants
├── models/      # Hive models + generated type adapters (*.g.dart)
├── services/    # local accounts, private storage, draw checking, notifications
├── screens/     # check, scanner, bulk check, draws, history, my bonds, notifications, profile, admin
└── widgets/     # bond-number extractor, camera image converter, connectivity badge, filters
```

## Tech stack

Flutter · Dart · Google ML Kit Text Recognition · camera · Hive · Flutter Secure Storage · Awesome Notifications · pdf · file_picker · crypto · connectivity_plus · timezone · shared_preferences

## Getting started

**Simulated FYP data.** All draw matching uses the professor-approved catalog bundled with the app. Official National Savings results are outside the demo's scope.

Use Flutter 3.41 or later with Dart 3.11 or later. Flutter 3.41.9 is the verified baseline. Android requires Java 17 or later and Android SDK 36. The iOS app requires iOS 15.5 or later and a compatible Xcode and CocoaPods installation.

From the root of a clean source checkout, run the following commands for the targets you have installed.

```bash
flutter doctor -v
flutter pub get --enforce-lockfile
flutter build apk --debug
flutter build ios --debug --no-codesign
```

The Android APK is at `build/app/outputs/flutter-apk/app-debug.apk`. The unsigned iOS build is at `build/ios/iphoneos/Runner.app`. Select your development team in Xcode's Runner signing settings and use `flutter run -d <device-id>` for an iPhone installation. Camera OCR needs a physical device. The pinned iOS ML Kit binaries require a physical iPhone for the demo on Apple Silicon.

### Demo workflow

1. Use the administrator setup below to approve a demo account, then sign in with its PIN.
2. Open the bond checker and enter `770487` for **Rs. 200**. Sample draw **91**, dated January 15, 2026, becomes eligible on January 16 on the device calendar.
3. Open **History → Past Draws**, select an eligible sample draw, then choose **Download Full List (PDF)**. The report includes each sample winner and prize amount, with a simulated-results label on every page. The app confirms the save and offers **Open PDF** as a separate action.
4. Open **Market** and post a listing with demo details. A second signed-in account on the same device can view the listing. Its owner can remove it. Historical listings with no recorded owner stay in their original Hive box and are hidden from the Market view.

### Simulated draw checking

The app validates the version, checksum and contents of the 21-record catalog in `assets/data/draws_seed.json` before using it. Startup reconciles Hive by denomination, draw number and draw date, then flushes and verifies the rows before recording completion. A retry fills missing rows or repairs incomplete catalog entries in place. It preserves valid legacy keys and reports a conflict when an existing complete draw disagrees with the catalog.

Manual checks, My Bonds, bulk lists, scanner results and automatic checks share the same rules. Compare exactly six digits, including leading zeros. A sample draw becomes eligible the day after its listed date on the device calendar. The default check uses all elapsed catalog draws for the chosen denomination.

- **Win** means a number matched an eligible, verified FYP sample draw. A verified match still counts when other expected results are unavailable. If several draws match, the result shows the most recent match.
- **No Win** means every expected FYP sample draw for the check was eligible and verified, and none contained the number.
- **Results Unavailable** means there were no eligible sample results, or a pending, missing, or incomplete expected draw prevented a definitive negative result.

The checking service accepts an inclusive date range that filters only the 21 approved FYP sample records by date and denomination. Its endpoints can extend beyond the sample dates or the current day. A pending sample draw within the filter still prevents a negative result. Results describe eligible FYP sample draws only. That scope excludes complete calendar-period coverage and official National Savings results. The current screens use the default period.

Repeated checks with the same outcome and coverage on the same day share one history event per account. Win notices use the account's inbox and a stable draw-and-bond event key. Account-scoped receipts prevent a dismissed win notice from reappearing during an ordinary recheck. Automatic checks and My Bonds update saved bond status without adding history rows. Older account records keep their original keys and values.

My Bonds can store the optional issue date and city for reference. Both fields can be blank, and draw matching uses the bond number and denomination. **Scan Instead** fills those two inputs in the open form. Use **Add Bond** to save the draft.

Bulk check accepts UTF-8 TXT or CSV files, with or without a byte order mark, and pasted numbers separated by commas or line breaks. Use one six-digit number per entry and keep any leading zeros. A one-column CSV may quote its values. Each batch allows up to 256 KiB of combined input and 1,000 nonempty entries before deduplication. If a check stops partway through, **Check All** with the same input resumes after the last completed entry.

### Device alerts and draw reminders

Profile switches control device notifications per account. The in-app inbox continues to record notices when alerts are muted or system permission is denied.

Choose **Set Reminder** on a sample draw in Draws or History. Each account can schedule one reminder per draw at 8:00 a.m. on draw day in the device's local time. On Android, exact-alarm access is separate from notification permission. If exact timing is unavailable, you can explicitly choose an approximate reminder. The app remembers the selected mode after restart, permission recovery, and unlock. An exact reminder stays paused while exact access is unavailable. A reminder set to approximate keeps that mode even if exact access is later granted.

You can reopen the draw's reminder to retry, reschedule, or cancel. Logout, account switching, and app locking request cancellation of pending reminders. Unlocking the owning account restores eligible future reminders. Elapsed reminders expire without catch-up alerts. Explicit cancellation removes the request after the platform confirms the cancellation.

Cancellation on lock is best effort. The system may show a queued notification before cancellation completes, including around app suspension or termination. System reminders use generic text and the app requires the normal unlock to view private information. Scheduling and delivery timing after device reboot depend on the platform. The app checks pending schedules at startup and again after unlock.

### Offline account demo

Set a strong demo administrator passphrase privately. The build accepts only its SHA-256 verifier. This command prompts without displaying the passphrase or writing it to the repository.

```bash
verifier="$(python3 -c 'import getpass, hashlib; print(hashlib.sha256(getpass.getpass("Demo admin passphrase: ").encode()).hexdigest())')"
flutter run --dart-define="FYP_ADMIN_VERIFIER=$verifier"
```

Register an account, return to the landing screen, and open **Admin** to approve it. The account holder can then **Sign in** with their registered email and PIN. The administrator can review declined registrations and help an approved account holder reset a forgotten PIN. Builds without a verifier leave Admin Access unavailable.

Bonds, check history, and inbox records created before accounts had ownership remain in their original Hive boxes. They are kept out of account views because the app cannot verify their owners. Existing Hive accounts keep their profile and approval. A successful unlock upgrades older SHA-256 PIN verifiers. The public demo catalog is shared. Account separation is enforced by the app on one device. The account boxes remain readable to someone with direct access to the app's files.

The app covers the screen when it loses focus. After backgrounding, enter the account PIN or administrator passphrase again. A private write already submitted to storage can finish for its original account. Each later write requires an active session. Android blocks app screenshots and recent-app previews. iOS covers the window for the app switcher.

On iOS the native cover stays in place until the current locked transition frame can be read from the Flutter surface in Core Animation's presentation layer. This check depends on the IOSurface-backed renderer used by Flutter 3.41.9 on iOS. It confirms the composited buffer, with final display behavior left to on-device verification. If the renderer does not expose a usable surface, the cover stays in place and prompts you to close and reopen the app.

### PIN recovery

PIN verification keys use Android Keystore-backed storage or iOS Keychain. If the app reports that a key is missing, damaged, or invalid, open **Admin** and find the approved account. Verify the account holder's identity, use **Reset PIN**, then confirm **Recover PIN** when prompted. Recovery creates a new credential for that account and keeps its existing profile, approval, bonds, history, and inbox. If several accounts used the same lost key, recover each affected account separately. Recovering one account leaves the original shared key available if it can be restored.

If secure storage is unavailable, unlock the device and retry. Recovery requires working secure storage. The app preserves existing credentials and records if it cannot save and verify a replacement. If registration succeeds and selecting the account fails, use **Sign in** with the registered email.

### Retry limits

Five failed attempts trigger a one-minute wait. Each account and Admin Access has a separate retry record. The app writes the attempt to Hive before checking the credential and refuses authentication when it cannot persist the record. Retry timing uses monotonic elapsed time during a run. An outstanding lock starts a fresh one-minute wait when that account is first tried after a restart.

Run both test configurations to cover an unprovisioned build and the admin flow. Use the fixture verifier only for tests.

```bash
flutter test
test_verifier="$(printf %s 'fixture-only-module-2-admin' | shasum -a 256 | cut -d ' ' -f 1)"
flutter test --dart-define="FYP_ADMIN_VERIFIER=$test_verifier"
```

## Development roadmap

| Module | Status |
| --- | --- |
| 1. Bootstrap and verification baseline | Complete and approved |
| 2. Accounts, approval, and private storage | Complete and approved |
| 3. Draw import and checking engine | Complete and approved |
| 4. Checking, My Bonds, bulk checking, and OCR | Complete and approved |
| 5. Notifications and reminders | Complete and approved |
| 6. Reports, marketplace, and submission polish | Complete and approved |
| Post-Module 6: Android bulk import restoration after the owning account unlocks | Complete and approved |
| Post-Module 6: Android reminder permission, channel, and exact-alarm checks | Complete and approved |

Modules 1–6 and the approved Android fixes form the final FYP submission baseline. The following physical-device checks remain outstanding and were accepted as limitations during approval.

- **Module 5** — Verify notification taps while signed out or locked, and reminder delivery, cancellation, and restoration across app restart and device reboot.
- **Module 6** — Verify PDF viewer handoff, Marketplace form usability, and launching the existing Call and WhatsApp actions.
- **Post-Module 6** — Verify Android bulk import with other document providers. The Android 16 emulator verified picker restoration and reminder scheduling and cancellation. Real notification delivery and taps across reboot and iPhone runtime verification remain open.

---

Built by [Abdul Wahab](https://github.com/DevWahabBaloch), Senior Flutter Developer · [Portfolio](https://devwahabbaloch.web.app/)
