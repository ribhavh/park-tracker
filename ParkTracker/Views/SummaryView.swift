import SwiftUI

/// Post-walk summary: how much this visit moved the needle.
struct SummaryView: View {
    @Environment(TrackerModel.self) private var model
    let summary: SessionSummary

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: summary.increased ? "checkmark.seal.fill" : "figure.walk.motion")
                .font(.system(size: 60))
                .foregroundStyle(summary.increased ? .green : .secondary)

            Text(summary.increased ? "Nice walk!" : "Walk complete")
                .font(.system(size: 32, weight: .bold, design: .rounded))

            if summary.autoStopped {
                Label("Ended automatically — you left the park.",
                      systemImage: "mappin.slash")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if summary.increased {
                VStack(spacing: 10) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(String(format: "%.1f%%", summary.startPercent * 100))
                            .foregroundStyle(.secondary)
                        Image(systemName: "arrow.right")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.1f%%", summary.endPercent * 100))
                            .foregroundStyle(.green)
                    }
                    .font(.system(size: 34, weight: .bold, design: .rounded))

                    Text("Your Central Park completion grew.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Today's Central Park visit didn't increase your completion rate — you covered ground you'd already walked.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            statsRow

            Spacer()

            Button(action: { model.dismissSummary() }) {
                Text("Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .padding(.horizontal, 24)
        }
        .padding()
    }

    private var statsRow: some View {
        HStack(spacing: 0) {
            metric(String(format: "%.2f", summary.milesAdded), "New miles")
            Rectangle().fill(.secondary.opacity(0.25)).frame(width: 0.5, height: 34)
            metric(durationText, "Duration")
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, 24)
    }

    private func metric(_ value: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.system(size: 22, weight: .bold, design: .rounded)).monospacedDigit()
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var durationText: String {
        let total = Int(summary.duration)
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%dh %dm", h, m) : String(format: "%dm %ds", m, s)
    }
}
