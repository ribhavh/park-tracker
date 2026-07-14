# park-tracker

An iOS app that shows how much of a park you've completed **on foot** — walk every path
in Central Park and watch your progress toward 100%.

- **Live map** of Central Park with your walked paths lit up in green against the full
  path network.
- **% complete** — the share of the park's walkways you've covered, at a glance.
- **Background tracking** with Core Location, so it keeps recording with your phone in
  your pocket. Progress persists across launches (SwiftData).

Path data is from OpenStreetMap; coverage is tracked at the level of ~20 m path segments.

See **[BUILD.md](BUILD.md)** for how to build, run, and verify it (requires Xcode).
