import Charts
import SwiftUI

struct TrackView: View {
    @EnvironmentObject var store: Store
    @State private var day = Calendar.current.startOfDay(for: Date())
    @State private var hours = 0
    @State private var minutes = 0
    @State private var savedText: String?

    private let goals = [60, 90, 120, 150, 180, 240]
    private let sample = [205, 190, 230, 180, 175, 195, 160, 150, 170, 140, 135, 150, 120, 110]

    struct Bar: Identifiable {
        let id: String
        let date: Date
        let minutes: Int
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Header(
                        eyebrow: "Track",
                        title: "Your screen time, day by day.",
                        lede: "Find today's number in Settings → Screen Time. Add it here each evening."
                    )
                    entryCard
                    chartCard
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { StreakBadge() }
            }
        }
        .onAppear { load(day) }
        .onChange(of: day) { _, newDay in load(newDay) }
    }

    // MARK: Entry

    private var entryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            DatePicker("Day", selection: $day, in: ...Date(), displayedComponents: .date)
            Stepper("Hours: \(hours)", value: $hours, in: 0...24)
            Stepper("Minutes: \(minutes)", value: $minutes, in: 0...59)
            HStack {
                Text("Daily goal")
                Spacer()
                Picker("Daily goal", selection: Binding(get: { store.data.goal }, set: { store.data.goal = $0 })) {
                    ForEach(goals, id: \.self) { Text(hm($0)).tag($0) }
                }
                .pickerStyle(.menu)
            }
            Button(action: save) {
                Text("Save day").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            if let savedText {
                Text(savedText).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .card()
    }

    private func save() {
        store.setUsage(hours * 60 + minutes, on: day)
        savedText = "Saved \(hours) h \(minutes) min for \(day.formatted(date: .abbreviated, time: .omitted))."
    }

    private func load(_ date: Date) {
        if let v = store.data.usage[Day.key(date)] {
            hours = v / 60
            minutes = v % 60
        } else {
            hours = 0
            minutes = 0
        }
        savedText = nil
    }

    // MARK: Chart

    private var isExample: Bool { store.data.usage.isEmpty }

    private var bars: [Bar] {
        var result: [Bar] = []
        for (i, date) in Day.back(14).enumerated() {
            let key = Day.key(date)
            let value: Int? = isExample ? sample[i] : store.data.usage[key]
            if let value { result.append(Bar(id: key, date: date, minutes: value)) }
        }
        return result
    }

    private var chartCard: some View {
        let data = bars
        let goal = store.data.goal
        let highest = max(goal, data.map(\.minutes).max() ?? 0)
        let step = highest > 360 ? 120.0 : 60.0

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Last 14 days").font(.headline)
                Spacer()
                if isExample {
                    Text("Example data")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.accent.opacity(0.15), in: Capsule())
                        .foregroundStyle(Theme.accent)
                }
            }
            Chart {
                ForEach(data) { bar in
                    BarMark(
                        x: .value("Day", bar.date, unit: .day),
                        y: .value("Minutes", bar.minutes)
                    )
                    .foregroundStyle(bar.minutes <= goal ? Theme.good : Theme.warn)
                    .cornerRadius(3)
                }
                RuleMark(y: .value("Goal", goal))
                    .foregroundStyle(Theme.accent)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("goal").font(.caption2.bold()).foregroundStyle(Theme.accent)
                    }
            }
            .chartXScale(domain: (Day.back(14).first ?? Date())...(Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())) ?? Date()))
            .chartYAxis {
                AxisMarks(position: .leading, values: .stride(by: step)) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let m = value.as(Int.self) ?? value.as(Double.self).map({ Int($0) }) {
                            Text("\(m / 60)h")
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 2)) { _ in
                    AxisValueLabel(format: .dateTime.day())
                }
            }
            .frame(height: 210)

            HStack(spacing: 14) {
                legend(Theme.good, "Under goal")
                legend(Theme.warn, "Over goal")
                legend(Theme.accent, "Goal")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text(summary(data))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .card()
    }

    private func legend(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 10, height: 10)
            Text(text)
        }
    }

    private func summary(_ data: [Bar]) -> String {
        guard !data.isEmpty else { return "No days saved in the last 14 days yet." }
        let lastWeek = Day.keys(7)
        let recent = data.filter { lastWeek.contains($0.id) }.map(\.minutes)
        let before = data.filter { !lastWeek.contains($0.id) }.map(\.minutes)
        func avg(_ a: [Int]) -> Double { Double(a.reduce(0, +)) / Double(a.count) }

        var text = isExample ? "Example: " : ""
        text += "Last 7 days average " + (recent.isEmpty ? "–" : hm(Int(avg(recent).rounded()))) + ". "
        if !recent.isEmpty && !before.isEmpty {
            let diff = avg(recent) - avg(before)
            text += (diff <= 0 ? "Down " : "Up ") + hm(Int(abs(diff).rounded())) + " from the week before. "
        }
        let under = data.filter { $0.minutes <= store.data.goal }.count
        text += "\(under) of \(data.count) days under your \(hm(store.data.goal)) goal."
        return text
    }
}
