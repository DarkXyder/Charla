import SwiftUI

enum Theme {
    static let coral = Color(red: 1.0, green: 0.42, blue: 0.33)
    static let teal = Color(red: 0.0, green: 0.62, blue: 0.60)
    static let sun = Color(red: 1.0, green: 0.76, blue: 0.24)
    static let good = Color(red: 0.16, green: 0.70, blue: 0.42)
    static let bad = Color(red: 0.90, green: 0.26, blue: 0.26)
    static let card = Color(.secondarySystemBackground)
}

/// Big rounded primary button.
struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = Theme.coral

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(color.opacity(configuration.isPressed ? 0.8 : 1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .foregroundStyle(.white)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

/// Answer choice: a rounded card that shows right / wrong after checking.
struct ChoiceButton: View {
    let title: String
    let selected: Bool
    var state: Bool? = nil   // nil while answering, true = right answer, false = picked wrong
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body.weight(.medium))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(border, lineWidth: selected || state != nil ? 2 : 1))
        }
        .buttonStyle(.plain)
    }

    private var border: Color {
        if let state { return state ? Theme.good : Theme.bad }
        return selected ? Theme.coral : Color.primary.opacity(0.12)
    }

    private var background: Color {
        if let state { return (state ? Theme.good : Theme.bad).opacity(0.12) }
        return selected ? Theme.coral.opacity(0.1) : Theme.card
    }
}

/// Plays a Spanish phrase; a long press plays it slowly.
struct SpeakButton: View {
    let text: String
    var size: CGFloat = 22
    @ObservedObject private var speaker = Speaker.shared

    var body: some View {
        Image(systemName: "speaker.wave.2.fill")
            .font(.system(size: size))
            .foregroundStyle(Theme.coral)
            .padding(10)
            .background(Theme.coral.opacity(0.12), in: Circle())
            .contentShape(Circle())
            .onTapGesture { speaker.say(text) }
            .onLongPressGesture { speaker.say(text, slow: true) }
            .accessibilityLabel("Play")
            .accessibilityAddTraits(.isButton)
    }
}

/// Hold-free microphone: tap to start, tap to stop.
struct MicButton: View {
    @ObservedObject var listener: Listener
    var size: CGFloat = 64

    var body: some View {
        Button {
            Task { listener.listening ? listener.stop() : await listener.start() }
        } label: {
            Image(systemName: listener.listening ? "stop.fill" : "mic.fill")
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(listener.listening ? Theme.bad : Theme.coral, in: Circle())
                .overlay(Circle().stroke((listener.listening ? Theme.bad : Theme.coral).opacity(0.3), lineWidth: listener.listening ? 10 : 0))
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: listener.listening)
        }
        .accessibilityLabel(listener.listening ? "Stop" : "Speak")
    }
}

/// Spanish characters English keyboards make awkward.
struct AccentBar: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            ForEach(["á", "é", "í", "ó", "ú", "ñ", "¿", "¡"], id: \.self) { c in
                Button(c) { text += c }
                    .font(.title3)
                    .frame(width: 36, height: 40)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 8))
                    .buttonStyle(.plain)
            }
        }
    }
}

/// Little flame + number.
struct StreakBadge: View {
    let days: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill").foregroundStyle(days > 0 ? Theme.coral : .secondary)
            Text("\(days)").font(.headline.monospacedDigit())
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Theme.card, in: Capsule())
    }
}

/// Ring for the daily goal.
struct GoalRing: View {
    let value: Int
    let goal: Int
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            Circle().stroke(Color.primary.opacity(0.1), lineWidth: 5)
            Circle().trim(from: 0, to: min(1, CGFloat(value) / CGFloat(max(goal, 1))))
                .stroke(Theme.sun, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: value >= goal ? "star.fill" : "star").font(.system(size: size * 0.32)).foregroundStyle(Theme.sun)
        }
        .frame(width: size, height: size)
    }
}
