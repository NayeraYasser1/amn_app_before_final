# AMN App — Session Handoff Document

> **Read this fully before touching anything.** It captures a long working session
> (build fixes → feature rebuilds → live on-device verification) so a new session
> can continue seamlessly.

---

## 1. Project Overview & Goals

**AMN** is a Flutter safety / vehicle-assistance app (package `amn_app`,
applicationId `com.example.amn_app`). Features: SOS hold-to-call, emergency
contacts, hospitals & insurance, first-aid guide, parking save/find-my-car,
navigation card, car service (roadside), weather, voice assistant, Firebase
auth, and an optional Raspberry-Pi "car bridge" for in-car hardware commands.

**The user (Nayera / Esraa)** iterates feature-by-feature: they test on a real
tablet, report problems (often with photos), and we fix + verify live on the
device. **Everything must work keyless/free** — no Google Maps API key, no
billing. We use OpenStreetMap (tiles/Nominatim/Overpass), OSRM, Open-Meteo, and
deep links into the external Google Maps app (`google.com/maps/...` URLs).

## 2. Environment & Critical Workflow

| Thing | Value |
|---|---|
| **Project root (CURRENT)** | `C:\Users\asus\Downloads\AMN_UPDATE_ALAA-main (1)\AMN_UPDATE_ALAA-main` |
| Flutter SDK | `C:\scr\flutter_windows_3.32.6-stable\flutter\bin` (3.32.6, add to `$env:Path`) |
| ADB | `C:\Users\asus\AppData\Local\Android\Sdk\platform-tools\adb.exe` |
| Test device | Samsung Galaxy Tab A7 **SM-T505N**, serial `R9KT6006Q1W`, 1200×2000, Android 11, has SIM, pattern lock |
| Firebase | Config copied from sibling project `C:\Users\asus\Downloads\amn_app_callUpdate-main\amn_app_callUpdate-main` (same `com.example.amn_app`) |

### ⚠️ THE GOLDEN DEPLOY RULE (hard-won)
**Incremental builds and attached `flutter run` sessions serve STALE code on
this machine.** The ONLY reliable deploy is:

```powershell
$env:Path += ";C:\scr\flutter_windows_3.32.6-stable\flutter\bin"
Set-Location "C:\Users\asus\Downloads\AMN_UPDATE_ALAA-main (1)\AMN_UPDATE_ALAA-main"
flutter clean; flutter pub get
flutter build apk --debug --no-version-check          # ~1–2 min after clean
& $adb install -r "build\app\outputs\flutter-apk\app-debug.apk"
& $adb shell am force-stop com.example.amn_app        # kill stale process!
& $adb shell monkey -p com.example.amn_app -c android.intent.category.LAUNCHER 1
```

If the user says "nothing changed", it is almost always a stale build/process —
clean-rebuild + force-stop first, THEN debug.

### On-device verification technique
- Screenshot: `adb shell screencap -p /sdcard/x.png; adb pull /sdcard/x.png <dest>; adb shell rm /sdcard/x.png`
  — **use PowerShell, not Git-Bash** (bash mangles `/sdcard/` paths).
- Tap: `adb shell input tap X Y` (screen is 1200×2000, screenshots are 1:1).
- App must be foregrounded ~12-14 s after launch before tapping (slow start).
- `flutter analyze <file>` after every edit — keep it at "No issues found".
- Voice matching can be tested OFFLINE with the harness at
  `<scratchpad>/test_match.dart` (exact copies of the matcher + real catalog) —
  run with `dart.bat test_match.dart`.

## 3. Architecture & Important Files

```
lib/
  main.dart                       # Firebase init w/ duplicate-app guard
  screens/
    home_page.dart                # SOS, quick actions, NAVIGATION CARD (map picker,
                                  #   OSRM ~distance/time, Cancel Trip), LIVE WEATHER card
    map_picker_screen.dart        # Reusable OSM map picker (search-as-you-type via
                                  #   Nominatim, recenter/+/- controls) → returns PickedDestination
    parking_map_screen.dart       # Real OSM map (_ParkingMap), save/find car, notes w/ X-delete,
                                  #   share via clipboard; CameraFit guard (>30 m) prevents NaN crash
    safety_hub_screen.dart        # FULLY REWRITTEN single-file hub: stages enum, PopScope back-fix,
                                  #   contacts CRUD (SharedPreferences), hospitals CRUD (+ map picker),
                                  #   23 first-aid topics w/ numbered steps + Watch Video (YouTube),
                                  #   deep-link params initialSection / initialFirstAidTopic
    voice_assistant_screen.dart   # Speech→catalog matcher→actions; TAPPABLE CHIPS (16);
                                  #   X cancel button; final-result-only handling
    roadside_assistance_screen.dart # CarServiceScreen — keyless "car repair near me" via GMaps
    emergency_history_screen.dart # History w/ filters (All/SOS/Service/Parking/Voice/Calls)
    settings_screen.dart          # custom black bottom bar (matches app-wide style)
    emergency_services_screen.dart, engine_status_screen.dart, ...
    emergency_contacts_screen.dart, hospital_insurance_screen.dart,
    emergency_numbers_screen.dart # LEGACY separate screens still used by some voice intents
  services/
    emergency_history_service.dart # local history (setString JSON, key amn_history_events_json)
    voice_command_sync_service.dart# loads catalog asset; Pi bridge HTTP (192.168.1.8:8876)
    usage_logger.dart              # Firestore logging — PERMISSION-DENIED noise, harmless
  models/emergency_event.dart      # fromMap timestamp SAFELY parsed (was the history-killing bug)
assets/voice/voice_command_catalog.json  # 61 commands, v1.3 — ORDER MATTERS (specific before
                                         #   generic; "call [name]" is LAST)
```

### Key SharedPreferences keys
| Key | Used by |
|---|---|
| `nav_dest_latitude/longitude/label` | home navigation card + voice set/cancel destination |
| `saved_parking_latitude/longitude/saved_at/note` | parking + voice find-my-car |
| `safety_hub_contacts_json` | Safety-Hub contacts + voice "call [name]" |
| `safety_hub_hospitals_json` | Safety-Hub hospitals |
| `amn_history_events_json` | history events |
| `maintenance_reminders_json` | voice maintenance commands (seeded on first use) |

### Voice command pipeline
speech → `_normalize` (lowercase, strip apostrophes, collapse ws) →
`_patternFromPhrase` (`[slot]`→`(.+)`, spaces→`\s+`) → first `hasMatch` in
catalog order wins → `_handleLocalAppAction(item, recognizedText)` (app) or Pi
bridge (software). Dual-target commands **fall back to the app action when the
bridge is offline**. Every command logs to History.

## 4. Completed Work (all verified on the tablet)

1. **Build blockers**: Firebase config restored; `activeThumbColor`→`activeColor`;
   `compileSdk = 36`, `ndkVersion = "27.0.12077973"`, `minSdk = 24`
   (android/app/build.gradle.kts); duplicate-app guard in main.dart.
2. **Car Service**: keyless rewrite — one button → GMaps "car repair near me".
3. **Navigation card**: in-app OSM picker (drag pin + live search w/ 15 results),
   real OSRM driving distance/time shown as `~8.7 km · ~11 min` (estimate "~" is
   a deliberate design decision — free OSRM ≠ Google live traffic), Cancel Trip
   button, tap card → GMaps directions.
4. **Weather card**: live Open-Meteo temp/condition + icon; tap → hourly sheet.
5. **Bottom nav**: identical black bar, white-selected/dim-grey on ALL screens.
6. **Parking**: real OSM map w/ car pin + user dot, add/edit/delete note (X icon),
   Share Location (clipboard), "I Arrived" labeled button, fixed
   `Infinity/NaN toInt` crash (CameraFit.bounds only when points >30 m apart).
7. **History fixed** (was always empty): root cause was
   `data['timestamp'] as DateTime?` hard-cast throwing on String in
   `EmergencyEvent.fromMap` → every event dropped. Also moved storage from
   flaky `getStringList` to `setString` JSON.
8. **Safety Hub rewrite**: real dialer calls (tel:), contacts with relationship
   labels (Mom/Dad/Husband/Best friend/Neighbour) + working add/edit/delete
   (**seed lists MUST stay growable — `const` list seeds silently broke all
   mutations**), hospitals CRUD with address/phone/map-picked coords + real GMaps
   directions, removed fake km/tabs/"View All", PopScope so system-back returns
   to hub home, 23-topic road-accident first-aid guide (user-provided content)
   with numbered step cards + hero icon + "Watch Video" (YouTube search),
   deep-linking for voice.
9. **Voice assistant overhaul**:
   - Fixed matcher (doubled-backslash regexes broke ALL slots + contractions).
   - Removed partial-result auto-fire (it hijacked sentences mid-speech —
     "call po…" → wrong contact lookup). Commands run on FINAL result only;
     `pauseFor: 2 s`.
   - X cancel button beside mic (with `_cancelRequested` guard so plugin errors
     don't overwrite the "Canceled" message); optimistic red-mic on tap;
     "didn't hear anything" reset.
   - Removed the "Car bridge offline" banner and `<··>` AppBar icon.
   - 16 TAPPABLE suggestion chips (chips run `_runTypedCommand`).
   - 61-command catalog incl.: dial police/ambulance/fire/traffic (122/123/180/128),
     call [name] (matches contact name OR relationship), first aid for [topic],
     find my car (walking directions to saved spot), save parking, set/cancel
     destination, what's the weather (spoken), where am I (Nominatim reverse
     geocode — verified returns real street), send my location (SMS composer w/
     GMaps link, clipboard fallback), show nearby hospitals / gas station /
     search for [place] (GMaps near-me search), navigate to [place] (GMaps
     directions, Google geocodes), open maps, send SOS (logs + dials 123),
     maintenance reminders ("show maintenance reminders" / "when is my next
     maintenance" — seeded: Engine check +14 d, Oil change +90 d, Tire rotation
     +180 d, License renewal +365 d).

## 5. What We Were Doing When We Stopped

The last task (add 11 user-requested voice commands) was **completed and
verified** ("where am i" → real address; "when is my next maintenance" →
"Engine check on July 16"). No half-finished edits. The tablet is running the
latest clean build; analyzer is clean; catalog JSON valid (61 commands).

## 6. Pending Bugs / Known Issues / Loose Ends

- **NOTHING IS COMMITTED TO GIT.** All work is uncommitted local changes in
  `AMN_UPDATE_ALAA-main (1)\AMN_UPDATE_ALAA-main`. Offer to commit early.
- **Offered but not built**: a UI screen to view/edit maintenance reminders
  (currently voice-only, seeded dates). User hasn't answered yet.
- Firestore `permission-denied` spam in logcat from `usage_logger.dart` /
  history cloud mirror — harmless (local features unaffected). Could be fixed
  with Firestore rules or by disabling cloud logging.
- Pi car bridge (`http://192.168.1.8:8876`) is offline in the user's setup —
  software-only commands (engine, mirrors, camera…) answer "car software is not
  reachable". Expected; app fallbacks cover the dual-target ones. Note: each
  software-target command pays a ~3 s bridge-status timeout before falling back.
- Legacy screens (emergency_contacts_screen, hospital_insurance_screen) are
  separate from the Safety-Hub versions — voice intents `open_emergency_contacts`
  / `open_hospital_insurance` still open the legacy ones. Possible future
  consolidation.
- 15 pre-existing cosmetic analyzer infos in OTHER files (withOpacity
  deprecations, private-type-in-public-API, etc.) — not errors; the twin project
  had them cleaned, this copy still has them.
- Old test artifacts: a parking spot + contacts/hospitals seeds persist on the
  device from testing (they're user data now, harmless).
- The user's tablet system back button (`KEYCODE_BACK`) and chips coordinates:
  chips row1 y≈485, row2 y≈553, row3 y≈620; Assistant tab (450,1875);
  Safety Hub quick-action (1033,394); mic (600,543)-ish (shifts when banner
  removed → mic now ~(600,334)).

## 7. Design Decisions & Reasoning

- **Keyless everything**: user explicitly rejected Google API key/billing.
  Nominatim/Overpass/OSRM/Open-Meteo + GMaps deep links. Nominatim requires the
  `User-Agent: amn_app/1.0 ...` header. OSM tiles require visible attribution
  (`© OpenStreetMap` widgets exist — keep them).
- **"~" estimates**: app-computed distance/time will never equal Google's
  live-traffic numbers; the user accepted "keep the ~estimate".
- **tel: URIs open the dialer with the number prefilled** (user taps green
  button) — deliberate for safety; no direct-call intent.
- **Catalog order is a contract**: specific app commands at top, generic
  `call [name]` at the very bottom, software entries in between. New specific
  phrases must be inserted ABOVE anything generic that could shadow them.
- **Egypt emergency numbers**: Police 122, Ambulance 123, Fire 180, Traffic 128.
- Seed hospital hotlines (editable in-app): El Salam 19885, Cleopatra 16805,
  Dar Al Fouad 16780.
- All lists that get mutated must be **growable** (no `const []` seeds) — this
  exact mistake silently broke Safety-Hub CRUD once already.

## 8. Exact Next Steps for the New Session

1. Read this file; confirm device connected: `adb devices` → `R9KT6006Q1W  device`
   (if `unauthorized`, have the user re-accept the USB-debugging prompt).
2. **Ask the user whether to commit everything to git** (strongly recommended —
   one commit like "Safety hub rebuild, voice assistant overhaul, parking/nav/
   history fixes"). Remember: on `main`; repo root = project root.
3. Ask if they want the **maintenance-reminders edit screen** (the offered
   follow-up), then continue with whatever feature/problem they report next —
   their pattern is: test on tablet → report issues (sometimes with photos) →
   you fix → clean-build → deploy → verify live via adb screenshots.
4. For ANY voice-matching change: update the catalog AND re-run the offline
   harness (`test_match.dart`, update its copied helpers if the app's matcher
   changes) BEFORE building.
5. Keep using TaskCreate/TaskUpdate for multi-part user requests.

## 9. Gotchas Cheat-Sheet (read before debugging)

- "Nothing changed on the tablet" → stale build/process. `flutter clean` +
  rebuild + `install -r` + `force-stop` + relaunch. ALWAYS.
- PowerShell for adb (bash corrupts `/sdcard/` and binary pulls).
- The app takes 12–14 s to reach Home after launch; taps before that hit the
  wrong screen (this produced several false alarms).
- `PopupMenuButton`/dialog taps via adb need exact coords from a fresh screenshot.
- Device screencap of a locked screen returns black; wake + user unlock needed
  (pattern lock — only the user can unlock).
- Analyzer must stay clean on touched files; the twin folders
  (`AMN_UPDATE_ALAA-main` without "(1)", `amn_app_callUpdate-main`) are OLD —
  do not edit them by mistake.
- `Icons.car_crash`, `Icons.electric_bolt` etc. exist in this Flutter version.
- flutter_map v7: `CameraFit.bounds` with two identical points → Infinity/NaN
  crash. Guard distance > 30 m (already done in parking; remember if reused).
