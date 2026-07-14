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

The repo ships a real ~2 km Central Park route for the Simulator to "walk":

1. Build & run on a Simulator.
2. When prompted, allow location ("Allow While Using" is enough to see it work;
   "Always" is what enables background tracking).
3. In Xcode: **Debug ▸ Simulate Location ▸ Add GPX File to Project…** and choose
   `Sample/central_park_walk.gpx`, then select it from **Debug ▸ Simulate Location**.
4. Watch the route's paths turn from gray to **green**, and the **% complete** tick up
   (the sample route covers ~3% of the park's ~14,900 path segments).

To test on a **real iPhone**, run on your device, grant "Always" location, and take a
walk in the park — segments mark as you go, and progress persists across relaunches
(stored with SwiftData).

## Regenerating the map data

The bundled path network comes from OpenStreetMap. To refresh or extend it:

```sh
python3 Scripts/fetch_paths.py            # -> ParkTracker/Resources/centralpark_paths.geojson
python3 Scripts/generate_sample_gpx.py    # -> Sample/central_park_walk.gpx
```

## Project layout

```
ParkTracker/
  App/          ParkTrackerApp.swift, Info.plist (location + background modes)
  Models/       PathSegment, ParkData (load + segment + spatial index),
                CoveredSegment (SwiftData), Geo (distance math)
  Location/     LocationManager (Core Location), TrackerModel (coverage engine + state)
  Views/        ParkMapView (MKMapView overlays), ProgressHeader (% card), ContentView
  Resources/    centralpark_paths.geojson (bundled OSM path network)
Scripts/        fetch_paths.py, generate_sample_gpx.py
Sample/         central_park_walk.gpx (Simulator test route)
```
