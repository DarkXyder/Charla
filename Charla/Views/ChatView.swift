import SwiftUI

/// A role-play conversation. With Apple Intelligence it's free chat; otherwise guided by the script.
struct ChatView: View {
    @StateObject private var model: ConversationModel
    @StateObject private var listener = Listener()
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    @State private var revealed: Set<UUID> = []
    @FocusState private var typing: Bool

    init(scenario: Scenario, forceGuided: Bool = false) {
        _model = StateObject(wrappedValue: ConversationModel(scenario: scenario, name: ProgressStore.shared.displayName,
                                                             forceGuided: forceGuided))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                goalBanner
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(model.messages) { m in bubble(m).id(m.id) }
                            if model.busy {
                                HStack { TypingDots(); Spacer() }.id("typing")
                            }
                            if model.finished { finishedCard.id("done") }
                        }
                        .padding()
                    }
                    .onChange(of: model.messages.count) { _, _ in
                        withAnimation { proxy.scrollTo(model.messages.last?.id, anchor: .bottom) }
                    }
                    .onChange(of: model.finished) { _, _ in withAnimation { proxy.scrollTo("done", anchor: .bottom) } }
                }
                if !model.finished { inputArea }
            }
            .navigationTitle(model.scenario.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Close") { Speaker.shared.stop(); dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Label(model.mode == .ai ? "AI" : "Guided", systemImage: model.mode == .ai ? "sparkles" : "list.bullet")
                        .font(.caption.weight(.semibold)).labelStyle(.titleAndIcon)
                        .foregroundStyle(model.mode == .ai ? Theme.teal : .secondary)
                }
            }
        }
        .task { await model.start() }
        .onChange(of: listener.transcript) { _, t in if !t.isEmpty { draft = t } }
        .onChange(of: listener.listening) { _, now in
            // Send automatically when the learner stops talking.
            if !now, !draft.isEmpty { submit() }
        }
    }

    private var goalBanner: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "target").foregroundStyle(Theme.coral)
            Text(model.scenario.goal).font(.footnote)
            Spacer(minLength: 0)
        }
        .padding(.horizontal).padding(.vertical, 10)
        .background(Theme.card)
    }

    @ViewBuilder
    private func bubble(_ m: ChatMessage) -> some View {
        switch m.role {
        case .partner:
            HStack(alignment: .bottom, spacing: 8) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(m.es).font(.body)
                    if revealed.contains(m.id), let en = m.en {
                        Text(en).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .onTapGesture { toggle(m.id) }
                SpeakButton(text: m.es, size: 13)
                Spacer(minLength: 30)
            }
        case .learner:
            VStack(alignment: .trailing, spacing: 6) {
                HStack {
                    Spacer(minLength: 50)
                    Text(m.es)
                        .padding(12)
                        .background(Theme.coral, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .foregroundStyle(.white)
                }
                if let c = m.correction {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Better:", systemImage: "pencil").font(.caption.weight(.semibold)).foregroundStyle(Theme.sun)
                        HStack { Text(c).font(.subheadline.weight(.semibold)); Spacer(); SpeakButton(text: c, size: 12) }
                        if let tip = m.tip { Text(tip).font(.caption).foregroundStyle(.secondary) }
                    }
                    .padding(10)
                    .frame(maxWidth: 300, alignment: .leading)
                    .background(Theme.sun.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                } else if m.good == true {
                    Label(m.en ?? "Good!", systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(Theme.good)
                }
            }
        case .note:
            Text(m.es).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    private var inputArea: some View {
        VStack(spacing: 10) {
            // Guided: the script's answers. AI: three ideas from the partner.
            let chips = model.mode == .guided ? model.options.map(\.es) : model.suggestions
            if !chips.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(chips, id: \.self) { s in
                            Button {
                                if model.mode == .guided { Task { await model.send(s) } } else { draft = s }
                            } label: {
                                Text(s).font(.subheadline)
                                    .padding(.horizontal, 12).padding(.vertical, 8)
                                    .background(Theme.teal.opacity(0.12), in: Capsule())
                                    .overlay(Capsule().stroke(Theme.teal.opacity(0.4)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            HStack(spacing: 10) {
                MicButton(listener: listener, size: 44)
                TextField(listener.listening ? "Listening…" : "Write or say it in Spanish", text: $draft, axis: .vertical)
                    .lineLimit(1...3)
                    .textInputAutocapitalization(.sentences)
                    .padding(10)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
                    .focused($typing)
                    .onSubmit(submit)
                Button(action: submit) {
                    Image(systemName: "arrow.up.circle.fill").font(.system(size: 34)).foregroundStyle(Theme.coral)
                }
                .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty || model.busy)
            }
            .padding(.horizontal)
            if typing { AccentBar(text: $draft).padding(.horizontal) }
        }
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var finishedCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 44)).foregroundStyle(Theme.good)
            Text("¡Muy bien!").font(.title2.weight(.bold))
            Text("Conversation complete · +\(20 + model.goodTurns * 5) XP").foregroundStyle(.secondary)
            Button("Done") { dismiss() }.buttonStyle(PrimaryButtonStyle())
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20))
    }

    private func submit() {
        let text = draft
        draft = ""
        Task { await model.send(text) }
    }

    private func toggle(_ id: UUID) {
        if revealed.contains(id) { revealed.remove(id) } else { revealed.insert(id) }
    }
}

struct TypingDots: View {
    @State private var phase = 0.0

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3) { i in
                Circle().frame(width: 7, height: 7)
                    .opacity(0.3 + 0.7 * abs(sin(phase + Double(i) * 0.7)))
            }
        }
        .foregroundStyle(.secondary)
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
        .onAppear { withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) { phase = .pi } }
    }
}
