import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// The app's front door: your progress painted on the park, your stats, and the
/// Start button. Opening the app should answer "how much of Central Park have I
/// walked?" without having to start a session.
struct HomeView: View {
    @Environment(TrackerModel.self) private var model
    @Environment(\.openURL) private var openURL

    @State private var sharePayload: SharePayload?
    @State private var importing = false
    @State private var confirmingReset = false
    @State private var showingHistory = false
    @State private var message: String?

    var body: some View {
        ZStack(alignment: .top) {
            ParkMapView(parkData: model.parkData,
                        coveredIDs: model.coveredIDs,
                        coverageVersion: model.coverageVersion,
                        followUser: false,
                        controlsBottomInset: 96)
                .ignoresSafeArea()

            VStack(spacing: 10) {
                statsCard
                if model.permissionDenied { permissionNote }
                if let message { infoNote(message) }
                Spacer()
                startButton
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .sheet(item: $sharePayload) { ShareSheet(url: $0.url) }
        .sheet(isPresented: $showingHistory) { HistoryView() }
        .fileImporter(isPresented: $importing,
                      allowedContentTypes: [.json]) { result in
            handleImport(result)
        }
        .confirmationDialog("Reset all progress?",
                            isPresented: $confirmingReset, titleVisibility: .visible) {
            Button("Erase my progress", role: .destructive) {
                model.resetProgress()
                show("Progress reset.")
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This erases every path you've walked. It can't be undone — export a backup first if you want to keep it.")
        }
    }

    // MARK: - Pieces

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(String(format: "%.1f%%", model.progress * 100))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .contentTransition(.numericText(value: model.progress))
                    .animation(.snappy, value: model.progress)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Central Park").font(.subheadline.weight(.semibold))
                    Text("on foot").font(.caption).foregroundStyle(.secondary)
                }
                menu
                    .padding(.leading, 4)
            }

            ProgressView(value: model.progress)
                .tint(.green)
                .animation(.snappy, value: model.progress)

            HStack {
                Text(String(format: "%.1f of %.1f miles walked",
                            model.coveredMiles, model.totalMiles))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button { showingHistory = true } label: {
                    HStack(spacing: 3) {
                        Text("History")
                        Image(systemName: "chevron.right").font(.caption2)
                    }
                    .font(.caption.weight(.semibold))
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
    }

    private var menu: some View {
        Menu {
            Button {
                if let url = model.exportBackup() {
                    sharePayload = SharePayload(url: url)
                } else {
                    show("Couldn't create a backup.")
                }
            } label: {
                Label("Export backup", systemImage: "square.and.arrow.up")
            }
            Button { importing = true } label: {
                Label("Import backup", systemImage: "square.and.arrow.down")
            }
            Divider()
            Button(role: .destructive) { confirmingReset = true } label: {
                Label("Reset progress", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
    }

    private var startButton: some View {
        Button { model.requestStart() } label: {
            Label("Start walk", systemImage: "figure.walk")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .buttonStyle(.borderedProminent)
        .tint(.green)
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
    }

    private func infoNote(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Actions

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let result = model.importBackup(from: url)
            var parts: [String] = []
            if result.segments > 0 { parts.append("\(result.segments) path segments") }
            if result.visits > 0 {
                parts.append("\(result.visits) walk\(result.visits == 1 ? "" : "s")")
            }
            show(parts.isEmpty ? "Nothing new to restore from that file."
                               : "Restored \(parts.joined(separator: " and ")).")
        case .failure:
            show("Couldn't read that file.")
        }
    }

    private func show(_ text: String) {
        message = text
        Task {
            try? await Task.sleep(for: .seconds(3))
            if message == text { message = nil }
        }
    }
}
