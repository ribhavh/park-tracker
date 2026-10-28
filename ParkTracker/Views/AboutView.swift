import SwiftUI

/// About, data credits, and a plain-language privacy summary with a link to the
/// full policy. Satisfies OpenStreetMap attribution and App Store privacy needs.
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private let privacyURL = URL(string: "https://github.com/ribhavh/park-tracker/blob/main/PRIVACY.md")!
    private let osmCopyrightURL = URL(string: "https://www.openstreetmap.org/copyright")!

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Central Park Tracker")
                            .font(.headline)
                        Text("Track which of Central Park's paths you've walked, toward 100 percent.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("Location") {
                    Text("Your location is used only while a walk is active, to detect which park paths you pass. Tracking continues in the background so your phone can stay in your pocket, and a blue status pill shows when a walk is running. Nothing is recorded when you are not on a walk.")
                        .font(.footnote)
                    Text("Your progress is stored only on this device. It is never uploaded, and the app has no accounts, ads, or analytics.")
                        .font(.footnote)
                    Button {
                        openURL(privacyURL)
                    } label: {
                        Label("Privacy policy", systemImage: "hand.raised")
                    }
                }

                Section("Data credits") {
                    Text("Path and park boundary data © OpenStreetMap contributors, used under the Open Database License (ODbL).")
                        .font(.footnote)
                    Button {
                        openURL(osmCopyrightURL)
                    } label: {
                        Label("OpenStreetMap copyright", systemImage: "map")
                    }
                    Text("Base map by Apple Maps.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
