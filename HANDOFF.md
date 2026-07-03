# AMN App — Session Handoff

> **Read this fully before touching anything.** It captures a long working session
> (feature fixes → four full read-only audits → systematic remediation of every
> frontend/UI issue) so a new session can continue seamlessly.

---

## 1. Project Overview & Goals

**AMN** is a Flutter safety / vehicle-assistance app (package `amn_app`,
applicationId `com.example.amn_app`). Features: SOS hold-to-call, emergency
contacts, hospitals & insurance, first-aid guide, parking save/find-my-car,
navigation card, car service (roadside), live weather, voice assistant,
Firebase auth, and an optional Raspberry-Pi "car bridge" for in-car hardware.

**The user (Nayera / Esraa)** iterates feature-by-feature and audit-by-audit:
they test on a real tablet, report problems (often with screenshots), and we
fix + verify live on the device, then commit. **Everything must work
keyless/free** — no Google Maps API key, no billing. We use OpenStreetMap
(tiles / Nominatim / Overpass), OSRM, Open-Meteo, and deep links into the
external Google Maps app.

**Working agreement the user has repeated:**
- Fix problems, build, deploy, **verify live on the tablet via screenshots**, then commit.
- The user explicitly deferred all **Backend** problems "for later" and had us fix
  everything on the **Frontend + UI/UX** side first.
- For the SOS emergency messaging, the user plans to pay for the **WhatsApp Cloud
  API later** and route the SOS location+message through it. (This needs a small
  backend relay — the token can't ship in the app.)

---

## 2. Environment & Critical Workflow

| Thing | Value |
|---|---|
| **Project root (CURRENT / live)** | `C:\Users\asus\Downloads\AMN_UPDATE_ALAA-main (1)\AMN_UPDATE_ALAA-main` |
| Flutter SDK | `C:\scr\flutter_windows_3.32.6-stable\flutter\bin` (3.32.6, add to `$env:Path`) |
| ADB | `C:\Users\asus\AppData\Local\Android\Sdk\platform-tools\adb.exe` |
| Test device | Samsung Galaxy Tab A7 **SM-T505N**, serial `R9KT6006Q1W`, 1200×2000, Android 11, has SIM |
| Firebase project | `amngradapp` (google-services.json + firebase_options.dart committed intentionally) |
| Git | repo lives in the **live folder only**; branch `main`; 30 commits |

> ⚠️ **Twin-folder trap:** `C:\Users\asus\Downloads` contains many stale AMN
> copies (`AMN_UPDATE_ALAA-main` without "(1)", `amn_app_callUpdate-main`, etc.).
> **Only the `(1)` folder is live and has the git repo.** The Claude session's
> cwd sometimes starts in an old copy — always use the absolute `(1)` path.

### ⚠️ THE GOLDEN DEPLOY RULE (hard-won)
Incremental/attached builds serve **stale** code on this machine. Reliable deploy:

```powershell
$env:Path += ";C:\scr\flutter_windows_3.32.6-stable\flutter\bin"
Set-Location "C:\Users\asus\Downloads\AMN_UPDATE_ALAA-main (1)\AMN_UPDATE_ALAA-main"
flutter build apk --debug --no-version-check            # ~15s incremental, ~3min after clean
$adb = "C:\Users\asus\AppData\Local\Android\Sdk\platform-tools\adb.exe"
& $adb install -r "build\app\outputs\flutter-apk\app-debug.apk"
& $adb shell am force-stop com.example.amn_app          # kill stale process!
& $adb shell am start -n com.example.amn_app/.MainActivity
```
- **Launch with `am start`, NOT `monkey`** — `monkey` injects a random input
  event that has corrupted on-device test data twice (random taps changed/deleted things).
- App takes **~12–14 s** to reach Home after launch; taps before that hit the wrong screen.
- Screenshot: `adb shell screencap -p /sdcard/x.png; adb pull /sdcard/x.png <dest>; adb shell rm /sdcard/x.png`
  — **use PowerShell, not Git-Bash** (bash mangles `/sdcard/` paths).
- `flutter analyze --no-version-check <files>` after every edit — the project is
  currently at **"No issues found!"** (0 lints); keep it there.
- `flutter test --no-version-check` — **8/8 pass** (real `PasswordValidator` unit tests).

### ⚠️ Committing on Windows PowerShell
`git commit -m` with a here-string **breaks if the message contains double quotes**
(the native arg parser splits on `"`). Use `@'...'@` here-strings and **avoid `"`
and fancy punctuation** in commit messages. Commits are signed off with
`Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.

---

## 3. Architecture & Important Files

51 Dart files (down from 63 — dead code removed this session).

```
lib/
  main.dart                       # Firebase init w/ duplicate-app guard; global dark ThemeData
  screens/
    home_page.dart                # SOS hold-to-call (scroll-cancel, progress fill, Semantics label),
                                  #   quick actions, NAVIGATION card (OSRM ~ETA), LIVE WEATHER card,
                                  #   maintenance alert card. All http.get have .timeout(8s).
    emergency_services_screen.dart# ACTIVE SOS flow: dials 123, live elapsed timer, resolves location,
                                  #   auto-sends SMS to DEFAULT contact + DEFAULT hospital (auto-opens
                                  #   the Messages composer if the silent send fails), "I am safe" end.
    safety_hub_screen.dart        # (~2800 lines) contacts + hospitals CRUD with a "DEFAULT · SOS"
                                  #   badge + set-as-default in the 3-dots menu (exactly one default
                                  #   each); 23-topic first aid; deep-link sections numbers/contacts/
                                  #   hospitals/firstAid. Phone numbers sanitized before tel:.
    sos_alert_service.dart (service) # picks the DEFAULT contact/hospital (falls back to first, then
                                  #   to a seed) for the SOS SMS.
    voice_assistant_screen.dart   # speech->catalog matcher->actions. Matcher is ANCHORED + cached +
                                  #   specificity-ranked (exact beats slotted; order-independent).
                                  #   cancel() on dispose; listen() guarded; dial failures spoken.
    parking_map_screen.dart       # real OSM map (_ParkingMap is now Stateful w/ MapController and
                                  #   RECENTERS on GPS), save/find car, notes, CameraFit >30m guard.
    map_picker_screen.dart        # OSM destination picker: Nominatim search w/ .timeout(8s),
                                  #   request-token (no stale race), ~1.1s throttle, tryParse coords.
    maintenance_reminders_screen.dart # view/add/edit/delete reminders; 10 preset types w/ icons;
                                  #   tap-to-pin onto Home alert card.
    engine_status_screen.dart     # StreamBuilder on user_status; "LIVE" badge only when data is real
                                  #   (updatedAt != null), else "DEMO".
    emergency_history_screen.dart # history w/ filters + per-row X delete (Undo). Lazy ListView.builder.
    roadside_assistance_screen.dart # keyless "car repair near me" via GMaps; getCurrentPosition timeout.
    settings_screen.dart          # black bottom bar; unimplemented rows show a "coming soon" snackbar.
    car_control_screen.dart / pairing_unpaired_screen.dart # MOCK demo screens, labeled "(demo)".
    login/signup/verify_code/forgot_password/reset_password/email_verification/
      complete_profile/edit_profile/car_information/driver_license/driver_status/
      android_call_bridge_status/language_country/pairing_success? (deleted)/splash ...
  services/
    emergency_history_service.dart # local history: writes SERIALIZED via a mutex queue (no lost
                                  #   writes); collision-proof ids; also mirrors to Firestore.
    maintenance_reminders_service.dart # shared maintenance data + icon-per-type + Home-pin logic.
    voice_command_sync_service.dart# loads catalog asset; Pi bridge HTTP (plaintext, 192.168.1.8:8876).
    usage_logger.dart              # Firestore usage_events; write wrapped in try/catch (never breaks flow).
    android_call_bridge_service.dart # MethodChannel to native call bridge.
    auth_service.dart              # email/password auth + secure storage (Google sign-in code removed).
    user_service.dart, cloudinary_service.dart, password_validator.dart, preferences_service.dart
  models/ emergency_event.dart, user_profile.dart   (emergency_contact.dart DELETED — was orphaned)
  utils/ phone.dart (sanitizePhoneNumber), car_options.dart (shared kCarModels/kCarColors), locale_helper.dart
  widgets/ auth_guard.dart, auth_wrapper.dart, my_buttons.dart
  app_localizations.dart           # STUB: ~6 keys in 3 langs (see M12 below)
assets/voice/voice_command_catalog.json  # 61 commands — ORDER no longer critical (matcher is
                                          #   specificity-ranked), but keep specific-before-generic anyway.
android/app/src/main/kotlin/.../AndroidCallBridgeServer.kt # native HTTP call bridge — now binds to
                                          #   127.0.0.1 (loopback) + 64KB request cap (was 0.0.0.0 open).
```

### Firestore collections written
`users`, `user_status`, `usage_events`, `emergency_events`.
**Note:** `emergency_events` has **no `userId` field** — it cannot be user-scoped
by security rules as-is (see C3 below). No rules files are committed.

### Key SharedPreferences keys
`nav_dest_*`, `saved_parking_*`, `safety_hub_contacts_json`,
`safety_hub_hospitals_json` (each item may have `"default": true`),
`amn_history_events_json`, `maintenance_reminders_json`.

---

## 4. Completed Work (this engagement — all committed, analyzer clean, tests green)

Went from ~30 open frontend/UI/safety issues to **zero on that side**. Highlights:

**Safety path:** SOS can't be blocked by a hanging GPS (fires at min(location, 8s) +
10s timeout); stopped seeding/saving fake medical & car data (was saving a fake
"Penicillin allergy"); SMS auto-fallback (opens composer if silent send fails);
default SOS contact + hospital with badge/guard/set-as-default; native call-bridge
network hole closed (loopback + request cap).

**Robustness:** history writes serialized (no lost writes) + stream leak fixed +
collision-proof ids; voice matcher anchored/cached/specificity-ranked (police-dial
can't be shadowed); emergency-dial failure feedback; speech lifecycle (cancel on
dispose, guarded listen); dispose guards + controller disposal; **timeouts on every
`http.get`** (weather, OSRM, Nominatim search+reverse) and remaining
`getCurrentPosition` calls; phone-number sanitizing for `tel:`/`sms:`; guarded
analytics logging; map-search stale-response race + throttle + tryParse.

**Architecture:** unified the two emergency subsystems onto the Safety Hub and
**deleted the dead legacy cluster** (`emergency_contacts_screen`,
`add_emergency_contact_screen`, `calling_contact_screen`, `hospital_insurance_screen`,
`first_aid_screen`, `emergency_numbers_screen`, `sos_emergency_screen`, `menu_screen`),
plus `dashboard_screen`, the orphaned `EmergencyContact` model, `car_driver_status_service`,
`pairing_success_screen`, and the unused `image_upload_widget`/`cloudinary_image_widget`.

**UI/UX:** dead Settings rows now give feedback; demo screens labeled "(demo)"; SOS
button has a Semantics label; honest engine LIVE/DEMO badge; parking map recenters;
dialog validation; global dark `ThemeData`; splash fixes; **all 15 analyzer lints
cleared**; shared car-option constants; nested-Expanded bug fixed; real unit tests added.

Commit range: `2ab6173` … `d581225` (see `git log`). Latest = `d581225`.

---

## 5. What We Were Doing When We Stopped

The pattern for the last several turns was: user asks for a full read-only audit →
we report → user says "fix all frontend" → we fix + verify + commit → user asks
"dig deeper for unseen problems" → we find a few more → fix. The **Frontend bucket
is now genuinely empty** (verified: no remaining `int/double.parse` crash risks,
every Timer cancelled, every `http.get` has a timeout, the one long list is lazy).

No half-finished edits. Tree is clean, analyzer clean, tests pass, latest build is
on the tablet.

---

## 6. Pending Bugs / Issues — the REMAINING work

Everything left is **Backend** (needs the user's decisions/accounts/network) or
**UI/UX content** (needs translations/hardware). None are open frontend Dart bugs.

### 🔴 Critical (Backend — all block production)
- **C1 — Forgot-password OTP = account takeover.** `forgot_password_screen.dart`,
  `verify_code_screen.dart`, `reset_password_screen.dart`. Any phone number → OTP →
  `signInWithCredential` → `updatePassword`, with no check the number belongs to the
  account. Fix: email-reset link, or match-phone-to-account + re-auth. **Needs a UX decision.**
- **C2 — Verification never enforced.** `auth_guard.dart`, `wrapper.dart`,
  `auth_wrapper.dart` admit any signed-in user; `email-verification` route is never
  reached and `sendEmailVerification()` never called. Fix: gate `home` on verification.
- **C3 — No deployed Firestore/Storage rules; `emergency_events` has no `userId`;
  client writes `phone_verified:true` and it's trusted.** Rules exist only as prose in
  `FIREBASE_SECURITY_RULES.md`. Fix: commit strict rules for all 4 collections, add a
  `userId` field to emergency_events, reject client-set verification flags.
- **C4 — Government-ID (license) images on public unsigned Cloudinary URLs.**
  `cloudinary_service.dart`, `user_service.dart`. Fix: signed upload + private delivery.
- **NEW-2 — Release build is debug-signed and uses `com.example.amn_app`.** Can't
  publish; changing the app ID also requires re-registering Firebase (google-services.json).

### 🟠 High
- **H8** — Weak email regex, raw exception text shown to users, no server-side validation.
  `login_screen`, `signup_screen`, `verify_code_screen`.
- **NEW-3** — `SEND_SMS` / `ANSWER_PHONE_CALLS` / default-dialer permissions → Play
  Store rejection without a Permissions Declaration. `AndroidManifest.xml`. (Moving
  SOS to WhatsApp lets you drop `SEND_SMS` and remove the biggest Play blocker.)
- **N-1 — iOS crash:** `ios/Runner/Info.plist` is missing `NSCameraUsageDescription`
  and `NSPhotoLibraryUsageDescription` while `image_picker` uses camera/gallery on
  `car_information_screen`, `complete_profile_screen`, `driver_license_screen` → a
  **guaranteed crash on iPhone** at license upload. **2-line fix; do this first.**

### 🟡 Medium
- **M2** — Pi voice bridge over plaintext HTTP, no auth (`voice_command_sync_service.dart`).
- **M10** — `UserProfile.toMap` resets `createdAt` to now on updates (`user_profile.dart`).
- **N-2** — No global error handling / crash reporting (`runZonedGuarded`,
  `FlutterError.onError`, Crashlytics all absent; `firebase_analytics` declared but unused).
- **N-3** — Two redundant image backends (Firebase Storage for avatars + Cloudinary for licenses).
- **M12 (remainder)** — Global dark theme is in, but screens still hardcode colors and
  **localization is a stub** (10 locales advertised in `main.dart`, ~6 keys in 3 langs in
  `app_localizations.dart`) with **no Arabic RTL**. Needs real human translations — content work.

### 🟢 Low
- **N-4** — Unused `firebase_analytics` dependency.
- **google_sign_in dep** — kept in `pubspec.yaml` **on purpose**: removing it makes
  Gradle resolve a newer `play-services-auth` this build machine **cannot download**
  (SSL/PKIX failure reaching `dl.google.com`). The dead Google-sign-in *code* is
  already removed. Drop the dep line once on a network that can reach Google's Maven.
  (There's a comment in pubspec.yaml explaining this.)
- **NEW-6** — No R8/minify/obfuscation for release (`android/app/build.gradle.kts`).
- **Mock screens** — Pairing & Car Controls are fundamentally mock (now labeled
  "(demo)"). "Real" needs BLE/OBD-II hardware + a backend; user is fine keeping them
  as demo for a grad project.

---

## 7. Design Decisions & Reasoning

- **Keyless everything** — user rejected Google API key/billing. Nominatim/Overpass/
  OSRM/Open-Meteo + GMaps deep links. Nominatim requires `User-Agent: amn_app/1.0 ...`
  and ≤1 req/s (hence the map-search throttle). Keep the "© OpenStreetMap" attribution.
- **SOS dials the dialer with 123 prefilled** (user taps green) — deliberate; no direct-call intent.
- **Egypt emergency numbers:** Police 122, Ambulance 123, Fire 180, Traffic 128.
- **Exactly one default** contact and one default hospital drive the SOS SMS; enforced
  in Safety Hub and read by `sos_alert_service`.
- **WhatsApp for SOS later:** cannot be called directly from the app (token would ship
  in the APK). Needs a backend relay (e.g. a Cloud Function). The SMS path is the interim.
- **Mock screens are labeled, not deleted** — user wants the demo UI for presentation.
- **All lists that get mutated must be growable** (no `const []` seeds) — this exact
  mistake silently broke Safety-Hub CRUD once.
- **`google_sign_in` kept despite being unused** — pure network/environment constraint
  (see N-4 note above), not a design choice.

---

## 8. Important Commands & Setup

```powershell
# One-time per shell
$env:Path += ";C:\scr\flutter_windows_3.32.6-stable\flutter\bin"
Set-Location "C:\Users\asus\Downloads\AMN_UPDATE_ALAA-main (1)\AMN_UPDATE_ALAA-main"
$adb = "C:\Users\asus\AppData\Local\Android\Sdk\platform-tools\adb.exe"

flutter analyze --no-version-check                      # keep at "No issues found!"
flutter test --no-version-check                         # 8/8 pass
flutter build apk --debug --no-version-check
& $adb devices                                          # expect R9KT6006Q1W  device
& $adb install -r "build\app\outputs\flutter-apk\app-debug.apk"
& $adb shell am force-stop com.example.amn_app
& $adb shell am start -n com.example.amn_app/.MainActivity
```
- If `adb devices` shows `unauthorized`, have the user re-accept the USB-debugging prompt.
- If a build fails with an SSL/`dl.google.com` download error, it's the environment
  (see the google_sign_in note) — do NOT remove that dep to "fix" it.

---

## 9. Exact Next Steps for the New Session

1. Read this file. Confirm device: `adb devices` → `R9KT6006Q1W  device`.
2. Confirm state: `flutter analyze` (No issues), `flutter test` (8/8), `git log --oneline -3`
   (top should be `d581225`), `git status` (clean).
3. **The frontend is done.** The remaining work is the Backend bucket in §6, which
   the user has been deferring. Do not invent new frontend fixes — ask the user which
   backend item to start, OR offer the two things that need no decision:
   - **N-1** (iOS plist, 2 lines — prevents a guaranteed iPhone crash). Safe, quick.
   - **N-4 partial** (only when network allows dropping `google_sign_in`).
4. The P0 backend items need the user's input:
   - **C1/C2** — decide the password-reset + email-verification UX before coding.
   - **C3/C4/NEW-2** — need Firebase console + Cloudinary + a release keystore (user's accounts).
   - **C6/SOS messaging** — the user will provide WhatsApp API access; build the relay then.
5. Keep the loop: fix → `flutter analyze` clean → build → deploy → **screenshot-verify
   on the tablet** → commit (mind the PowerShell double-quote pitfall).

---

## 10. Gotchas Cheat-Sheet (read before debugging)

- **"Nothing changed on the tablet"** → stale build/process. Rebuild + `install -r` +
  `force-stop` + `am start`. Launch with `am start`, never `monkey`.
- **PowerShell for adb** (bash corrupts `/sdcard/` and binary pulls).
- The app takes **12–14 s** to reach Home; taps before that hit the wrong screen.
- **Commit messages must not contain `"`** (double quotes) — the native git arg parser
  splits on them and the commit fails. Use `@'...'@` here-strings, plain text.
- **The `(1)` folder is the only live one with git.** Old twins in Downloads are traps.
- **Build SSL error on `dl.google.com`** = environment; don't touch the `google_sign_in` dep.
- `flutter_map` v7: `CameraFit.bounds` with two identical points → Infinity/NaN crash;
  guard distance > 30 m (already done in parking).
- Device screencap of a **locked** screen is black; user must unlock (pattern).
- `emergency_events` Firestore writes have **no `userId`** — remember this when doing C3.
- The user's SOS default contact/hospital and some parking/history entries are **real
  test data** on the device now — don't wipe them casually.
