# Flock Alert — Xcode Project Setup

## Requirements
- Xcode 15.2+
- iOS 17.0+ deployment target
- Apple Developer Account (for device testing with location)

---

## Step 1 — Create Xcode Project

1. Open Xcode → **File → New → Project**
2. Choose: **App** (iOS)
3. Settings:
   - Product Name: `FlockAlert`
   - Bundle ID: `com.flockalert.app`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Storage: **SwiftData** ✅
4. Choose save location → point to this directory

---

## Step 2 — Add Source Files

Drag all files from `FlockAlert/` into the Xcode project navigator:

```
FlockAlertApp.swift
AppState.swift
ContentView.swift
Models/Camera.swift
Models/AlertEvent.swift
Models/CameraReport.swift
Services/OverpassAPIClient.swift
Services/LocationManager.swift
Services/GeofenceManager.swift
Services/AlertDispatcher.swift
Services/SyncManager.swift
Features/Map/MapView.swift
Features/Map/MapViewModel.swift
Features/Map/CameraPin.swift
Features/Map/CameraDetailSheet.swift
Features/Map/FilterView.swift
Features/Alerts/AlertsView.swift
Features/Alerts/AlertSettingsView.swift
Features/Alerts/ProximityBannerView.swift
Features/Report/ReportCameraView.swift
Features/Learn/LearnContent.swift
Features/Learn/LearnView.swift
Features/Learn/ArticleView.swift
Features/Settings/SettingsView.swift
Features/Onboarding/OnboardingView.swift
Design/Theme.swift
Design/HapticManager.swift
Design/Components/GlassCard.swift
Design/Components/FlockTabBar.swift
Resources/SeedCameras.json      ← Add to "Copy Bundle Resources"
Resources/Info.plist             ← Use as project Info.plist
```

---

## Step 3 — Configure Capabilities

In **Xcode → Target → Signing & Capabilities**, add:

| Capability | Notes |
|---|---|
| Location | Required — "Always and When In Use" |
| Background Modes | ✅ Location updates, ✅ Background fetch |
| Push Notifications | For proximity alerts |
| Maps | Automatically included with MapKit |

---

## Step 4 — Info.plist Keys

Use `Resources/Info.plist` as your project Info.plist, OR add these keys manually:

- `NSLocationAlwaysAndWhenInUseUsageDescription`
- `NSLocationAlwaysUsageDescription`
- `NSLocationWhenInUseUsageDescription`
- `NSCameraUsageDescription`
- `NSPhotoLibraryUsageDescription`
- `UIBackgroundModes`: `location`, `fetch`

---

## Step 5 — Build & Run

```
⌘R → Run on device (location testing requires a real device)
```

Simulator will load the map but location simulation is needed for alert testing.

---

## API Architecture

### Overpass API (Live Camera Data)
- Endpoint: `https://overpass-api.de/api/interpreter`
- **Must include** `User-Agent` header — requests without it return 406
- Fallback mirrors: `overpass.kumi.systems`, `overpass.openstreetmap.ru`
- Queries OSM for `surveillance=camera` + Flock Safety tags

### Seed Data
- `SeedCameras.json` — 30 verified public-records camera locations
- Loaded once on first launch via `SyncManager.loadSeedData()`
- Growing database: add entries as FOIA requests return data

---

## Backend (Phase 2)

For production scale, deploy:

```
PostgreSQL + PostGIS   ← Geospatial camera database
Go API (Gin)           ← REST endpoints
Cloudflare R2          ← Photo storage
Redis (Upstash)        ← Geofence cache
Fly.io / Railway       ← Hosting
```

REST endpoints to build:
```
GET  /v1/cameras/nearby?lat=&lng=&radius=
GET  /v1/cameras/tile/{z}/{x}/{y}.mvt
POST /v1/reports
POST /v1/reports/:id/verify
GET  /v1/stats/city/:name
```

---

## App Store Submission Notes

- Category: **Navigation** (primary), **Utilities** (secondary)
- Age rating: 4+
- Privacy nutrition label: Location (used during app & background), no data linked to identity
- Keywords: `surveillance map, ALPR camera, privacy awareness, license plate reader, flock safety, camera alert`
