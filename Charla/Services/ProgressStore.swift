import Foundation

/// Spaced-repetition state of one word or phrase (a simplified SM-2).
struct Card: Codable, Hashable {
    let itemId: String
    var ease: Double = 2.5
    var interval: Double = 0   // days
    var reps: Int = 0
    var due: Date
    var lapses: Int = 0

    enum Grade { case again, good, easy }

    mutating func review(_ grade: Grade, now: Date = Date()) {
        switch grade {
        case .again:
            reps = 0
            lapses += 1
            ease = max(1.3, ease - 0.2)
            interval = 0
            due = now.addingTimeInterval(10 * 60) // see it again in this session or soon after
        case .good, .easy:
            reps += 1
            if grade == .easy { ease += 0.15 }
            switch reps {
            case 1: interval = grade == .easy ? 3 : 1
            case 2: interval = grade == .easy ? 6 : 3
            default: interval = (interval * ease * (grade == .easy ? 1.3 : 1)).rounded()
            }
            due = Calendar.current.startOfDay(for: now).addingTimeInterval(interval * 86_400 + 4 * 3600)
        }
    }

    /// Considered learned once it survived a couple of reviews.
    var isLearned: Bool { reps >= 2 }
}

/// Everything the learner has done, saved as one JSON file.
struct ProgressData: Codable {
    var completedUnits: Set<String> = []
    var completedConversations: Set<String> = []
    var cards: [String: Card] = [:]
    var xpByDay: [String: Int] = [:]   // "2026-10-22": 120
    var streak = 0
    var lastActiveDay: String?
    var bestStreak = 0
}

@MainActor
final class ProgressStore: ObservableObject {
    static let shared = ProgressStore()

    @Published private(set) var data = ProgressData()
    @Published var name: String { didSet { UserDefaults.standard.set(name, forKey: "learnerName") } }
    @Published var dailyGoal: Int { didSet { UserDefaults.standard.set(dailyGoal, forKey: "dailyGoal") } }

    private let fileURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("progress.json")
    }()

    private init() {
        name = UserDefaults.standard.string(forKey: "learnerName") ?? ""
        dailyGoal = UserDefaults.standard.object(forKey: "dailyGoal") as? Int ?? 50
        if let d = try? Data(contentsOf: fileURL), let saved = try? JSONDecoder().decode(ProgressData.self, from: d) {
            data = saved
        }
        refreshStreak()
    }

    var displayName: String { name.trimmingCharacters(in: .whitespaces).isEmpty ? "Alex" : name }

    // MARK: - units

    func isCompleted(_ unit: Unit) -> Bool { data.completedUnits.contains(unit.id) }

    /// A unit opens when the one before it is done.
    func isUnlocked(_ unit: Unit) -> Bool {
        guard let i = Course.shared.units.firstIndex(of: unit) else { return false }
        return i == 0 || data.completedUnits.contains(Course.shared.units[i - 1].id)
    }

    var currentUnit: Unit? {
        Course.shared.units.first { !isCompleted($0) && isUnlocked($0) } ?? Course.shared.units.last
    }

    func completeLesson(_ unit: Unit, xp: Int) {
        data.completedUnits.insert(unit.id)
        // Every word of the unit joins the review deck, first due tomorrow.
        let tomorrow = Calendar.current.startOfDay(for: Date()).addingTimeInterval(86_400 + 4 * 3600)
        for item in unit.items where data.cards[item.id] == nil {
            data.cards[item.id] = Card(itemId: item.id, due: tomorrow)
        }
        addXP(xp)
    }

    func completeConversation(_ scenario: Scenario, xp: Int) {
        data.completedConversations.insert(scenario.id)
        addXP(xp)
    }

    func isConversationDone(_ s: Scenario) -> Bool { data.completedConversations.contains(s.id) }

    // MARK: - review deck

    var dueCards: [Card] {
        let now = Date()
        return data.cards.values.filter { $0.due <= now }.sorted { $0.due < $1.due }
    }

    var learnedCount: Int { data.cards.values.filter(\.isLearned).count }
    var seenCount: Int { data.cards.count }

    /// A practice set when nothing is due: the weakest cards first.
    func practiceCards(_ n: Int = 15) -> [Card] {
        Array(data.cards.values.sorted { ($0.reps, -$0.lapses) < ($1.reps, -$1.lapses) }.prefix(n)).shuffled()
    }

    func grade(_ itemId: String, _ g: Card.Grade) {
        guard var c = data.cards[itemId] else { return }
        c.review(g)
        data.cards[itemId] = c
        addXP(g == .again ? 2 : 5)
    }

    // MARK: - XP & streak

    static func dayKey(_ d: Date = Date()) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: d)
    }

    var xpToday: Int { data.xpByDay[Self.dayKey()] ?? 0 }
    var totalXP: Int { data.xpByDay.values.reduce(0, +) }
    var goalReached: Bool { xpToday >= dailyGoal }

    func addXP(_ n: Int) {
        let today = Self.dayKey()
        data.xpByDay[today, default: 0] += n
        if data.lastActiveDay != today {
            let yesterday = Self.dayKey(Date().addingTimeInterval(-86_400))
            data.streak = data.lastActiveDay == yesterday ? data.streak + 1 : 1
            data.lastActiveDay = today
            data.bestStreak = max(data.bestStreak, data.streak)
        }
        save()
    }

    /// A missed day breaks the streak.
    func refreshStreak() {
        let today = Self.dayKey(), yesterday = Self.dayKey(Date().addingTimeInterval(-86_400))
        if let last = data.lastActiveDay, last != today, last != yesterday, data.streak != 0 {
            data.streak = 0
            save()
        }
    }

    /// The last 7 days of XP, oldest first, for the weekly chart.
    var lastWeek: [(day: String, xp: Int)] {
        (0..<7).reversed().map { back in
            let d = Date().addingTimeInterval(Double(-back) * 86_400)
            let f = DateFormatter()
            f.dateFormat = "EEEEE"
            return (f.string(from: d), data.xpByDay[Self.dayKey(d)] ?? 0)
        }
    }

    func reset() {
        data = ProgressData()
        save()
    }

    private func save() {
        if let d = try? JSONEncoder().encode(data) {
            try? d.write(to: fileURL, options: .atomic)
        }
    }
}
