import CoreLocation

/// Small geometry helpers using a local equirectangular projection.
/// Accurate enough at the scale of a single park (sub-meter error).
enum Geo {
    static func metersPerDegree(atLat lat: Double) -> (lat: Double, lon: Double) {
        let latMeters = 111_320.0
        let lonMeters = 111_320.0 * cos(lat * .pi / 180)
        return (latMeters, lonMeters)
    }

    /// Distance in meters from point `p` to the line segment `a`–`b`.
    static func distance(from p: CLLocationCoordinate2D,
                         toSegment a: CLLocationCoordinate2D,
                         _ b: CLLocationCoordinate2D) -> CLLocationDistance {
        let (mLat, mLon) = metersPerDegree(atLat: p.latitude)
        // Project into local meters with `p` at the origin.
        func xy(_ c: CLLocationCoordinate2D) -> (x: Double, y: Double) {
            ((c.longitude - p.longitude) * mLon, (c.latitude - p.latitude) * mLat)
        }
        let a2 = xy(a), b2 = xy(b)
        let dx = b2.x - a2.x, dy = b2.y - a2.y
        let len2 = dx * dx + dy * dy
        if len2 == 0 { return hypot(a2.x, a2.y) }
        // Projection factor of the origin onto AB, clamped to the segment.
        var t = -(a2.x * dx + a2.y * dy) / len2
        t = max(0, min(1, t))
        let cx = a2.x + t * dx, cy = a2.y + t * dy
        return hypot(cx, cy)
    }
}
