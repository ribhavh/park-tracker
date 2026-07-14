import Foundation
import CoreLocation
import MapKit

/// Loads the bundled Central Park path network, splits each way into short
/// segments, and provides a spatial index for fast "which segments are near
/// this GPS point?" lookups.
final class ParkData {

    let segments: [PathSegment]
    let region: MKCoordinateRegion

    /// Uniform grid hash: cell -> indices into `segments`.
    private let index: [GridKey: [Int]]
    private let cellSizeMeters: Double = 50
    private let refLat: Double

    // MARK: - Loading

    /// Loads `centralpark_paths.geojson` from the app bundle. Traps on failure —
    /// the data ships inside the app, so a miss means a build/packaging bug.
    static func loadBundled() -> ParkData {
        guard let url = Bundle.main.url(forResource: "centralpark_paths",
                                        withExtension: "geojson") else {
            fatalError("centralpark_paths.geojson missing from app bundle")
        }
        do {
            let data = try Data(contentsOf: url)
            let fc = try JSONDecoder().decode(FeatureCollection.self, from: data)
            return ParkData(features: fc.features)
        } catch {
            fatalError("Failed to load park data: \(error)")
        }
    }

    init(features: [Feature]) {
        let maxSegmentMeters = 20.0
        var segs: [PathSegment] = []
        segs.reserveCapacity(features.count * 4)

        var minLat = Double.greatestFiniteMagnitude, maxLat = -Double.greatestFiniteMagnitude
        var minLon = Double.greatestFiniteMagnitude, maxLon = -Double.greatestFiniteMagnitude

        for feature in features {
            let coords = feature.geometry.coordinates  // [[lon, lat], ...]
            guard coords.count >= 2 else { continue }
            var pieceIndex = 0
            for i in 0..<(coords.count - 1) {
                let a = CLLocationCoordinate2D(latitude: coords[i][1], longitude: coords[i][0])
                let b = CLLocationCoordinate2D(latitude: coords[i + 1][1], longitude: coords[i + 1][0])
                // Subdivide the edge so no segment is much longer than 20 m.
                let edgeLen = CLLocation(latitude: a.latitude, longitude: a.longitude)
                    .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
                let steps = max(1, Int((edgeLen / maxSegmentMeters).rounded(.up)))
                for s in 0..<steps {
                    let t0 = Double(s) / Double(steps)
                    let t1 = Double(s + 1) / Double(steps)
                    let p0 = Self.lerp(a, b, t0)
                    let p1 = Self.lerp(a, b, t1)
                    segs.append(PathSegment(id: "\(feature.properties.wayId)_\(pieceIndex)",
                                            start: p0, end: p1))
                    pieceIndex += 1
                    for c in [p0, p1] {
                        minLat = min(minLat, c.latitude); maxLat = max(maxLat, c.latitude)
                        minLon = min(minLon, c.longitude); maxLon = max(maxLon, c.longitude)
                    }
                }
            }
        }

        self.segments = segs
        self.refLat = (minLat + maxLat) / 2

        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2,
                                            longitude: (minLon + maxLon) / 2)
        let span = MKCoordinateSpan(latitudeDelta: (maxLat - minLat) * 1.15,
                                    longitudeDelta: (maxLon - minLon) * 1.15)
        self.region = MKCoordinateRegion(center: center, span: span)

        // Build the spatial index (needs refLat, so do it after init of stored props).
        var idx: [GridKey: [Int]] = [:]
        let (mLat, mLon) = Geo.metersPerDegree(atLat: refLat)
        let latCell = cellSizeMeters / mLat
        let lonCell = cellSizeMeters / mLon
        for (i, seg) in segs.enumerated() {
            for c in [seg.start, seg.end] {
                let key = GridKey(x: Int((c.longitude / lonCell).rounded(.down)),
                                  y: Int((c.latitude / latCell).rounded(.down)))
                idx[key, default: []].append(i)
            }
        }
        // Dedup indices per cell (an endpoint shared by two cells can double-add).
        self.index = idx.mapValues { Array(Set($0)) }
    }

    // MARK: - Spatial query

    /// Indices of segments whose endpoints fall within ~`radiusMeters` of `coord`.
    /// A superset for candidate filtering — the caller does exact distance checks.
    func nearbySegmentIndices(to coord: CLLocationCoordinate2D,
                              radiusMeters: Double) -> [Int] {
        let (mLat, mLon) = Geo.metersPerDegree(atLat: refLat)
        let latCell = cellSizeMeters / mLat
        let lonCell = cellSizeMeters / mLon
        let cx = Int((coord.longitude / lonCell).rounded(.down))
        let cy = Int((coord.latitude / latCell).rounded(.down))
        let reach = max(1, Int((radiusMeters / cellSizeMeters).rounded(.up)))

        var out = Set<Int>()
        for dx in -reach...reach {
            for dy in -reach...reach {
                if let bucket = index[GridKey(x: cx + dx, y: cy + dy)] {
                    out.formUnion(bucket)
                }
            }
        }
        return Array(out)
    }

    // MARK: - Helpers

    private static func lerp(_ a: CLLocationCoordinate2D,
                             _ b: CLLocationCoordinate2D,
                             _ t: Double) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: a.latitude + (b.latitude - a.latitude) * t,
                               longitude: a.longitude + (b.longitude - a.longitude) * t)
    }

    private struct GridKey: Hashable { let x: Int; let y: Int }

    // MARK: - GeoJSON decoding

    struct FeatureCollection: Decodable { let features: [Feature] }

    struct Feature: Decodable {
        let properties: Properties
        let geometry: Geometry
    }

    struct Properties: Decodable {
        let wayId: Int
        let name: String
        let highway: String
    }

    struct Geometry: Decodable {
        let type: String
        let coordinates: [[Double]]
    }
}
