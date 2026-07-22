import SwiftUI

/// Active-session screen: a map that follows you, live session stats, and Stop.
struct TrackingView: View {
    @Environment(TrackerModel.self) private var model

    var body: some View {
        ZStack(alignment: .top) {
            ParkMapView(parkData: model.parkData,
                        coveredIDs: model.coveredIDs,
                        coverageVersion: model.coverageVersion,
                        followUser: true,
                        controlsBottomInset: 96)   // clear the Stop button below
                .ignoresSafeArea()

            statsCard
                .padding(.horizontal, 16)
                .padding(.top, 8)

            VStack {
                Spacer()
                stopButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
            }
        }
    }

    private var statsCard: some View {
        HStack(spacing: 0) {
            stat(value: elapsedText, label: "Time")
            divider
            stat(value: String(format: "%.2f", model.sessionMilesAdded), label: "Miles now")
            divider
            stat(value: String(format: "%.1f%%", model.progress * 100), label: "Complete")
        }
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
    }

    private func stat(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle().fill(.secondary.opacity(0.25)).frame(width: 0.5, height: 34)
    }

    private var stopButton: some View {
        Button(role: .destructive, action: { model.stopSession(auto: false) }) {
            Label("Stop walk", systemImage: "stop.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)
    }

    private var elapsedText: String {
        let total = Int(model.sessionElapsed)
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s)
                     : String(format: "%d:%02d", m, s)
    }
}
