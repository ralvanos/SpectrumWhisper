# SpectrumWhisper

**Version:** 1.0.0  
**Package:** `com.io.github.com.ralvanos.spectrumwhisper`  
**Platform:** Android only

Local-first monitor for the radios a phone can already hear. SpectrumWhisper reads broadcast Wi-Fi advertisements, the serving cellular signal the operating system reports, and magnetic readings you type from a handheld meter. It estimates distance, and sorts a radio as a vehicle, hotspot, printer, phone, other, or unknown from the broadcast name and a vendor list kept on the phone. It can log that history and share a snapshot from the phone.

Nothing is joined. Traffic is not captured. Passwords are not collected. Cell identities are not stored.

## Features

* **Live** — field rings, loudest radios, serving cellular type and dBm, latest meter reading, notices, and **Share snapshot**
* **Heat** — 2.4, 5, and 6 GHz channel bars, a waterfall, trend lines, and named spots
* **Radios** — search, filters, security, vendor, visit length, distance, and a manual category
* **Log** — optional signal history, share or copy, a snapshot of this scan or a time range, and the magnetic-field log
* **Settings** — scan interval, bands, distance model, name lists, retention, notices, and the support table

A walk map appears only when **Record position with scans** is on. That setting is off by default. Android still asks for location before it will list nearby Wi-Fi. That permission is not the same as saving your path.

**Snapshot** shares an image of one scan, the last 15 minutes, the last hour, or this session. Text from the same sheet lists every network in that window. The image leaves hardware addresses out.

## What the numbers mean

* **Distance** is a path-loss estimate from the phone's dBm, an assumed transmit power, and an indoor or outdoor exponent. It is not a measurement.
* **Building or vehicle** is a guess from the broadcast name, how long the radio stays, and how much the signal moves. A manual choice wins.
* **Magnetic field** is whatever you type from a meter. Phones do not measure RF magnetic field.
* **Cellular** is the serving radio the phone reports (LTE, 5G, GSM, or WCDMA) plus dBm and the operator name. Tower IDs are not read.

Scans run while the app is in the foreground. Android throttles Wi-Fi scans and does not allow a quiet background sweep.

**Sample environment** in Settings draws a labeled set of radios so the screens can be used on a phone or emulator that cannot scan.

## Setup

Requires [Flutter](https://flutter.dev) 3 (Dart 3) and an Android device or emulator.

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Release APK:

```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk` (gitignored).

The current Gradle file signs release with the debug keystore so a sideload APK installs easily. Sideload installs show **Unknown** as the source; that is the installer, not the signature. For your own signing identity, copy `android/key.properties.example` to `android/key.properties`, add a `spectrumwhisper.jks` keystore, and point `signingConfig` at that file. `key.properties` and `*.jks` are gitignored.

## GitHub (manual)

Do **not** add APKs, `build/`, `.dart_tool/`, `android/local.properties`, `android/key.properties`, or any `.jks` / `.keystore`.

Do add:

* `android/gradlew`, `android/gradlew.bat`, `android/gradle/wrapper/` (including `gradle-wrapper.jar`)
* `android/key.properties.example` (blank template only)
* `README.md`, `LICENSE`, `PRIVACY.md`, `.gitignore`

```bash
git add .
git status
```

Check `git status` for `key.properties`, `*.jks`, `*.apk`, `local.properties`, or `build/` before the first commit. Then create the empty GitHub repo and push (`git remote add origin …` then `git push -u origin main`).

## Privacy

See [PRIVACY.md](PRIVACY.md). Release builds do not request internet permission. Wi-Fi listing still needs the location permission Android requires before it will return scan results.

## Feedback & Support

Questions, ideas, or bug reports are always welcome.

- **Email**: [ralvanos@protonmail.com](mailto:ralvanos@protonmail.com)

### Support the App

SpectrumWhisper is designed to be fully free and ad-free. Donations are completely voluntary. If you contribute and would like recognition, I'll gladly find a way to feature your name.

> "Doubt kills more dreams than failure ever will" - Suzy Kassem

#### Voluntary donations

- **Bitcoin**: `bc1qm0pwaxjyd809v7d606duklmcujn9sygnkgyunx`
- **Monero**: `82sVJnuXRSRGv8RnZGPhpQYssmSAQXT8aXu81CB9iifMB73HKmuMcGNWxmV5s8ELUoaHtJeY13akB7m5f6DMjCDW1mFjtKV`

The same addresses are on the Settings tab. **Send** opens your email app. **Copy** only copies an address on this phone.

## License

MIT — see [LICENSE](LICENSE).
