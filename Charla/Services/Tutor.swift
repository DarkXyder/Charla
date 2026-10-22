import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// One answer from the conversation partner.
struct TutorReply {
    var reply: String
    var translation: String
    var correction: String
    var tip: String
    var suggestions: [String]
    var finished: Bool
}

/// Is Apple's on-device model usable on this iPhone, and if not, why.
enum TutorAvailability {
    static var isAvailable: Bool { status == nil }

    /// nil when available, otherwise a short explanation for the profile screen.
    static var status: String? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return nil
            case .unavailable(let reason):
                let r = String(describing: reason)
                if r.contains("deviceNotEligible") { return "This iPhone doesn't support Apple Intelligence (iPhone 15 Pro or newer)." }
                if r.contains("appleIntelligenceNotEnabled") { return "Turn on Apple Intelligence in Settings to chat freely." }
                if r.contains("modelNotReady") { return "Apple Intelligence is still downloading. Try again later." }
                return "Apple Intelligence isn't available right now."
            @unknown default:
                return "Apple Intelligence isn't available right now."
            }
        }
        return "Free conversation needs iOS 26 and Apple Intelligence."
        #else
        return "This build doesn't include the AI partner."
        #endif
    }
}

/// The AI side of a role-play. Created only when `TutorAvailability.isAvailable`.
protocol TutorEngine {
    func opening() async throws -> TutorReply
    func respond(to learner: String) async throws -> TutorReply
}

enum TutorFactory {
    static func make(for scenario: Scenario, name: String) -> TutorEngine? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), TutorAvailability.isAvailable {
            return AppleTutor(scenario: scenario, name: name)
        }
        #endif
        return nil
    }

    static func instructions(_ s: Scenario, name: String) -> String {
        """
        You are \(s.partner), \(s.role). You are role-playing with an English-speaking beginner (CEFR level A1) \
        who is learning Latin American Spanish. The situation: \(s.title). The learner, called \(name), wants to: \(s.goal)

        Rules:
        - Stay in character. Write "reply" only in simple Latin American Spanish: one or two short sentences, \
        present tense, everyday words such as: \(s.vocab).
        - Use "tú" unless your role says "usted". Never use "vosotros".
        - Ask one simple question at a time and steer the conversation towards the learner's goal.
        - If the learner writes in English or seems stuck, answer kindly in simple Spanish.
        - "translation": the English translation of your reply.
        - "correction": if the learner's last message had a real mistake (wrong word, wrong verb form, wrong gender), \
        the corrected Spanish sentence; otherwise an empty string. Ignore missing accents, capital letters and punctuation.
        - "tip": one short English sentence explaining the correction, or an empty string.
        - "suggestions": three short, different Spanish replies the learner could say next, at A1 level.
        - "finished": true once the goal is reached and you have said goodbye, or after about eight exchanges.
        """
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable
struct GeneratedTurn {
    @Guide(description: "Your next line, in simple Latin American Spanish, one or two short sentences")
    var reply: String
    @Guide(description: "English translation of your reply")
    var translation: String
    @Guide(description: "Corrected Spanish version of the learner's last message if it had a mistake, otherwise empty")
    var correction: String
    @Guide(description: "One short English sentence explaining the correction, otherwise empty")
    var tip: String
    @Guide(description: "Three short Spanish replies the learner could say next")
    var suggestions: [String]
    @Guide(description: "True when the conversation goal has been reached and you said goodbye")
    var finished: Bool
}

@available(iOS 26.0, *)
final class AppleTutor: TutorEngine {
    private let session: LanguageModelSession

    init(scenario: Scenario, name: String) {
        session = LanguageModelSession(instructions: TutorFactory.instructions(scenario, name: name))
    }

    func opening() async throws -> TutorReply {
        try await ask("Start the role-play: greet the learner in character and ask your first simple question.")
    }

    func respond(to learner: String) async throws -> TutorReply {
        try await ask("The learner says: \"\(learner)\"")
    }

    private func ask(_ prompt: String) async throws -> TutorReply {
        let response = try await session.respond(to: prompt, generating: GeneratedTurn.self)
        let t = response.content
        return TutorReply(reply: t.reply, translation: t.translation, correction: t.correction, tip: t.tip,
                          suggestions: Array(t.suggestions.prefix(3)), finished: t.finished)
    }
}
#endif
