import SwiftUI

struct MoreView: View {
    @EnvironmentObject var store: Store
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Notify me when a focus session ends", isOn: Binding(
                        get: { store.data.notify },
                        set: { store.data.notify = $0 }
                    ))
                } header: {
                    Text("Notifications")
                }

                Section {
                    Button("Delete all my data", role: .destructive) { confirmReset = true }
                } header: {
                    Text("Start over")
                } footer: {
                    Text("Deletes all sessions, drills, screen time and gate counts on this iPhone. This can't be undone.")
                }

                Section {
                    LabeledContent("Version", value: version)
                    Text("Unscroll collects nothing. No ads, no tracking, no account. Your data stays on this iPhone and in your iCloud backup.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("More")
            .confirmationDialog("Delete all your Unscroll data?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Delete everything", role: .destructive) { store.reset() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This can't be undone.")
            }
        }
    }

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}
