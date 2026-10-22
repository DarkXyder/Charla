import Foundation

struct ChatMessage: Identifiable, Equatable {
    enum Role { case partner, learner, note }

    let id = UUID()
    let role: Role
    let es: String
    var en: String?
    /// For learner messages: the corrected sentence and why.
    var correction: String?
    var tip: String?
    var good: Bool?
}

/// Runs one role-play, with the on-device AI when available, otherwise following the script.
@MainActor
final class ConversationModel: ObservableObject {
    enum Mode { case ai, guided }

    let scenario: Scenario
    let mode: Mode
    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var suggestions: [String] = []
    @Published private(set) var options: [ScriptOption] = []
    @Published private(set) var busy = false
    @Published private(set) var finished = false
    @Published private(set) var goodTurns = 0

    private let name: String
    private let engine: TutorEngine?
    private var step = 0
    private var exchanges = 0
    private var started = false

    init(scenario: Scenario, name: String, forceGuided: Bool = false) {
        self.scenario = scenario
        self.name = name
        let engine = forceGuided ? nil : TutorFactory.make(for: scenario, name: name)
        self.engine = engine
        mode = engine == nil ? .guided : .ai
    }

    func start() async {
        guard !started else { return }
        started = true
        if let engine {
            busy = true
            do {
                let r = try await engine.opening()
                add(partner: r)
            } catch {
                // Fall back to the scripted opener; the AI can still answer the learner.
                let first = scenario.script[0]
                appendPartner(first.partner.es.personalized(name), first.partner.en.personalized(name))
            }
            busy = false
        } else {
            showScriptTurn()
        }
    }

    func send(_ raw: String) async {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !busy, !finished else { return }
        switch mode {
        case .ai: await sendToAI(text)
        case .guided: answerScript(text)
        }
    }

    // MARK: - AI

    private func sendToAI(_ text: String) async {
        guard let engine else { return }
        let index = messages.count
        messages.append(ChatMessage(role: .learner, es: text))
        suggestions = []
        busy = true
        defer { busy = false }
        do {
            let r = try await engine.respond(to: text)
            let corrected = !r.correction.trimmingCharacters(in: .whitespaces).isEmpty
                && SpanishText.folded(r.correction) != SpanishText.folded(text)
            messages[index].correction = corrected ? r.correction : nil
            messages[index].tip = corrected && !r.tip.isEmpty ? r.tip : nil
            messages[index].good = !corrected
            if !corrected { goodTurns += 1 }
            exchanges += 1
            add(partner: r)
            if r.finished || exchanges >= 10 { finish() }
        } catch {
            messages.append(ChatMessage(role: .note, es: "Your partner couldn't answer that. Try saying it another way."))
        }
    }

    private func add(partner r: TutorReply) {
        appendPartner(r.reply, r.translation)
        suggestions = r.suggestions.filter { !$0.isEmpty }
    }

    // MARK: - guided script

    private func showScriptTurn() {
        let turn = scenario.script[step]
        appendPartner(turn.partner.es.personalized(name), turn.partner.en.personalized(name))
        options = turn.options.map { ScriptOption(es: $0.es.personalized(name), en: $0.en.personalized(name), correct: $0.correct) }.shuffled()
    }

    private func answerScript(_ text: String) {
        let best = options.map { ($0, SpanishText.spokenMatch(text, expected: $0.es)) }.max { $0.1 < $1.1 }
        messages.append(ChatMessage(role: .learner, es: text))
        let i = messages.count - 1
        guard let match = best, match.1 >= 0.7 else {
            messages[i].good = false
            messages.append(ChatMessage(role: .note, es: "Try one of the suggested answers, or say it a little differently."))
            return
        }
        let option = match.0
        guard option.correct else {
            messages[i].good = false
            messages[i].en = option.en
            let right = options.first(where: \.correct)
            messages[i].correction = right?.es
            messages[i].tip = "That doesn't really answer the question. \(right.map { "Try: \($0.en)" } ?? "")"
            return
        }
        messages[i].good = true
        messages[i].en = option.en
        goodTurns += 1
        options = []
        step += 1
        if step < scenario.script.count {
            showScriptTurn()
        } else {
            finish()
        }
    }

    // MARK: -

    private func appendPartner(_ es: String, _ en: String) {
        messages.append(ChatMessage(role: .partner, es: es, en: en))
        Speaker.shared.say(es)
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        options = []
        suggestions = []
        ProgressStore.shared.completeConversation(scenario, xp: 20 + goodTurns * 5)
    }
}
