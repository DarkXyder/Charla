import SwiftUI

/// Review flashcards and replay conversations.
struct PracticeView: View {
    @EnvironmentObject private var progress: ProgressStore
    @State private var review: ReviewSession?
    @State private var practice: PracticeSession?
    @State private var chat: Scenario?
    private let course = Course.shared

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Review", systemImage: "rectangle.stack.fill").font(.headline).foregroundStyle(Theme.coral)
                    Text(progress.dueCards.isEmpty
                         ? (progress.seenCount == 0 ? "Finish a lesson to start your review deck." : "Nothing due. Come back tomorrow, or practise anyway.")
                         : "\(progress.dueCards.count) words and phrases are due. Reviewing them right before you'd forget makes them stick.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    if !progress.dueCards.isEmpty {
                        Button("Review \(progress.dueCards.count) cards") { review = ReviewSession(cards: progress.dueCards) }
                            .buttonStyle(PrimaryButtonStyle())
                    }
                    if progress.seenCount > 0 {
                        Button("Practice exercises") {
                            practice = PracticeSession(items: progress.practiceCards(12).compactMap { course.item($0.itemId) })
                        }
                        .buttonStyle(PrimaryButtonStyle(color: Theme.teal))
                    }
                }
                .padding(.vertical, 6)
            }

            Section("Conversations") {
                ForEach(course.units) { unit in
                    let open = progress.isCompleted(unit)
                    Button { chat = unit.conversation } label: {
                        HStack(spacing: 12) {
                            Image(systemName: progress.isConversationDone(unit.conversation) ? "checkmark.bubble.fill" : "bubble.left.and.bubble.right.fill")
                                .foregroundStyle(open ? Theme.teal : .secondary)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(unit.conversation.title).foregroundStyle(.primary)
                                Text(open ? "With \(unit.conversation.partner)" : "Finish \"\(unit.title)\" to unlock")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if !open { Image(systemName: "lock.fill").foregroundStyle(.tertiary) }
                        }
                    }
                    .disabled(!open)
                }
            } footer: {
                Text(TutorAvailability.status ?? "Your partner runs on this iPhone with Apple Intelligence: private, and it works offline.")
            }
        }
        .navigationTitle("Practice")
        .fullScreenCover(item: $review) { ReviewView(cards: $0.cards) }
        .fullScreenCover(item: $practice) { LessonView(practice: $0.items) }
        .fullScreenCover(item: $chat) { ChatView(scenario: $0) }
    }
}

private struct ReviewSession: Identifiable {
    let id = UUID()
    let cards: [Card]
}

private struct PracticeSession: Identifiable {
    let id = UUID()
    let items: [Item]
}

/// Flashcards: hear it, recall the meaning, flip, rate yourself.
struct ReviewView: View {
    @State var cards: [Card]
    @EnvironmentObject private var progress: ProgressStore
    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    @State private var flipped = false
    @State private var reviewed = 0

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Button { dismiss() } label: { Image(systemName: "xmark").font(.headline).foregroundStyle(.secondary) }
                ProgressView(value: Double(index), total: Double(max(cards.count, 1))).tint(Theme.coral)
                Text("\(min(index + 1, cards.count))/\(cards.count)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            if index < cards.count, let item = Course.shared.item(cards[index].itemId) {
                Spacer()
                VStack(spacing: 16) {
                    Text(item.es).font(.largeTitle.weight(.bold)).multilineTextAlignment(.center)
                    SpeakButton(text: item.es, size: 26)
                    if flipped {
                        Divider()
                        Text(item.en).font(.title2).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        if let note = item.note { Text(note).font(.footnote).foregroundStyle(.tertiary) }
                    } else {
                        Text("Do you remember what it means?").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .padding(28)
                .frame(maxWidth: .infinity)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 24))
                .onTapGesture { flipped = true }
                Spacer()
                if flipped {
                    HStack(spacing: 10) {
                        gradeButton("Again", Theme.bad, .again)
                        gradeButton("Good", Theme.teal, .good)
                        gradeButton("Easy", Theme.good, .easy)
                    }
                } else {
                    Button("Show answer") { flipped = true }.buttonStyle(PrimaryButtonStyle())
                }
            } else {
                Spacer()
                Image(systemName: "checkmark.seal.fill").font(.system(size: 60)).foregroundStyle(Theme.good)
                Text("Review done!").font(.largeTitle.weight(.bold))
                Text("\(reviewed) cards reviewed").foregroundStyle(.secondary)
                Spacer()
                Button("Continue") { dismiss() }.buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding()
        .onAppear(perform: play)
        .onChange(of: index) { _, _ in play() }
    }

    private func gradeButton(_ title: String, _ color: Color, _ g: Card.Grade) -> some View {
        Button(title) {
            let card = cards[index]
            progress.grade(card.itemId, g)
            reviewed += 1
            // Forgotten cards come back at the end of this session.
            if g == .again { cards.append(card) }
            flipped = false
            index += 1
        }
        .buttonStyle(PrimaryButtonStyle(color: color))
    }

    private func play() {
        guard index < cards.count, let item = Course.shared.item(cards[index].itemId) else { return }
        Speaker.shared.say(item.es)
    }
}
