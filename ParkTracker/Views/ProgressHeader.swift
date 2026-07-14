import SwiftUI

/// Floating card over the map: the headline "% of Central Park walked" plus a
/// bar and the raw path count. Designed to read at a glance.
struct ProgressHeader: View {
    let progress: Double      // 0...1
    let coveredMiles: Double
    let totalMiles: Double

    private var percentText: String {
        String(format: "%.1f%%", progress * 100)
    }

    private var milesText: String {
        String(format: "%.1f of %.1f miles walked", coveredMiles, totalMiles)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(percentText)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText(value: progress))
                    .animation(.snappy, value: progress)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Central Park")
                        .font(.subheadline.weight(.semibold))
                    Text("on foot")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            ProgressView(value: progress)
                .tint(.green)
                .animation(.snappy, value: progress)

            Text(milesText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .contentTransition(.numericText(value: coveredMiles))
                .animation(.snappy, value: coveredMiles)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
    }
}

#Preview {
    ZStack {
        Color.green.opacity(0.3).ignoresSafeArea()
        ProgressHeader(progress: 0.412, coveredMiles: 23.8, totalMiles: 57.9)
            .padding()
    }
}
