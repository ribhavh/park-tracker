# park-tracker

An iOS app that shows how much of a park you have completed **on foot**. Walk
every path in Central Park and watch your progress climb toward 100 percent.

- **Live map** of Central Park with your walked paths lit up in green against the
  full path network.
- **Percent complete** and miles walked, at a glance on the home screen.
- **Walk history** with a per-day dashboard: tap a walk to see the paths you
  covered that day and the percentage change.
- **Background tracking** with Core Location, so it keeps recording with your
  phone in your pocket. Progress is stored on device with SwiftData.
- **Demo mode** replays a sample walk so you can see it work without walking.

## Data and attribution

Path and park boundary data are **© OpenStreetMap contributors**, used under the
Open Database License (ODbL). See https://www.openstreetmap.org/copyright. The
base map is provided by Apple Maps.

## Privacy

Location is used only during an active walk, and your progress stays on your
device (no accounts, ads, or analytics). Full policy: [PRIVACY.md](PRIVACY.md).

## Building

See **[BUILD.md](BUILD.md)** for how to build, run, and verify it. Requires Xcode.
