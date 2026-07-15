import SwiftUI
import MapKit

/// The centerpiece: a full-bleed park map. Every walkway is drawn faded; the
/// segments you've walked are lit up in the accent color on top. A native
/// user-tracking button recenters on you.
struct ParkMapView: UIViewRepresentable {
    let parkData: ParkData
    let coveredIDs: Set<String>
    /// Bumps when coverage grows; nudges SwiftUI to call `updateUIView`.
    let coverageVersion: Int
    /// When true, the map starts out following the user's location.
    var followUser: Bool = false
    /// Bottom inset for the recenter button, so callers can lift it above their
    /// own bottom controls (e.g. the Stop button on the tracking screen).
    var controlsBottomInset: CGFloat = 24

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator

        let config = MKStandardMapConfiguration(elevationStyle: .flat)
        config.pointOfInterestFilter = .excludingAll   // clean canvas; focus on paths
        map.preferredConfiguration = config

        map.showsUserLocation = true
        map.showsCompass = true
        map.isRotateEnabled = true
        map.setRegion(parkData.region, animated: false)
        // Keep the user roughly inside Central Park.
        map.setCameraBoundary(MKMapView.CameraBoundary(coordinateRegion: parkData.region),
                              animated: false)

        context.coordinator.prepare(parkData: parkData)

        // Park outline, drawn beneath the paths.
        if parkData.boundary.count > 2 {
            let outline = MKPolygon(coordinates: parkData.boundary,
                                    count: parkData.boundary.count)
            context.coordinator.boundaryOverlay = outline
            map.addOverlay(outline, level: .aboveRoads)
        }

        // Faded base layer: the entire path network, drawn once.
        let base = MKMultiPolyline(parkData.segments.map {
            MKPolyline(coordinates: [$0.start, $0.end], count: 2)
        })
        context.coordinator.baseOverlay = base
        map.addOverlay(base, level: .aboveRoads)

        // Walked layer, restored from previous sessions.
        context.coordinator.syncCovered(ids: coveredIDs, on: map)
        context.coordinator.lastVersion = coverageVersion

        if followUser {
            map.setUserTrackingMode(.follow, animated: false)
        }

        addTrackingButton(to: map)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        // Only touch overlays when coverage actually grew — updateUIView also runs
        // on unrelated re-renders (e.g. the 1 Hz elapsed-time tick). Deliberately
        // does NOT re-assert follow-mode, so the user can freely pan/zoom during a
        // session and recenter with the button when they want.
        guard coverageVersion != context.coordinator.lastVersion else { return }
        context.coordinator.lastVersion = coverageVersion
        context.coordinator.syncCovered(ids: coveredIDs, on: map)
    }

    private func addTrackingButton(to map: MKMapView) {
        let button = MKUserTrackingButton(mapView: map)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.9)
        button.layer.cornerRadius = 8
        button.layer.masksToBounds = true
        map.addSubview(button)
        NSLayoutConstraint.activate([
            button.trailingAnchor.constraint(equalTo: map.safeAreaLayoutGuide.trailingAnchor,
                                             constant: -16),
            button.bottomAnchor.constraint(equalTo: map.safeAreaLayoutGuide.bottomAnchor,
                                           constant: -controlsBottomInset),
        ])
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate {
        var baseOverlay: MKMultiPolyline?
        var boundaryOverlay: MKPolygon?
        var lastVersion = -1

        private var segmentByID: [String: PathSegment] = [:]
        private var drawnCoveredIDs: Set<String> = []

        private let walkedColor = UIColor.systemGreen
        private let unwalkedColor = UIColor.tertiaryLabel

        /// Build the id → segment lookup once, for cheap incremental redraws.
        func prepare(parkData: ParkData) {
            guard segmentByID.isEmpty else { return }
            segmentByID = Dictionary(
                parkData.segments.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        }

        /// Draw only the segments newly covered since the last call — avoids
        /// rescanning the full network or redrawing the whole walked layer.
        func syncCovered(ids: Set<String>, on map: MKMapView) {
            let delta = ids.subtracting(drawnCoveredIDs)
            guard !delta.isEmpty else { return }
            let lines = delta.compactMap { segmentByID[$0] }
                .map { MKPolyline(coordinates: [$0.start, $0.end], count: 2) }
            if !lines.isEmpty {
                map.addOverlay(MKMultiPolyline(lines), level: .aboveRoads)
            }
            drawnCoveredIDs.formUnion(delta)
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon, overlay === boundaryOverlay {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.strokeColor = walkedColor.withAlphaComponent(0.5)
                renderer.fillColor = walkedColor.withAlphaComponent(0.05)
                renderer.lineWidth = 2
                return renderer
            }
            guard let multi = overlay as? MKMultiPolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }
            let renderer = MKMultiPolylineRenderer(multiPolyline: multi)
            renderer.lineCap = .round
            renderer.lineJoin = .round
            // The base network is the only gray layer; every other multi-polyline
            // is a walked (green) delta.
            if overlay === baseOverlay {
                renderer.strokeColor = unwalkedColor
                renderer.lineWidth = 2.5
            } else {
                renderer.strokeColor = walkedColor
                renderer.lineWidth = 5
            }
            return renderer
        }
    }
}
