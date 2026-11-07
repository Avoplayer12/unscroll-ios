import SwiftUI

enum AppTab: Hashable {
    case focus, train, track, gate, more
}

struct ContentView: View {
    @EnvironmentObject var store: Store
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab: AppTab = .focus
    @State private var showWelcome = false

    var body: some View {
        TabView(selection: $tab) {
            FocusView()
                .tabItem { Label("Focus", systemImage: "timer") }
                .tag(AppTab.focus)
            TrainView()
                .tabItem { Label("Train", systemImage: "brain.head.profile") }
                .tag(AppTab.train)
            TrackView()
                .tabItem { Label("Track", systemImage: "chart.bar") }
                .tag(AppTab.track)
            GateView()
                .tabItem { Label("Gate", systemImage: "pause.circle") }
                .tag(AppTab.gate)
            MoreView()
                .tabItem { Label("More", systemImage: "ellipsis.circle") }
                .tag(AppTab.more)
        }
        .onOpenURL { url in
            guard url.scheme == "unscroll" else { return }
            switch url.host {
            case "gate":
                let app = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?.first(where: { $0.name == "app" })?.value
                showWelcome = false
                store.openGate(app: app)
                tab = .gate
            case "focus":
                tab = .focus
            default:
                break
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background: store.addCheck()
            case .active: store.tick(); store.updateIdleTimer()
            default: break
            }
        }
        .onAppear {
            store.tick()
            store.updateIdleTimer()
            if !store.data.welcomed { showWelcome = true }
        }
        .sheet(isPresented: $showWelcome, onDismiss: { store.data.welcomed = true }) {
            WelcomeView()
        }
    }
}

struct WelcomeView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Welcome to Unscroll")
                .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                .padding(.top, 24)
            row("timer", "Focus", "Put the phone away for a set time and keep a streak.")
            row("brain.head.profile", "Train", "A 1 minute brain workout instead of a scroll.")
            row("chart.bar", "Track", "Watch your daily screen time go down.")
            row("pause.circle", "Gate", "Stop and think before TikTok or Instagram opens.")
            Text("No account. Your data stays on this iPhone.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                dismiss()
            } label: {
                Text("Let's start").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(24)
        .interactiveDismissDisabled()
    }

    private func row(_ icon: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Theme.accent)
                .frame(width: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(text).foregroundStyle(.secondary)
            }
        }
    }
}
