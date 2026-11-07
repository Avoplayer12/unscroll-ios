import SwiftUI

struct TrainView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Header(
                        eyebrow: "Train",
                        title: "Swap one scroll for one drill.",
                        lede: "Each drill takes about a minute. Finishing one counts toward your streak."
                    )
                    NavigationLink { MathDrillView() } label: {
                        DrillRow(icon: "plus.forwardslash.minus", title: "Math sprint", text: "5 quick problems. Beat your time.")
                    }
                    NavigationLink { MemoryDrillView() } label: {
                        DrillRow(icon: "number", title: "Number memory", text: "Remember longer and longer numbers.")
                    }
                    NavigationLink { BreathView() } label: {
                        DrillRow(icon: "wind", title: "Box breathing", text: "4 rounds of in, hold, out, hold. 64 seconds.")
                    }
                    Text(statsText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { StreakBadge() }
            }
        }
    }

    private var statsText: String {
        var s = "Drills today: \(store.data.train[Day.key()] ?? 0). Best memory: \(store.data.memBest) digits."
        if let best = store.data.mathBest { s += " Best math sprint: \(best) s." }
        return s
    }
}

struct DrillRow: View {
    let icon: String
    let title: String
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Theme.accent)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline).foregroundStyle(.primary)
                Text(text).font(.subheadline).foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }
        .card()
    }
}

// MARK: - Math sprint

struct MathQuestion {
    let text: String
    let answer: Int

    static func random() -> MathQuestion {
        let op = ["+", "−", "×"].randomElement() ?? "+"
        var a: Int
        var b: Int
        if op == "×" {
            a = Int.random(in: 2...12)
            b = Int.random(in: 2...12)
        } else {
            a = Int.random(in: 10...99)
            b = Int.random(in: 10...99)
            if op == "−" && b > a { swap(&a, &b) }
        }
        let answer: Int
        switch op {
        case "+": answer = a + b
        case "−": answer = a - b
        default: answer = a * b
        }
        return MathQuestion(text: "\(a) \(op) \(b)", answer: answer)
    }
}

struct MathDrillView: View {
    @EnvironmentObject var store: Store
    @State private var index = 0
    @State private var right = 0
    @State private var question = MathQuestion.random()
    @State private var input = ""
    @State private var feedback = ""
    @State private var started = Date()
    @State private var result: String?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 20) {
            if let result {
                Text(result)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                    .padding(.top, 24)
                Button("Go again", action: restart)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            } else {
                HStack {
                    Text("\(index + 1) / 5")
                    Spacer()
                    Text("\(right) right")
                }
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(.secondary)

                Text("\(question.text) = ?")
                    .font(.system(size: 44, weight: .bold, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.vertical, 12)

                HStack {
                    TextField("Answer", text: $input)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .font(.title2.monospacedDigit())
                        .focused($focused)
                    Button("Check", action: check)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                }
                Text(feedback).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .navigationTitle("Math sprint")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { restart() }
    }

    private func check() {
        guard let n = Int(input.trimmingCharacters(in: .whitespaces)) else { return }
        if n == question.answer {
            right += 1
            feedback = "Correct."
        } else {
            feedback = "Not quite. \(question.text) = \(question.answer)."
        }
        index += 1
        input = ""
        if index < 5 {
            question = MathQuestion.random()
            return
        }
        let secs = Int(Date().timeIntervalSince(started).rounded())
        var best = ""
        if right == 5, store.data.mathBest.map({ secs < $0 }) ?? true {
            store.data.mathBest = secs
            best = " New best time."
        }
        store.recordDrill()
        focused = false
        result = "\(right) of 5 right in \(secs) seconds." + (right == 5 ? " Perfect round." : "") + best
    }

    private func restart() {
        index = 0
        right = 0
        question = MathQuestion.random()
        input = ""
        feedback = ""
        result = nil
        started = Date()
        focused = true
    }
}

// MARK: - Number memory

struct MemoryDrillView: View {
    enum Phase: Equatable {
        case show(String)
        case ask(String)
        case done(got: Int, number: String)
    }

    @EnvironmentObject var store: Store
    @State private var length = 3
    @State private var phase: Phase = .show("")
    @State private var input = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("\(length) digits")
                Spacer()
                Text("Best: \(store.data.memBest)")
            }
            .font(.system(.footnote, design: .monospaced))
            .foregroundStyle(.secondary)

            switch phase {
            case .show(let number):
                Text(number)
                    .font(.system(size: 44, weight: .bold, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.3)
                    .padding(.vertical, 12)
                Text("Remember this number.").foregroundStyle(.secondary)
            case .ask(let number):
                Text("What was the number?").font(.headline)
                HStack {
                    TextField("Number", text: $input)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .font(.title2.monospacedDigit())
                        .focused($focused)
                    Button("Check") { check(number) }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                }
            case .done(let got, let number):
                Text("You remembered \(got) digits.")
                    .font(.title2.bold())
                    .padding(.top, 12)
                Text("The number was \(number). Most people land between 6 and 8.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Go again") {
                    length = 3
                    nextRound()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            Spacer()
        }
        .padding()
        .navigationTitle("Number memory")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if phase == .show("") { nextRound() } }
        .task(id: phase) {
            guard case .show(let number) = phase, !number.isEmpty else { return }
            try? await Task.sleep(nanoseconds: UInt64(1_000_000_000 + 600_000_000 * number.count))
            guard !Task.isCancelled, phase == .show(number) else { return }
            input = ""
            phase = .ask(number)
            focused = true
        }
    }

    private func nextRound() {
        var s = String(Int.random(in: 1...9))
        for _ in 1..<length { s += String(Int.random(in: 0...9)) }
        phase = .show(s)
    }

    private func check(_ number: String) {
        if input.filter(\.isNumber) == number {
            if length > store.data.memBest { store.data.memBest = length }
            length += 1
            nextRound()
        } else {
            focused = false
            store.recordDrill()
            phase = .done(got: length - 1, number: number)
        }
    }
}

// MARK: - Box breathing

struct BreathView: View {
    @EnvironmentObject var store: Store
    @State private var running = false
    @State private var done = false
    @State private var step = 0
    @State private var seconds = 4
    @State private var expanded = false
    private let phases = ["Breathe in", "Hold", "Breathe out", "Hold"]

    var body: some View {
        VStack(spacing: 24) {
            if done {
                Text("64 seconds of calm.")
                    .font(.title2.bold())
                    .padding(.top, 24)
                Text("Slow breathing like this lowers your heart rate and stress.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Go again") {
                    done = false
                    step = 0
                    running = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                Circle()
                    .fill(Theme.accent.opacity(0.15))
                    .overlay(Circle().stroke(Theme.accent, lineWidth: 2))
                    .frame(width: 200, height: 200)
                    .scaleEffect(expanded ? 1 : 0.6)
                    .animation(.easeInOut(duration: 4), value: expanded)
                    .padding(.top, 24)
                Text(running ? phases[step % 4] : "Get ready")
                    .font(.system(.title, design: .rounded, weight: .semibold))
                HStack {
                    Text("Round \(step / 4 + 1) of 4")
                    Spacer()
                    Text("\(seconds)").monospacedDigit()
                }
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .navigationTitle("Box breathing")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if !done { running = true } }
        .task(id: running) {
            guard running else { return }
            for s in 0..<16 {
                step = s
                if s % 4 == 0 { expanded = true }
                if s % 4 == 2 { expanded = false }
                for t in stride(from: 4, through: 1, by: -1) {
                    seconds = t
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    if Task.isCancelled { return }
                }
            }
            expanded = false
            done = true
            running = false
            store.recordDrill()
        }
    }
}
