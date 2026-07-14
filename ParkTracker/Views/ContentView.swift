import SwiftUI
import UIKit
import CoreLocation

struct ContentView: View {
    @Environment(TrackerModel.self) private var model
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack(alignment: .top) {
            ParkMapView(parkData: model.parkData,
                        coveredIDs: model.coveredIDs,
                        coverageVersion: model.coverageVersion)
                .ignoresSafeArea()

            VStack(spacing: 10) {
                ProgressHeader(progress: model.progress,
                               covered: model.coveredCount,
                               total: model.totalCount)
                if needsPermissionPrompt {
                    permissionBanner
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .onAppear { model.startTracking() }
    }

    private var needsPermissionPrompt: Bool {
        model.authStatus == .denied || model.authStatus == .restricted
    }

    private var permissionBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "location.slash.fill")
                .foregroundStyle(.orange)
            Text("Location is off, so your walks aren't being recorded.")
                .font(.footnote)
            Spacer(minLength: 8)
            Button("Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            .font(.footnote.weight(.semibold))
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
