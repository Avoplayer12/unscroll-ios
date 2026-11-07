import SwiftUI
import UIKit

struct GateView: View {
    enum Stage: Equatable {
        case idle
        case counting(Int)
        case choose
        case resisted
        case gaveIn
    }

    @EnvironmentObject var store: Store
    @State private var stage: Stage = .idle
    @State private var finishedToken: UUID?
    @State private var appName = "TikTok"
    @State private var copied = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Header(eyebrow: "Gate", title: title, lede: lede)
                    stageView
                    HStack(spacing: 8) {
                        StatTile(value: "\(store.gateToday.opens)", label: "gate opens today")
                        StatTile(value: "\(store.gateToday.resisted)", label: "walk-aways today")
                        StatTile(value: "\(store.resistedThisWeek)", label: "walk-aways, 7 days")
                    }
                    if !store.topAppsThisWeek.isEmpty { topApps }
                    setupCard
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { StreakBadge() }
            }
        }
        .task(id: store.gateToken) { await runCountdown() }
    }

    // MARK: Countdown

    private func runCountdown() async {
        guard let token = store.gateToken, token != finishedToken else { return }
        for n in stride(from: 10, through: 1, by: -1) {
            stage = .counting(n)
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if Task.isCancelled { return }
        }
        finishedToken = token
        stage = .choose
    }

    private var name: String { store.gateApp ?? "it" }

    private var title: String {
        switch stage {
        case .idle: return "Think before you scroll."
        case .resisted: return "Good choice."
        case .gaveIn: return "OK. Keep it short."
        case .counting, .choose: return "Wait. Do you really want to open \(name)?"
        }
    }

    private var lede: String {
        switch stage {
        case .idle: return "Set up the gate below. Then every time you open TikTok or Instagram, Unscroll asks first."
        case .counting: return "Breathe for 10 seconds. Then decide."
        case .choose: return "This is gate number \(store.gateToday.opens) today. What do you choose?"
        case .resisted: return "Swipe away \(store.gateApp ?? "that app") and do something real."
        case .gaveIn: return "The gate stays quiet for \(GatePass.minutes) minutes. Switch back to \(store.gateApp ?? "the app") now."
        }
    }

    @ViewBuilder
    private var stageView: some View {
        switch stage {
        case .idle:
            Button {
                store.practiceGate()
            } label: {
                Text("Try the gate").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        case .counting(let n):
            Text("\(n)")
                .font(.system(size: 96, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.accent)
                .frame(maxWidth: .infinity)
                .card()
                .contentTransition(.numericText(countsDown: true))
                .animation(.default, value: n)
        case .choose:
            VStack(spacing: 10) {
                Button {
                    store.resistGate()
                    stage = .resisted
                } label: {
                    Text("I'll do something else").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                Button {
                    store.giveInGate()
                    stage = .gaveIn
                } label: {
                    Text("Open \(name) anyway").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        case .resisted:
            VStack(alignment: .leading, spacing: 8) {
                let r = store.gateToday.resisted
                Text("You walked away \(r) time\(r == 1 ? "" : "s") today.").font(.headline)
                Text("Try a focus session or a 1 minute drill instead.").foregroundStyle(.secondary)
            }
            .card()
        case .gaveIn:
            Text("Tonight, check your total screen time in Track.")
                .card()
        }
    }

    private var topApps: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Most opened this week").font(.headline)
            ForEach(store.topAppsThisWeek) { item in
                HStack {
                    Text(item.name)
                    Spacer()
                    Text("\(item.opens) open\(item.opens == 1 ? "" : "s")")
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .card()
    }

    // MARK: Setup

    private var link: String {
        var c = URLComponents()
        c.scheme = "unscroll"
        c.host = "gate"
        let n = appName.trimmingCharacters(in: .whitespaces)
        if !n.isEmpty { c.queryItems = [URLQueryItem(name: "app", value: n)] }
        return c.string ?? "unscroll://gate"
    }

    private let steps = [
        "Open the **Shortcuts** app and tap **Automation**.",
        "Tap **+**, then **App**. Choose the app, select **Is Opened** and **Run Immediately**, then tap **Next**.",
        "Tap **New Blank Automation**. Add the action **Should Show Gate** from Unscroll.",
        "Add an **If** action: *If Should Show Gate is true*.",
        "Inside the If, add **Open URLs** and paste the link above.",
        "Repeat for each app. When you pick *Open anyway*, the gate stays quiet for 5 minutes so it doesn't loop."
    ]

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Set up the gate").font(.headline)
            TextField("App name", text: $appName)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)
            Text(link)
                .font(.system(.footnote, design: .monospaced))
                .textSelection(.enabled)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            Button(copied ? "Copied" : "Copy link") {
                UIPasteboard.general.string = link
                copied = true
                Task {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    copied = false
                }
            }
            .buttonStyle(.bordered)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(i + 1).").monospacedDigit().foregroundStyle(.secondary)
                        Text(LocalizedStringKey(step))
                    }
                    .font(.subheadline)
                }
            }
        }
        .card()
    }
}
