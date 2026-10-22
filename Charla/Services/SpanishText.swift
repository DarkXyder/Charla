import Foundation

/// Comparing what the learner typed or said with the expected Spanish.
enum SpanishText {
    /// Lowercased, punctuation removed (¿?¡!.,), single spaces. Accents kept.
    static func clean(_ s: String) -> String {
        let removed = s.lowercased().unicodeScalars.filter { !CharacterSet.punctuationCharacters.contains($0) && !CharacterSet.symbols.contains($0) }
        return String(String.UnicodeScalarView(removed))
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    /// Also without accents and ñ → n, for lenient matching.
    static func folded(_ s: String) -> String {
        clean(s).folding(options: [.diacriticInsensitive], locale: Locale(identifier: "es"))
    }

    enum Verdict: Equatable {
        case correct
        case accents   // right apart from accents / ñ
        case close     // a small typo
        case wrong
    }

    static func check(_ answer: String, expected: String) -> Verdict {
        let a = clean(answer), e = clean(expected)
        if a == e { return .correct }
        if folded(answer) == folded(expected) { return .accents }
        if similarity(folded(answer), folded(expected)) >= 0.88 { return .close }
        return .wrong
    }

    /// 0…1, from edit distance.
    static func similarity(_ a: String, _ b: String) -> Double {
        let x = Array(a), y = Array(b)
        if x.isEmpty && y.isEmpty { return 1 }
        var prev = Array(0...y.count)
        for i in 1...max(1, x.count) where !x.isEmpty {
            var cur = [i] + Array(repeating: 0, count: y.count)
            for j in stride(from: 1, through: y.count, by: 1) {
                cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (x[i - 1] == y[j - 1] ? 0 : 1))
            }
            prev = cur
        }
        let distance = x.isEmpty ? y.count : prev[y.count]
        return 1 - Double(distance) / Double(max(x.count, y.count))
    }

    /// Speech is judged on words, not spelling: recognisers drop accents and punctuation.
    static func spokenMatch(_ heard: String, expected: String) -> Double {
        similarity(folded(heard), folded(expected))
    }
}
