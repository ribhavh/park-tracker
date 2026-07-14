import SwiftUI
import MapKit

/// The centerpiece: a full-bleed park map. Every walkway is drawn faded; the
/// segments you've walked are lit up in the accent color on top. A native
/// user-tracking button recenters on you.
struct ParkMapView: UIViewRepresentable {
    let parkData: ParkData
    let coveredIDs: Set<String>
    /// Bumps when coverage grows; drives the covered-overlay rebuild.
    let coverageVersion: Int
    /// When true, the map follows the user's location (blue dot centered).
    var followUser: Bool = false

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

        // Initial covered layer (restored from previous sessions).
        context.coordinator.rebuildCovered(on: map, parkData: parkData, coveredIDs: coveredIDs)
        context.coordinator.lastVersion = coverageVersion

        if followUser {
            map.setUserTrackingMode(.follow, animated: false)
        }

        addTrackingButton(to: map)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        if coverageVersion != context.coordinator.lastVersion {
            context.coordinator.rebuildCovered(on: map, parkData: parkData, coveredIDs: coveredIDs)
            context.coordinator.lastVersion = coverageVersion
        }
        // Re-engage follow if a session just started and we're not already following.
        if followUser, map.userTrackingMode == .none {
            map.setUserTrackingMode(.follow, animated: true)
        }
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
                                           constant: -24),
        ])
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate {
        var baseOverlay: MKMultiPolyline?
        var coveredOverlay: MKMultiPolyline?
        var boundaryOverlay: MKPolygon?
        var lastVersion = -1

        private let walkedColor = UIColor.systemGreen
        private let unwalkedColor = UIColor.tertiaryLabel

        func rebuildCovered(on map: MKMapView, parkData: ParkData, coveredIDs: Set<String>) {
            if let old = coveredOverlay { map.removeOverlay(old) }
            guard !coveredIDs.isEmpty else { coveredOverlay = nil; return }
            let lines = parkData.segments
                .filter { coveredIDs.contains($0.id) }
                .map { MKPolyline(coordinates: [$0.start, $0.end], count: 2) }
            let overlay = MKMultiPolyline(lines)
            coveredOverlay = overlay
            map.addOverlay(overlay, level: .aboveRoads)   // sits on top of the base
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
            if overlay === coveredOverlay {
                renderer.strokeColor = walkedColor
                renderer.lineWidth = 5
            } else {
                renderer.strokeColor = unwalkedColor
                renderer.lineWidth = 2.5
            }
            return renderer
        }
    }
}
