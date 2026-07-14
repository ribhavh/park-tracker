import SwiftUI

struct ContentView: View {
    @Environment(TrackerModel.self) private var model

    var body: some View {
        Group {
            switch model.phase {
            case .welcome:
                WelcomeView()
                    .transition(.opacity)
            case .tracking:
                TrackingView()
                    .transition(.opacity)
            case .summary(let summary):
                SummaryView(summary: summary)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: model.phase)
    }
}
