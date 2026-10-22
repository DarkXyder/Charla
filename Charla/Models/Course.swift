import Foundation

/// The whole beginner course, loaded from Content/course.json.
struct Course: Codable {
    let version: Int
    let language: String
    let voice: String
    let units: [Unit]

    static let shared: Course = {
        guard let url = Bundle.main.url(forResource: "course", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let course = try? JSONDecoder().decode(Course.self, from: data) else {
            fatalError("course.json missing or invalid")
        }
        return course
    }()

    var allItems: [Item] { units.flatMap(\.items) }

    func item(_ id: String) -> Item? { allItems.first { $0.id == id } }
    func unit(_ id: String) -> Unit? { units.first { $0.id == id } }
}

struct Unit: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let titleEs: String
    let icon: String
    let goal: String
    let items: [Item]
    let grammar: Grammar
    let conversation: Scenario
}

/// A word or phrase with its translation.
struct Item: Codable, Identifiable, Hashable {
    let id: String
    let es: String
    let en: String
    let note: String?

    /// Long enough to build from word tiles.
    var words: [String] { es.split(separator: " ").map(String.init) }
}

struct Example: Codable, Hashable {
    let es: String
    let en: String
}

struct Grammar: Codable, Hashable {
    let title: String
    let body: String
    let examples: [Example]
}

/// A role-play. With the on-device AI it's a free conversation steered by `role` and `goal`;
/// without it, the learner follows `script`, picking or saying one of the options.
struct Scenario: Codable, Hashable, Identifiable {
    let id: String
    let title: String
    let partner: String
    let role: String
    let goal: String
    let vocab: String
    let script: [ScriptTurn]
}

struct ScriptTurn: Codable, Hashable {
    let partner: Example
    let options: [ScriptOption]
}

struct ScriptOption: Codable, Hashable {
    let es: String
    let en: String
    let correct: Bool
}

extension String {
    /// Fills in the learner's name in scripted lines.
    func personalized(_ name: String) -> String {
        replacingOccurrences(of: "{name}", with: name)
    }
}
