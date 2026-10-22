import SwiftUI

/// Runs a lesson (or a practice set): one exercise at a time, "Check", feedback, next.
struct LessonView: View {
    let title: String
    let unit: Unit?
    @State private var steps: [Exercise]
    @EnvironmentObject private var progress: ProgressStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var listener = Listener()

    @State private var index = 0
    @State private var answer = Answer()
    @State private var feedback: Feedback?
    @State private var correct = 0
    @State private var graded = 0
    @State private var done = false
    @State private var confirmQuit = false

    init(unit: Unit) {
        self.unit = unit
        self.title = unit.titleEs
        _steps = State(initialValue: LessonBuilder.build(unit, speaking: UserDefaults.standard.object(forKey: "speakingExercises") as? Bool ?? true))
    }

    init(practice items: [Item]) {
        self.unit = nil
        self.title = "Practice"
        _steps = State(initialValue: LessonBuilder.practice(items, speaking: UserDefaults.standard.object(forKey: "speakingExercises") as? Bool ?? true))
    }

    /// What the learner has entered for the current exercise.
    struct Answer {
        var choice: String?
        var text = ""
        var tiles: [Int] = []          // indices into the tile list, in order
        var matched: Set<String> = []  // item ids paired correctly
    }

    struct Feedback {
        let right: Bool
        let title: String
        let solution: String?
        let solutionEn: String?
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            if done {
                summary
            } else {
                ScrollView {
                    ExerciseView(exercise: steps[index], answer: $answer, feedback: feedback, listener: listener,
                                 onMatchComplete: { checkAnswer() })
                        .padding()
                        .id(steps[index].id)
                }
                .scrollDismissesKeyboard(.interactively)
                bottomBar
            }
        }
        .background(Color(.systemBackground))
        .confirmationDialog("Leave the lesson?", isPresented: $confirmQuit, titleVisibility: .visible) {
            Button("Leave", role: .destructive) { dismiss() }
        } message: { Text("Your progress in this lesson won't be saved.") }
        .onChange(of: index) { _, _ in autoplay() }
        .onAppear { autoplay() }
    }

    // MARK: - bars

    private var topBar: some View {
        HStack(spacing: 14) {
            Button { if done { dismiss() } else { confirmQuit = true } } label: {
                Image(systemName: "xmark").font(.headline).foregroundStyle(.secondary)
            }
            ProgressView(value: Double(done ? steps.count : index), total: Double(max(steps.count, 1)))
                .tint(Theme.coral)
                .scaleEffect(x: 1, y: 2.2)
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
        }
        .padding()
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            if let f = feedback {
                VStack(alignment: .leading, spacing: 4) {
                    Label(f.title, systemImage: f.right ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.headline).foregroundStyle(f.right ? Theme.good : Theme.bad)
                    if let s = f.solution {
                        HStack {
                            Text(s).font(.body.weight(.semibold))
                            Spacer()
                            SpeakButton(text: s, size: 14)
                        }
                    }
                    if let e = f.solutionEn { Text(e).font(.subheadline).foregroundStyle(.secondary) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background((f.right ? Theme.good : Theme.bad).opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
            }
            Button(buttonTitle) { primaryAction() }
                .buttonStyle(PrimaryButtonStyle(color: feedback.map { $0.right ? Theme.good : Theme.bad } ?? Theme.coral))
                .disabled(!canCheck)
                .opacity(canCheck ? 1 : 0.5)
            if case .speak = steps[index].kind, feedback == nil {
                Button("I can't speak right now") { skipSpeaking() }.font(.footnote)
            }
        }
        .padding()
    }

    private var buttonTitle: String {
        if feedback != nil { return "Continue" }
        if case .learn = steps[index].kind { return "Got it" }
        return "Check"
    }

    private var canCheck: Bool {
        if feedback != nil { return true }
        switch steps[index].kind {
        case .learn: return true
        case .listen, .choose: return answer.choice != nil
        case .build: return !answer.tiles.isEmpty
        case .type: return !answer.text.trimmingCharacters(in: .whitespaces).isEmpty
        case .speak: return !listener.transcript.isEmpty && !listener.listening
        case .match: return false // checks itself when all pairs are found
        }
    }

    // MARK: - flow

    private func primaryAction() {
        if feedback != nil { next(); return }
        if case .learn = steps[index].kind { next(); return }
        checkAnswer()
    }

    private func checkAnswer() {
        let ex = steps[index]
        var right = false
        var title = "Correct!"
        var solution: String?
        var solutionEn: String?
        switch ex.kind {
        case .learn:
            return
        case .listen(let item, _):
            right = answer.choice == item.en
            solution = item.es; solutionEn = item.en
        case .choose(let item, _):
            right = answer.choice == item.es
            solution = item.es; solutionEn = item.en
        case .build(let item, let tiles):
            let built = answer.tiles.map { tiles[$0] }.joined(separator: " ")
            right = SpanishText.clean(built) == SpanishText.clean(item.es)
            solution = item.es; solutionEn = item.en
        case .type(let item):
            switch SpanishText.check(answer.text, expected: item.es) {
            case .correct: right = true
            case .accents: right = true; title = "Correct! Watch the accents:"
            case .close: right = true; title = "Almost! Small typo:"
            case .wrong: right = false
            }
            solution = item.es; solutionEn = item.en
        case .speak(let item):
            let score = SpanishText.spokenMatch(listener.transcript, expected: item.es)
            right = score >= 0.72
            title = right ? (score > 0.92 ? "¡Perfecto!" : "Good!") : "Not quite. We heard: \"\(listener.transcript)\""
            solution = item.es; solutionEn = item.en
        case .match:
            right = true
            title = "All matched!"
        }
        if !right {
            title = title == "Correct!" ? "Not quite. Correct answer:" : title
            // Missed exercises come back once at the end.
            if !ex.isRetry {
                var again = Exercise(kind: ex.kind)
                again.isRetry = true
                steps.append(again)
            }
        }
        if !ex.isRetry || right { graded += 1 }
        if right { correct += 1 }
        feedback = Feedback(right: right, title: title, solution: solution, solutionEn: solutionEn)
        if let solution, right { Speaker.shared.say(solution) }
    }

    private func skipSpeaking() {
        UserDefaults.standard.set(false, forKey: "speakingExercises")
        next()
    }

    private func next() {
        feedback = nil
        answer = Answer()
        if index + 1 < steps.count {
            index += 1
        } else {
            finish()
        }
    }

    private func finish() {
        done = true
        let xp = correct * 10
        if let unit { progress.completeLesson(unit, xp: xp) } else { progress.addXP(xp) }
    }

    private func autoplay() {
        guard !done, index < steps.count else { return }
        switch steps[index].kind {
        case .learn(let item), .listen(let item, _): Speaker.shared.say(item.es)
        default: break
        }
    }

    // MARK: - summary

    private var summary: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "party.popper.fill").font(.system(size: 64)).foregroundStyle(Theme.coral)
            Text(unit == nil ? "Practice done!" : "¡Lección completa!").font(.largeTitle.weight(.bold))
            HStack(spacing: 30) {
                stat("\(correct * 10)", "XP")
                stat(graded > 0 ? "\(Int(Double(correct) / Double(graded) * 100))%" : "-", "Accuracy")
                stat("\(progress.data.streak)", "Day streak")
            }
            if let unit {
                Text("Conversation unlocked: \(unit.conversation.title)")
                    .font(.subheadline).foregroundStyle(Theme.teal).multilineTextAlignment(.center)
            }
            Spacer()
            Button("Continue") { dismiss() }.buttonStyle(PrimaryButtonStyle())
        }
        .padding()
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack {
            Text(value).font(.title.weight(.bold)).foregroundStyle(Theme.coral)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }
}

/// The body of one exercise.
struct ExerciseView: View {
    let exercise: Exercise
    @Binding var answer: LessonView.Answer
    let feedback: LessonView.Feedback?
    @ObservedObject var listener: Listener
    let onMatchComplete: () -> Void
    @FocusState private var typing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            switch exercise.kind {
            case .learn(let item): learn(item)
            case .listen(let item, let options): listen(item, options)
            case .choose(let item, let options): choose(item, options)
            case .build(let item, let tiles): build(item, tiles)
            case .type(let item): type(item)
            case .speak(let item): speak(item)
            case .match(let items): MatchBoard(items: items, matched: $answer.matched, onComplete: onMatchComplete)
            }
        }
    }

    private func prompt(_ text: String) -> some View {
        Text(text).font(.title3.weight(.bold))
    }

    private func learn(_ item: Item) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("New phrase", systemImage: "sparkles").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.coral)
            HStack(alignment: .center) {
                Text(item.es).font(.largeTitle.weight(.bold))
                Spacer()
                SpeakButton(text: item.es, size: 26)
            }
            Text(item.en).font(.title3).foregroundStyle(.secondary)
            if let note = item.note {
                Label(note, systemImage: "info.circle").font(.subheadline).padding(12)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
            }
            Text("Long-press the speaker to hear it slowly.").font(.caption).foregroundStyle(.tertiary)
        }
    }

    private func listen(_ item: Item, _ options: [String]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            prompt("What do you hear?")
            HStack { Spacer(); SpeakButton(text: item.es, size: 34); Spacer() }
            choices(options, correct: item.en)
        }
    }

    private func choose(_ item: Item, _ options: [String]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            prompt("How do you say…")
            Text("“\(item.en)”").font(.title2)
            choices(options, correct: item.es)
        }
    }

    private func choices(_ options: [String], correct: String) -> some View {
        VStack(spacing: 10) {
            ForEach(options, id: \.self) { o in
                ChoiceButton(title: o, selected: answer.choice == o,
                             state: feedback == nil ? nil : (o == correct ? true : (answer.choice == o ? false : nil))) {
                    guard feedback == nil else { return }
                    answer.choice = o
                }
            }
        }
    }

    private func build(_ item: Item, _ tiles: [String]) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            prompt("Build the sentence")
            Text("“\(item.en)”").font(.title3)
            // Chosen tiles, in order: tap to remove.
            FlowLayout(spacing: 8) {
                ForEach(answer.tiles, id: \.self) { i in
                    tile(tiles[i]) { if feedback == nil { answer.tiles.removeAll { $0 == i } } }
                }
            }
            .frame(minHeight: 56, alignment: .topLeading)
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 14).stroke(Color.primary.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [5])))
            FlowLayout(spacing: 8) {
                ForEach(tiles.indices, id: \.self) { i in
                    tile(tiles[i]) { if feedback == nil, !answer.tiles.contains(i) { answer.tiles.append(i) } }
                        .opacity(answer.tiles.contains(i) ? 0.25 : 1)
                }
            }
        }
    }

    private func tile(_ word: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(word).font(.body.weight(.medium))
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }

    private func type(_ item: Item) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            prompt("Write it in Spanish")
            Text("“\(item.en)”").font(.title2)
            TextField("Type in Spanish", text: $answer.text, axis: .vertical)
                .font(.title3)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(14)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
                .focused($typing)
                .disabled(feedback != nil)
            AccentBar(text: $answer.text)
        }
        .onAppear { typing = true }
    }

    private func speak(_ item: Item) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            prompt("Say it aloud")
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.es).font(.title.weight(.bold))
                    Text(item.en).foregroundStyle(.secondary)
                }
                Spacer()
                SpeakButton(text: item.es, size: 24)
            }
            HStack { Spacer(); MicButton(listener: listener, size: 76); Spacer() }
                .disabled(feedback != nil)
            Text(listener.listening ? "Listening… tap to stop" : (listener.transcript.isEmpty ? "Tap the microphone and speak" : "“\(listener.transcript)”"))
                .font(.subheadline).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
            if listener.denied {
                Text("Microphone or speech recognition is off for Charla in Settings.").font(.caption).foregroundStyle(Theme.bad)
            }
        }
    }
}

/// Tap a Spanish card, then its English meaning.
struct MatchBoard: View {
    let items: [Item]
    @Binding var matched: Set<String>
    let onComplete: () -> Void
    @State private var left: [Item] = []
    @State private var right: [Item] = []
    @State private var pickedLeft: String?
    @State private var wrongFlash: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Match the pairs").font(.title3.weight(.bold))
            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 10) {
                    ForEach(left) { item in
                        card(item.es, id: item.id, selected: pickedLeft == item.id) {
                            pickedLeft = item.id
                            Speaker.shared.say(item.es)
                        }
                    }
                }
                VStack(spacing: 10) {
                    ForEach(right) { item in
                        card(item.en, id: item.id, selected: false) { pick(item) }
                    }
                }
            }
        }
        .onAppear {
            if left.isEmpty {
                left = items.shuffled()
                right = items.shuffled()
            }
        }
    }

    private func pick(_ item: Item) {
        guard let l = pickedLeft else { return }
        if l == item.id {
            matched.insert(item.id)
            pickedLeft = nil
            if matched.count == items.count { onComplete() }
        } else {
            wrongFlash = item.id
            Task { try? await Task.sleep(nanoseconds: 500_000_000); wrongFlash = nil }
        }
    }

    private func card(_ text: String, id: String, selected: Bool, action: @escaping () -> Void) -> some View {
        let isMatched = matched.contains(id)
        return Button(action: action) {
            Text(text).font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity, minHeight: 54)
                .padding(.horizontal, 8)
                .background(isMatched ? Theme.good.opacity(0.15) : (wrongFlash == id ? Theme.bad.opacity(0.2) : (selected ? Theme.coral.opacity(0.15) : Theme.card)),
                            in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? Theme.coral : Color.primary.opacity(0.1), lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(.plain)
        .disabled(isMatched)
        .opacity(isMatched ? 0.5 : 1)
    }
}

/// Wraps tiles onto new lines.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 { x = 0; y += row + spacing; row = 0 }
            x += size.width + spacing
            row = max(row, size.height)
        }
        return CGSize(width: width, height: y + row)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, row: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += row + spacing; row = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            row = max(row, size.height)
        }
    }
}
