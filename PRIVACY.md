# Privacy Policy

**SpectrumWhisper** is a local-first Android monitor for nearby Wi-Fi advertisements, the serving cellular signal, and magnetic readings you type yourself. Package `com.io.github.com.ralvanos.spectrumwhisper`. Version 1.0.0.

Last updated: 3 October 2026

## Data collection

SpectrumWhisper does **not** run analytics, crash reporting, advertising, or an account system. It has no backend. Release builds do not declare the `INTERNET` permission and do not upload a catalog to the developer.

What it reads stays on the phone unless you choose to share it:

- Broadcast Wi-Fi name, hardware address, frequency, channel width, security flags, and signal strength
- The serving cellular type (LTE, 5G, GSM, or WCDMA), dBm, and operator name
- An optional position, only while **Record position with scans** is on
- Magnetic-field numbers and notes you type from a handheld meter

The app does not join a network, capture traffic, collect passwords, or send deauthentication frames. Cell tower IDs are not requested or stored.

## Data storage

All of this stays in app-private storage on the device:

- The radio catalog and optional signal log
- Named spots, meter readings, and settings, including watch notes
- The encryption key for those files, in the Android keystore

**On-device encryption:** the catalog, log, spots, meter readings, and settings are encrypted with AES-GCM. The key does not leave the phone.

**Sample environment** in Settings is drawn in memory so the screens can be tried without a live scan. It is not saved as a real scan.

A vendor list shipped inside the app (`assets/oui.tsv`) is used offline to label a hardware address. It is not a scan of your network and it is not sent anywhere.

## Sharing

Share and snapshot use the Android share sheet or the clipboard. SpectrumWhisper does not send that message itself.

- A snapshot **image** leaves hardware addresses out.
- Snapshot **text** and the log share can shorten hardware addresses when **Hide hardware addresses when sharing** is on.
- If you share or copy, the destination app is outside SpectrumWhisper. A file you save elsewhere is no longer protected by the app.

## Network access

The **release** app does not declare `INTERNET` and does not make HTTP requests. Debug and profile builds include internet permission only for Flutter tooling.

**Send** on the Settings support table opens your email app with `ralvanos@protonmail.com`. Bitcoin and Monero addresses are copied on the device only if you tap **Copy**.

## Location and cellular

Android will not return a Wi-Fi scan list until location permission is granted and location services are on. That permission is not the same as saving a path.

- **Record position with scans** is off by default. While it is off, scan results are not stored with coordinates.
- While it is on, latitude and longitude from that scan can be kept for the walk map and for a named spot.
- The cellular line is the serving signal type, dBm, and operator name. Tower identity is not read.

Scans run while the app is in the foreground. There is no quiet background sweep.

## Permissions

Used only for the features named:

- Fine and coarse location — Android requires this before it will list nearby Wi-Fi. Optional position recording uses the same permission.
- Wi-Fi state and change Wi-Fi state — ask Android for a scan. The app does not join or reconfigure a network.
- Nearby Wi-Fi devices — Android 13+ permission for the same scan list.
- Location foreground service — declared by the location library. A position is read during a foreground scan only when recording is on.

SpectrumWhisper does not use contacts, microphone, camera, accounts, SMS, or wearable APIs.

## Contact

[ralvanos@protonmail.com](mailto:ralvanos@protonmail.com)
