import SwiftUI

/// The course path: one card per unit, the next one highlighted.
struct LearnView: View {
    @EnvironmentObject private var progress: ProgressStore
    private let course = Course.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                ForEach(Array(course.units.enumerated()), id: \.element.id) { i, unit in
                    let unlocked = progress.isUnlocked(unit)
                    NavigationLink(value: unit) {
                        UnitCard(unit: unit, number: i + 1, done: progress.isCompleted(unit), unlocked: unlocked,
                                 current: progress.currentUnit == unit && !progress.isCompleted(unit),
                                 talked: progress.isConversationDone(unit.conversation))
                    }
                    .buttonStyle(.plain)
                    .disabled(!unlocked)
                }
                Text("More units are on the way.").font(.footnote).foregroundStyle(.secondary).padding(.top, 8)
            }
            .padding()
        }
        .navigationTitle("Charla")
        .navigationDestination(for: Unit.self) { UnitView(unit: $0) }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack {
                    GoalRing(value: progress.xpToday, goal: progress.dailyGoal, size: 30)
                    StreakBadge(days: progress.data.streak)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("¡Hola, \(progress.displayName)!").font(.title.weight(.bold))
            Text(progress.goalReached ? "Daily goal done. ¡Muy bien!" : "\(max(0, progress.dailyGoal - progress.xpToday)) XP to today's goal")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct UnitCard: View {
    let unit: Unit
    let number: Int
    let done: Bool
    let unlocked: Bool
    let current: Bool
    let talked: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(done ? Theme.good : (unlocked ? Theme.coral : Color.gray.opacity(0.3)))
                Image(systemName: unlocked ? (done ? "checkmark" : unit.icon) : "lock.fill")
                    .font(.title3.weight(.semibold)).foregroundStyle(.white)
            }
            .frame(width: 54, height: 54)
            VStack(alignment: .leading, spacing: 3) {
                Text("Unit \(number) · \(unit.titleEs)").font(.caption.weight(.semibold)).foregroundStyle(Theme.coral)
                Text(unit.title).font(.headline)
                Text(unit.goal).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                if done {
                    Label(talked ? "Conversation done" : "Conversation unlocked", systemImage: talked ? "checkmark.bubble.fill" : "bubble.left.and.bubble.right.fill")
                        .font(.caption2.weight(.semibold)).foregroundStyle(talked ? Theme.good : Theme.teal)
                }
            }
            Spacer(minLength: 0)
            if unlocked { Image(systemName: "chevron.right").foregroundStyle(.tertiary) }
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(current ? Theme.coral : .clear, lineWidth: 2))
        .opacity(unlocked ? 1 : 0.55)
    }
}

/// One unit: start the lesson, read the tip, see the words, open the conversation.
struct UnitView: View {
    let unit: Unit
    @EnvironmentObject private var progress: ProgressStore
    @State private var lesson = false
    @State private var conversation = false
    @State private var showTip = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: unit.icon).font(.largeTitle).foregroundStyle(Theme.coral)
                    Text(unit.titleEs).font(.title.weight(.bold))
                    Text(unit.goal).foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
                Button { lesson = true } label: {
                    Label(progress.isCompleted(unit) ? "Practise the lesson again" : "Start lesson", systemImage: "play.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                Button { conversation = true } label: {
                    Label("Conversation: \(unit.conversation.title)", systemImage: "bubble.left.and.bubble.right.fill")
                }
                .buttonStyle(PrimaryButtonStyle(color: Theme.teal))
                .disabled(!progress.isCompleted(unit))
                .opacity(progress.isCompleted(unit) ? 1 : 0.45)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                if !progress.isCompleted(unit) {
                    Text("Finish the lesson to unlock the conversation.").font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("Grammar tip") {
                DisclosureGroup(isExpanded: $showTip) {
                    GrammarCard(grammar: unit.grammar)
                } label: {
                    Label(unit.grammar.title, systemImage: "lightbulb.fill").foregroundStyle(Theme.sun)
                }
            }

            Section("Words & phrases (\(unit.items.count))") {
                ForEach(unit.items) { item in
                    HStack(spacing: 12) {
                        SpeakButton(text: item.es, size: 15)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.es).font(.body.weight(.semibold))
                            Text(item.en).font(.subheadline).foregroundStyle(.secondary)
                            if let note = item.note { Text(note).font(.caption).foregroundStyle(.tertiary) }
                        }
                    }
                }
            }
        }
        .navigationTitle(unit.title)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $lesson) { LessonView(unit: unit) }
        .fullScreenCover(isPresented: $conversation) { ChatView(scenario: unit.conversation) }
    }
}

struct GrammarCard: View {
    let grammar: Grammar

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(grammar.body).font(.subheadline)
            ForEach(grammar.examples, id: \.es) { ex in
                HStack(alignment: .top, spacing: 10) {
                    SpeakButton(text: ex.es, size: 13)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(ex.es).font(.subheadline.weight(.semibold))
                        Text(ex.en).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }
}
