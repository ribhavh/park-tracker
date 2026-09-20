import SwiftUI
import MapKit

/// A static map for one visit: the whole path network drawn very light, with the
/// paths first walked that day highlighted dark green on top. Opens zoomed to the
/// highlighted area.
struct VisitMapView: UIViewRepresentable {
    let parkData: ParkData
    let highlighted: [PathSegment]

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator

        let config = MKStandardMapConfiguration(elevationStyle: .flat)
        config.pointOfInterestFilter = .excludingAll
        map.preferredConfiguration = config
        map.showsUserLocation = false

        // Faint full network underneath.
        let base = MKMultiPolyline(parkData.segments.map {
            MKPolyline(coordinates: [$0.start, $0.end], count: 2)
        })
        context.coordinator.baseOverlay = base
        map.addOverlay(base, level: .aboveRoads)

        // That day's paths on top, with a white casing beneath so a regular-green
        // line stays legible over the green park (the standard route treatment).
        if !highlighted.isEmpty {
            let lines = { highlighted.map { MKPolyline(coordinates: [$0.start, $0.end], count: 2) } }
            let casing = MKMultiPolyline(lines())
            let day = MKMultiPolyline(lines())
            context.coordinator.casingOverlay = casing
            context.coordinator.dayOverlay = day
            map.addOverlay(casing, level: .aboveRoads)
            map.addOverlay(day, level: .aboveRoads)
        }

        map.setRegion(region(), animated: false)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {}

    /// Frame the highlighted paths (or the whole park if there are none).
    private func region() -> MKCoordinateRegion {
        let coords = highlighted.flatMap { [$0.start, $0.end] }
        guard !coords.isEmpty else { return parkData.region }
        let lats = coords.map(\.latitude), lons = coords.map(\.longitude)
        let minLat = lats.min()!, maxLat = lats.max()!
        let minLon = lons.min()!, maxLon = lons.max()!
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2,
                                            longitude: (minLon + maxLon) / 2)
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.6, 0.004),
            longitudeDelta: max((maxLon - minLon) * 1.6, 0.004))
        return MKCoordinateRegion(center: center, span: span)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var baseOverlay: MKMultiPolyline?
        var casingOverlay: MKMultiPolyline?
        var dayOverlay: MKMultiPolyline?

        // Whole network in a soft light green; this day's walk in regular green
        // over a white halo so it reads clearly against the green park.
        private let lightGreen = UIColor.systemGreen.withAlphaComponent(0.40)
        private let regularGreen = UIColor.systemGreen
        private let casingWhite = UIColor.white.withAlphaComponent(0.9)

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let multi = overlay as? MKMultiPolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }
            let renderer = MKMultiPolylineRenderer(multiPolyline: multi)
            renderer.lineCap = .round
            renderer.lineJoin = .round
            if overlay === dayOverlay {
                renderer.strokeColor = regularGreen
                renderer.lineWidth = 5
            } else if overlay === casingOverlay {
                renderer.strokeColor = casingWhite
                renderer.lineWidth = 9
            } else {
                renderer.strokeColor = lightGreen
                renderer.lineWidth = 2.5
            }
            return renderer
        }
    }
}
