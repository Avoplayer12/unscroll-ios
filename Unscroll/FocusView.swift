import SwiftUI

struct FocusView: View {
    @EnvironmentObject var store: Store
    @State private var selected = 25
    @State private var now = Date()
    private let presets = [10, 25, 45, 60]
    private let ticker = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Header(
                        eyebrow: "Focus",
                        title: "Put the phone face down.",
                        lede: "Pick a time and press Start. The screen stays on while Unscroll is open. Leaving the app or locking the phone counts as a phone check."
                    )
                    presetRow
                    dial
                    controls
                    if let message = store.focusMessage {
                        Text(message)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    stats
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { StreakBadge() }
            }
        }
        .onReceive(ticker) { t in
            now = t
            store.tick()
        }
    }

    private var presetRow: some View {
        HStack(spacing: 8) {
            ForEach(presets, id: \.self) { m in
                Button {
                    selected = m
                } label: {
                    Text("\(m) min")
                        .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .tint(selected == m ? Theme.accent : .secondary)
                .disabled(store.data.running != nil)
                .accessibilityAddTraits(selected == m ? .isSelected : [])
            }
        }
    }

    private var dial: some View {
        let running = store.data.running
        let total = TimeInterval((running?.minutes ?? selected) * 60)
        let left = running.map { max(0, $0.end.timeIntervalSince(now)) } ?? total
        let progress = running == nil ? 0 : 1 - left / total
        let subtitle: String = {
            guard let r = running else { return "ready" }
            if r.checks > 0 { return "\(r.checks) phone check\(r.checks == 1 ? "" : "s")" }
            return "\(r.minutes) min session"
        }()

        return ZStack {
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 12)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.5), value: progress)
            VStack(spacing: 4) {
                Text(clock(left))
                    .font(.system(size: 56, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
        }
        .frame(width: 250, height: 250)
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var controls: some View {
        if store.data.running == nil {
            Button {
                store.startFocus(minutes: selected)
            } label: {
                Text("Start").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        } else {
            Button(role: .destructive) {
                store.giveUp()
            } label: {
                Text("Give up").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }

    private var stats: some View {
        HStack(spacing: 8) {
            StatTile(value: "\(store.focusMinutes(in: [Day.key()]))", label: "focus min today")
            StatTile(value: "\(store.focusMinutes(in: Day.keys(7)))", label: "focus min, 7 days")
            StatTile(value: "\(store.data.sessions.count)", label: "sessions total")
        }
    }

    private func clock(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded(.up))
        return String(format: "%02d:%02d", s / 60, s % 60)
    }
}
