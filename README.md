# Prize Bond Checker

Offline-first Flutter app for checking Pakistani prize bonds: it verifies bond numbers against draw results across all 8 denominations, with real-time OCR scanning, background auto-checking and PDF reports.

**Final-year project, BS Software Engineering (Virtual University of Pakistan), graded 4.0/4.0 (A+).**

## Overview

Checking prize bonds by hand means comparing six-digit numbers against long draw lists for each denomination. This app automates that end to end. You scan or enter your bonds once, and the app checks them against every new draw, alerts you to wins, and keeps working without an internet connection.

## Features

- **OCR scanning:** reads 6-digit bond numbers in real time from a live camera stream with Google ML Kit text recognition, using a throttled frame stream and custom rotation handling
- **All 8 denominations:** Rs. 100, 200, 750, 1,500, 7,500, 15,000, 25,000 and 40,000
- **Offline-first storage:** a local Hive data layer with 7 type adapters; draw status recalculates automatically by date
- **Background auto-checking:** saved bonds are checked automatically against new draws
- **Notifications:** a four-channel notification system built on Awesome Notifications
- **Bulk verification:** import bond numbers from TXT or CSV files
- **PDF export:** styled reports of check results
- **Security:** PIN authentication with SHA-256 hashing
- **Admin workflow:** an approval flow for administrative actions
- **Connectivity awareness:** a live online/offline indicator

## Architecture

Layered **presentation → business logic → data** structure:

```text
lib/
├── config/      # app configuration and constants
├── models/      # Hive models + generated type adapters (*.g.dart)
├── services/    # auth (PIN, SHA-256), draw checking, notifications
├── screens/     # check, scanner, bulk check, draws, history, my bonds, notifications, profile, admin
└── widgets/     # bond-number extractor, camera image converter, connectivity badge, filters
```

## Tech stack

Flutter · Dart · Google ML Kit Text Recognition · camera · mobile_scanner · Hive · Awesome Notifications · pdf · file_picker · crypto (SHA-256) · connectivity_plus · timezone · shared_preferences

## Getting started

```bash
flutter pub get
flutter run
```

Camera-based OCR needs a physical Android or iOS device.

---

Built by [Abdul Wahab](https://github.com/DevWahabBaloch), Senior Flutter Developer · [Portfolio](https://devwahabbaloch.web.app/)
