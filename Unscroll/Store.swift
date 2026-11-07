import AudioToolbox
import Foundation
import SwiftUI
import UIKit

// MARK: - Models

struct FocusSession: Codable, Identifiable, Hashable {
    var id = UUID()
    var day: String
    var minutes: Int
    var checks: Int
    var endedAt: Date
}

struct RunningSession: Codable, Hashable {
    var end: Date
    var minutes: Int
    var checks: Int
}

struct GateDay: Codable, Hashable {
    var opens: Int = 0
    var resisted: Int = 0
    var apps: [String: Int] = [:]
}

struct AppCount: Identifiable, Hashable {
    let name: String
    let opens: Int
    var id: String { name }
}

struct AppData: Codable {
    var sessions: [FocusSession] = []
    var usage: [String: Int] = [:]        // day key -> screen time minutes
    var goal: Int = 120                     // daily screen time goal in minutes
    var gate: [String: GateDay] = [:]       // day key -> gate counts
    var train: [String: Int] = [:]          // day key -> drills finished
    var memBest: Int = 0
    var mathBest: Int? = nil
    var running: RunningSession? = nil
    var welcomed: Bool = false
    var notify: Bool = true

    enum CodingKeys: String, CodingKey {
        case sessions, usage, goal, gate, train, memBest, mathBest, running, welcomed, notify
    }

    init() {}

    // Every field is optional when reading, so older saved data keeps loading after updates.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sessions = try c.decodeIfPresent([FocusSession].self, forKey: .sessions) ?? []
        usage = try c.decodeIfPresent([String: Int].self, forKey: .usage) ?? [:]
        goal = try c.decodeIfPresent(Int.self, forKey: .goal) ?? 120
        gate = try c.decodeIfPresent([String: GateDay].self, forKey: .gate) ?? [:]
        train = try c.decodeIfPresent([String: Int].self, forKey: .train) ?? [:]
        memBest = try c.decodeIfPresent(Int.self, forKey: .memBest) ?? 0
        mathBest = try c.decodeIfPresent(Int.self, forKey: .mathBest)
        running = try c.decodeIfPresent(RunningSession.self, forKey: .running)
        welcomed = try c.decodeIfPresent(Bool.self, forKey: .welcomed) ?? false
        notify = try c.decodeIfPresent(Bool.self, forKey: .notify) ?? true
    }
}

// MARK: - Days

enum Day {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func key(_ date: Date = Date()) -> String { formatter.string(from: date) }

    /// The last `count` days, oldest first, each at the start of the day.
    static func back(_ count: Int) -> [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<count).reversed().compactMap { cal.date(byAdding: .day, value: -$0, to: today) }
    }

    static func keys(_ count: Int) -> Set<String> { Set(back(count).map { key($0) }) }
}

// MARK: - Gate pass (shared with the Shortcuts action)

enum GatePass {
    private static let key = "gatePassUntil"

    /// After "Open anyway", the gate stays quiet for this long so it doesn't loop.
    static let minutes = 5

    static func grant() {
        UserDefaults.standard.set(Date().addingTimeInterval(TimeInterval(minutes * 60)), forKey: key)
    }

    static func clear() { UserDefaults.standard.removeObject(forKey: key) }

    static var isActive: Bool {
        guard let until = UserDefaults.standard.object(forKey: key) as? Date else { return false }
        return until > Date()
    }
}

// MARK: - Store

@MainActor
final class Store: ObservableObject {
    @Published var data: AppData { didSet { save() } }
    @Published var focusMessage: String? = nil
    @Published var gateApp: String? = nil
    @Published var gateToken: UUID? = nil

    private let fileURL: URL
    private var lastGateOpen = Date.distantPast

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("unscroll.json")
        if let raw = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(AppData.self, from: raw) {
            data = decoded
        } else {
            data = AppData()
        }
    }

    private func save() {
        guard let raw = try? JSONEncoder().encode(data) else { return }
        try? raw.write(to: fileURL, options: .atomic)
    }

    // MARK: Streak

    var streak: Int {
        var active = Set(data.sessions.map(\.day))
        for (k, v) in data.train where v > 0 { active.insert(k) }
        for (k, v) in data.gate where v.resisted > 0 { active.insert(k) }
        let cal = Calendar.current
        var day = cal.startOfDay(for: Date())
        if !active.contains(Day.key(day)), let y = cal.date(byAdding: .day, value: -1, to: day) { day = y }
        var n = 0
        while active.contains(Day.key(day)) {
            n += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return n
    }

    // MARK: Focus

    func startFocus(minutes: Int) {
        let end = Date().addingTimeInterval(TimeInterval(minutes * 60))
        data.running = RunningSession(end: end, minutes: minutes, checks: 0)
        focusMessage = nil
        updateIdleTimer()
        if data.notify {
            Task {
                if await Notifier.requestPermission() {
                    Notifier.scheduleFocusEnd(at: end, minutes: minutes)
                }
            }
        }
    }

    func giveUp() {
        data.running = nil
        focusMessage = "Session stopped. No minutes counted. Try a shorter one next time."
        Notifier.cancelFocusEnd()
        updateIdleTimer()
    }

    /// Called when the app goes to the background during a session.
    func addCheck() {
        guard var r = data.running, r.end > Date() else { return }
        r.checks += 1
        data.running = r
    }

    /// Finishes the running session if its time is up.
    func tick() {
        guard let r = data.running, r.end <= Date() else { return }
        data.sessions.append(FocusSession(day: Day.key(r.end), minutes: r.minutes, checks: r.checks, endedAt: r.end))
        data.running = nil
        updateIdleTimer()
        let checks = r.checks == 0
            ? "You never left the app. Perfect."
            : "You checked your phone \(r.checks) time\(r.checks == 1 ? "" : "s"). Try for zero next time."
        focusMessage = "Done. \(r.minutes) minutes without the scroll. " + checks
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        AudioServicesPlaySystemSound(1025)
    }

    /// Keeps the screen on during a session, so locking it is a choice.
    func updateIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled = data.running != nil
    }

    func focusMinutes(in days: Set<String>) -> Int {
        data.sessions.filter { days.contains($0.day) }.reduce(0) { $0 + $1.minutes }
    }

    // MARK: Train

    func recordDrill() {
        data.train[Day.key(), default: 0] += 1
    }

    // MARK: Track

    func setUsage(_ minutes: Int, on day: Date) {
        data.usage[Day.key(day)] = min(1440, max(0, minutes))
    }

    // MARK: Gate

    var gateToday: GateDay { data.gate[Day.key()] ?? GateDay() }

    var resistedThisWeek: Int {
        let week = Day.keys(7)
        return data.gate.filter { week.contains($0.key) }.reduce(0) { $0 + $1.value.resisted }
    }

    var topAppsThisWeek: [AppCount] {
        let week = Day.keys(7)
        var totals: [String: Int] = [:]
        for (k, g) in data.gate where week.contains(k) {
            for (name, n) in g.apps { totals[name, default: 0] += n }
        }
        return totals.sorted { $0.value > $1.value }.prefix(5).map { AppCount(name: $0.key, opens: $0.value) }
    }

    /// Called when Shortcuts opens unscroll://gate?app=Name.
    func openGate(app: String?) {
        let trimmed = (app ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? nil : String(trimmed.prefix(30))
        gateApp = name
        if Date().timeIntervalSince(lastGateOpen) > 30 {
            lastGateOpen = Date()
            let k = Day.key()
            var g = data.gate[k] ?? GateDay()
            g.opens += 1
            if let name { g.apps[name, default: 0] += 1 }
            data.gate[k] = g
        }
        gateToken = UUID()
    }

    /// Runs the countdown without counting it, so people can try the gate.
    func practiceGate() {
        gateApp = nil
        gateToken = UUID()
    }

    func resistGate() {
        let k = Day.key()
        var g = data.gate[k] ?? GateDay()
        g.resisted += 1
        data.gate[k] = g
        GatePass.clear()
    }

    func giveInGate() {
        GatePass.grant()
    }

    // MARK: Reset

    func reset() {
        var fresh = AppData()
        fresh.welcomed = true
        data = fresh
        focusMessage = nil
        GatePass.clear()
        Notifier.cancelFocusEnd()
        updateIdleTimer()
    }
}

func hm(_ minutes: Int) -> String {
    "\(minutes / 60) h \(String(format: "%02d", minutes % 60))"
}
