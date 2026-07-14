import SwiftUI
import UIKit

/// Landing screen: greet the user, show current progress, and start a walk.
struct WelcomeView: View {
    @Environment(TrackerModel.self) private var model
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "tree.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.green)
                Text("Central Park\non foot")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                Text("Let's track your progress toward walking\nevery path in the park.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            progressBadge

            Spacer()

            if model.permissionDenied {
                permissionNote
            }

            Button(action: { model.requestStart() }) {
                Label("Start walk", systemImage: "figure.walk")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .padding(.horizontal, 24)

            Text("We'll ask for location access to record your walk.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 8)
        }
        .padding()
    }

    private var progressBadge: some View {
        VStack(spacing: 6) {
            Text(String(format: "%.1f%%", model.progress * 100))
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(.green)
            Text(String(format: "%.1f of %.1f miles walked",
                        model.coveredMiles, model.totalMiles))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 24)
    }

    private var permissionNote: some View {
        HStack(spacing: 10) {
            Image(systemName: "location.slash.fill").foregroundStyle(.orange)
            Text("Location access is needed to track your walk.")
                .font(.footnote)
            Spacer(minLength: 8)
            Button("Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            .font(.footnote.weight(.semibold))
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 24)
    }
}
