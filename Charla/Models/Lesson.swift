import Foundation

/// One step of a lesson.
struct Exercise: Identifiable {
    enum Kind {
        case learn(Item)
        case listen(Item, options: [String])      // hear Spanish, pick the English
        case choose(Item, options: [String])      // read English, pick the Spanish
        case build(Item, tiles: [String])         // tap word tiles into order
        case type(Item)                           // type the Spanish
        case speak(Item)                          // say it aloud
        case match([Item])                        // pair Spanish with English
    }

    let id = UUID()
    let kind: Kind
    /// Repeats of a missed exercise don't repeat again.
    var isRetry = false

    var isGraded: Bool {
        if case .learn = kind { return false }
        return true
    }
}

enum LessonBuilder {
    /// New words in groups of four: learn them, practise each in a different way, then match.
    static func build(_ unit: Unit, speaking: Bool) -> [Exercise] {
        var steps: [Exercise] = []
        let groups = stride(from: 0, to: unit.items.count, by: 4).map { Array(unit.items[$0..<min($0 + 4, unit.items.count)]) }
        var rotation = 0
        var spoken = 0, typed = 0
        for group in groups {
            steps += group.map { Exercise(kind: .learn($0)) }
            var practice: [Exercise] = []
            for item in group {
                let kind: Exercise.Kind
                switch rotation % 5 {
                case 0: kind = .listen(item, options: englishOptions(for: item, in: unit))
                case 1: kind = item.words.count >= 3 ? .build(item, tiles: tiles(for: item, in: unit))
                                                     : .choose(item, options: spanishOptions(for: item, in: unit))
                case 2 where speaking && spoken < 3:
                    kind = .speak(item); spoken += 1
                case 3 where typed < 3 && item.words.count <= 4:
                    kind = .type(item); typed += 1
                default: kind = .choose(item, options: spanishOptions(for: item, in: unit))
                }
                practice.append(Exercise(kind: kind))
                rotation += 1
            }
            steps += practice.shuffled()
            if group.count >= 3 { steps.append(Exercise(kind: .match(group))) }
        }
        return steps
    }

    /// A review lesson for "Practice": no learn cards, only exercises.
    static func practice(_ items: [Item], speaking: Bool) -> [Exercise] {
        let unit = Course.shared.units.first { u in items.contains { u.items.contains($0) } } ?? Course.shared.units[0]
        return items.enumerated().map { i, item in
            switch i % 4 {
            case 0: return Exercise(kind: .listen(item, options: englishOptions(for: item, in: unit)))
            case 1 where item.words.count >= 3: return Exercise(kind: .build(item, tiles: tiles(for: item, in: unit)))
            case 2 where speaking: return Exercise(kind: .speak(item))
            default: return Exercise(kind: .choose(item, options: spanishOptions(for: item, in: unit)))
            }
        }
    }

    // MARK: - distractors

    private static func pool(_ item: Item, _ unit: Unit) -> [Item] {
        let same = unit.items.filter { $0.id != item.id }.shuffled()
        let other = Course.shared.allItems.filter { $0.id != item.id && !same.contains($0) }.shuffled()
        return same + other
    }

    static func englishOptions(for item: Item, in unit: Unit) -> [String] {
        var opts = [item.en]
        for o in pool(item, unit) where !opts.contains(o.en) && opts.count < 4 { opts.append(o.en) }
        return opts.shuffled()
    }

    static func spanishOptions(for item: Item, in unit: Unit) -> [String] {
        var opts = [item.es]
        for o in pool(item, unit) where !opts.contains(o.es) && opts.count < 4 { opts.append(o.es) }
        return opts.shuffled()
    }

    static func tiles(for item: Item, in unit: Unit) -> [String] {
        let own = item.words
        let ownClean = Set(own.map(SpanishText.clean))
        var extra: [String] = []
        for o in pool(item, unit) {
            for w in o.words where !ownClean.contains(SpanishText.clean(w)) && !extra.contains(w) && extra.count < 2 {
                extra.append(w)
            }
            if extra.count >= 2 { break }
        }
        return (own + extra).shuffled()
    }
}
