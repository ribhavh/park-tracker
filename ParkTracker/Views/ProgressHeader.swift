import SwiftUI

/// Floating card over the map: the headline "% of Central Park walked" plus a
/// bar and the raw path count. Designed to read at a glance.
struct ProgressHeader: View {
    let progress: Double      // 0...1
    let covered: Int
    let total: Int

    private var percentText: String {
        String(format: "%.1f%%", progress * 100)
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

            Text("\(covered.formatted()) of \(total.formatted()) path segments walked")
                .font(.caption)
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
}

#Preview {
    ZStack {
        Color.green.opacity(0.3).ignoresSafeArea()
        ProgressHeader(progress: 0.412, covered: 1892, total: 4593)
            .padding()
    }
}
