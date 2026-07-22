import SwiftUI
import SwiftData

/// Your Central Park visits, newest first — the story behind the percentage.
struct HistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Visit.startedAt, order: .reverse) private var visits: [Visit]

    var body: some View {
        NavigationStack {
            Group {
                if visits.isEmpty { emptyState } else { list }
            }
            .navigationTitle("Walk history")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var list: some View {
        List {
            Section {
                ForEach(visits) { visit in
                    row(visit)
                }
                .onDelete(perform: delete)
            } header: {
                Text(totals)
            } footer: {
                Text("Deleting a walk removes it from this list only — the paths you walked stay marked on the map.")
            }
        }
    }

    private func row(_ visit: Visit) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(visit.startedAt.formatted(
                .dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()))
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 6) {
                Text(String(format: "+%.1f%%", visit.gainedPercent * 100))
                    .foregroundStyle(.green)
                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(String(format: "%.1f%% complete", visit.endPercent * 100))
            }
            .font(.system(.body, design: .rounded).weight(.bold))

            HStack(spacing: 6) {
                Text(String(format: "%.2f mi new", visit.newMiles))
                Text("·")
                Text(durationText(visit.duration))
                if visit.autoStopped {
                    Text("·")
                    Label("ended automatically", systemImage: "mappin.slash")
                        .labelStyle(.titleAndIcon)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No walks yet", systemImage: "figure.walk")
        } description: {
            Text("Your visits appear here once you've covered new ground in Central Park.")
        }
    }

    private var totals: String {
        let miles = visits.reduce(0) { $0 + $1.newMiles }
        let walks = visits.count
        return String(format: "%d walk%@ · %.1f mi new",
                      walks, walks == 1 ? "" : "s", miles)
    }

    private func durationText(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600, m = (total % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return m > 0 ? "\(m) min" : "\(total)s"
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets { modelContext.delete(visits[index]) }
        try? modelContext.save()
    }
}
