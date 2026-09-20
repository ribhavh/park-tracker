import SwiftUI

/// One day's walk: a map of what you covered that day, plus the percentage change
/// and stats for that visit.
struct VisitDetailView: View {
    @Environment(TrackerModel.self) private var model
    let visit: Visit

    private var highlighted: [PathSegment] { model.highlightedSegments(for: visit) }

    var body: some View {
        ZStack(alignment: .bottom) {
            VisitMapView(parkData: model.parkData, highlighted: highlighted)
                .ignoresSafeArea(edges: .bottom)
            statsCard
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
        .navigationTitle(visit.startedAt.formatted(.dateTime.weekday(.wide).month().day()))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(String(format: "+%.1f%%", visit.gainedPercent * 100))
                    .foregroundStyle(.green)
                Image(systemName: "arrow.right").font(.subheadline).foregroundStyle(.secondary)
                Text(String(format: "%.1f%%", visit.endPercent * 100))
                Text("complete").font(.subheadline).foregroundStyle(.secondary)
            }
            .font(.system(size: 28, weight: .bold, design: .rounded))

            HStack(spacing: 0) {
                metric(String(format: "%.2f", visit.newMiles), "New miles")
                divider
                metric(String(format: "%.1f%%", visit.startPercent * 100), "Was at")
                if !visit.isBackfilled {
                    divider
                    metric(durationText, "Duration")
                }
            }

            Label(visit.isBackfilled
                  ? "Reconstructed from your walk history."
                  : "The brighter green paths are what you covered this day.",
                  systemImage: visit.isBackfilled ? "clock.arrow.circlepath" : "info.circle")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
    }

    private func metric(_ value: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.system(size: 20, weight: .bold, design: .rounded)).monospacedDigit()
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle().fill(.secondary.opacity(0.25)).frame(width: 0.5, height: 32)
    }

    private var durationText: String {
        let total = Int(visit.duration)
        let h = total / 3600, m = (total % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return m > 0 ? "\(m) min" : "\(total)s"
    }
}
