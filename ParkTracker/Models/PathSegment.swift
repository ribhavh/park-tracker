import CoreLocation

/// A short (~20 m) piece of a Central Park walkway.
///
/// Long OSM ways are cut into these so a path can be *partially* completed as
/// you walk it. The `id` is stable across launches — `"{wayId}_{index}"` — so
/// persisted coverage stays valid as long as the bundled geometry is unchanged.
struct PathSegment: Identifiable {
    let id: String
    let start: CLLocationCoordinate2D
    let end: CLLocationCoordinate2D

    var midpoint: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: (start.latitude + end.latitude) / 2,
                               longitude: (start.longitude + end.longitude) / 2)
    }
}
