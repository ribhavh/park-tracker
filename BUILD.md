# Building & Running Park Tracker

A native iOS app that tracks which of **Central Park's walking paths** you've walked
and shows your **% complete** on a live map. Walked paths light up green against the
faded full path network.

## Prerequisites

1. **Xcode** (from the Mac App Store). Not currently installed on this machine — only
   the Swift command-line tools are, which can't build iOS apps.
2. **XcodeGen** to generate the Xcode project from `project.yml`:
   ```sh
   brew install xcodegen
   ```
3. To run on a **physical iPhone** (not just the Simulator): sign into Xcode with a free
   Apple ID (Xcode ▸ Settings ▸ Accounts), then set your team in `project.yml`
   (`DEVELOPMENT_TEAM: ...`) or pick it in the target's Signing tab after generating.
   Note: apps signed with a free Apple ID expire after 7 days; the $99/yr Apple Developer
   Program removes that limit. The Simulator has no such limit.

## Generate the project & open it

```sh
cd "path/to/park-tracker"
xcodegen generate
open ParkTracker.xcodeproj
```

Then **Build & Run** (⌘R). Pick an iOS 17+ Simulator or your device.

## Verify it works (Simulator, no walking required)

The repo ships a real ~1.2 mile Central Park route for the Simulator to "walk":

1. Build & run on a Simulator.
2. When prompted, allow location ("Allow While Using" is enough to see it work;
   "Always" is what enables background tracking).
3. In Xcode: **Debug ▸ Simulate Location ▸ Add GPX File to Project…** and choose
   `Sample/central_park_walk.gpx`, then select it from **Debug ▸ Simulate Location**.
4. Watch the route's paths turn from gray to **green**, and the **miles walked** and
   **% complete** tick up (the sample route covers ~1.2 of the park's ~58 miles of paths).

To test on a **real iPhone**, run on your device, grant "Always" location, and take a
walk in the park — segments mark as you go, and progress persists across relaunches
(stored with SwiftData).

## Where your progress is stored

Progress lives **on the device** in a SwiftData store (SQLite) inside the app's
sandbox: one `CoveredSegment` row per walked path segment. Notes:

- **Deleting the app erases it.** Reinstalling over the top (e.g. re-running from
  Xcode when a 7-day free-provisioning signature expires) *preserves* it.
- It is included in iPhone backups (iCloud/Finder), so a device restore brings it back.
- Turn **off** Settings ▸ App Store ▸ *Offload Unused Apps* — a sideloaded app can't be
  re-downloaded from the App Store.

**Backup / restore / reset** are in the "..." menu on the Home screen: *Export backup*
writes a JSON file you can save or AirDrop, *Import backup* merges one back in, and
*Reset progress* wipes everything (export first).

### Turning on iCloud sync (requires a paid Apple Developer account)

The data model is already CloudKit-compatible (no `.unique` constraints, all properties
have defaults). Free provisioning **cannot** use the iCloud capability, so this needs the
$99/yr Apple Developer Program. Once you have it:

1. In Xcode: target ▸ **Signing & Capabilities** ▸ **+ Capability** ▸ **iCloud**, tick
   **CloudKit**, and create a container (e.g. `iCloud.com.ribhavhora.parktracker`).
2. In `ParkTracker/App/ParkTrackerApp.swift`, build the container with CloudKit:
   ```swift
   let config = ModelConfiguration(cloudKitDatabase: .automatic)
   container = try ModelContainer(for: CoveredSegment.self, configurations: config)
   ```
3. Rebuild. Progress then syncs through your iCloud account and survives app deletion
   and new devices.

## Regenerating the map data

The bundled path network comes from OpenStreetMap. To refresh or extend it:

```sh
python3 Scripts/fetch_paths.py            # -> ParkTracker/Resources/centralpark_paths.geojson
python3 Scripts/fetch_boundary.py         # -> ParkTracker/Resources/centralpark_boundary.geojson
python3 Scripts/generate_sample_gpx.py    # -> Sample/central_park_walk.gpx
```

## Project layout

```
ParkTracker/
  App/          ParkTrackerApp.swift, Info.plist (location + background modes)
  Models/       PathSegment, ParkData (load + segment + spatial index + park boundary),
                CoveredSegment (SwiftData), SessionModels (AppPhase/SessionSummary),
                Geo (distance, bearing, heading math)
  Location/     LocationManager (Core Location), TrackerModel (coverage engine, session
                flow, backup/reset), NotificationManager (summary notification)
  Views/        HomeView (progress map + stats + Start), TrackingView (live session),
                SummaryView, ParkMapView (MKMapView overlays), ContentView, ShareSheet
  Resources/    centralpark_paths.geojson, centralpark_boundary.geojson
Scripts/        fetch_paths.py, fetch_boundary.py, generate_sample_gpx.py
Sample/         central_park_walk.gpx (Simulator test route)
```
