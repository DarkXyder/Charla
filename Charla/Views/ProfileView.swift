import SwiftUI
import UserNotifications

/// Daily reminder notification.
enum Reminders {
    static func schedule(at time: Date) async -> Bool {
        let center = UNUserNotificationCenter.current()
        let ok = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        guard ok else { return false }
        center.removeAllPendingNotificationRequests()
        let content = UNMutableNotificationContent()
        content.title = "¡Hola! Time for Spanish"
        content.body = "Five minutes today keeps your streak alive."
        content.sound = .default
        let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: true)
        try? await center.add(UNNotificationRequest(identifier: "daily", content: content, trigger: trigger))
        return true
    }

    static func cancel() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}

struct ProfileView: View {
    @EnvironmentObject private var progress: ProgressStore
    @AppStorage("reminderOn") private var reminderOn = false
    @AppStorage("reminderTime") private var reminderTime = 19 * 3600.0 // seconds after midnight
    @AppStorage("speakingExercises") private var speaking = true
    @State private var rate = Double(Speaker.shared.rate)
    @State private var confirmReset = false

    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    stat("\(progress.data.streak)", "Day streak", "flame.fill", Theme.coral)
                    stat("\(progress.totalXP)", "Total XP", "star.fill", Theme.sun)
                    stat("\(progress.learnedCount)", "Words learned", "text.book.closed.fill", Theme.teal)
                }
                .padding(.vertical, 6)
                weekChart
            }

            Section("You") {
                TextField("Your name (used in conversations)", text: $progress.name)
                Picker("Daily goal", selection: $progress.dailyGoal) {
                    Text("Casual · 20 XP").tag(20)
                    Text("Regular · 50 XP").tag(50)
                    Text("Serious · 100 XP").tag(100)
                    Text("Intense · 150 XP").tag(150)
                }
            }

            Section {
                Toggle("Daily reminder", isOn: $reminderOn)
                if reminderOn {
                    DatePicker("Time", selection: Binding(
                        get: { Calendar.current.startOfDay(for: Date()).addingTimeInterval(reminderTime) },
                        set: { reminderTime = $0.timeIntervalSince(Calendar.current.startOfDay(for: $0)) }
                    ), displayedComponents: .hourAndMinute)
                }
            } header: {
                Text("Reminder")
            }
            .onChange(of: reminderOn) { _, _ in updateReminder() }
            .onChange(of: reminderTime) { _, _ in updateReminder() }

            Section {
                VStack(alignment: .leading) {
                    Text("Voice speed")
                    Slider(value: $rate, in: 0.3...0.55) { editing in
                        if !editing {
                            Speaker.shared.rate = Float(rate)
                            Speaker.shared.say("Hola, ¿cómo estás?")
                        }
                    }
                }
                Toggle("Speaking exercises", isOn: $speaking)
                LabeledContent("Voice", value: Speaker.shared.voiceName)
            } header: {
                Text("Audio")
            } footer: {
                Text(Speaker.shared.hasEnhancedVoice ? "Using an enhanced voice." :
                     "For a more natural voice, download an Enhanced Spanish (Mexico) voice in Settings → Accessibility → Spoken Content → Voices → Spanish.")
            }

            Section("Conversation partner") {
                if let status = TutorAvailability.status {
                    Label(status, systemImage: "list.bullet.rectangle").font(.subheadline)
                    Text("Until then, conversations are guided: you pick or say one of the suggested answers.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Label("On-device AI ready: free conversation, private and offline.", systemImage: "sparkles")
                        .font(.subheadline).foregroundStyle(Theme.teal)
                }
            }

            Section {
                Button("Reset all progress", role: .destructive) { confirmReset = true }
            } footer: {
                Text("Charla \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "") · Latin American Spanish")
            }
        }
        .navigationTitle("Profile")
        .confirmationDialog("Reset all progress?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset", role: .destructive) { progress.reset() }
        } message: { Text("Lessons, review cards, XP and your streak will be cleared.") }
    }

    private func stat(_ value: String, _ label: String, _ icon: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).foregroundStyle(color)
            Text(value).font(.title2.weight(.bold).monospacedDigit())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var weekChart: some View {
        let week = progress.lastWeek
        let top = max(progress.dailyGoal, week.map { $0.xp }.max() ?? 0)
        return HStack(alignment: .bottom, spacing: 10) {
            ForEach(week.indices, id: \.self) { i in
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(week[i].xp >= progress.dailyGoal ? Theme.sun : Theme.coral.opacity(0.6))
                        .frame(height: max(4, CGFloat(week[i].xp) / CGFloat(max(top, 1)) * 70))
                    Text(week[i].day).font(.caption2).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 96, alignment: .bottom)
    }

    private func updateReminder() {
        if reminderOn {
            let time = Calendar.current.startOfDay(for: Date()).addingTimeInterval(reminderTime)
            Task { if !(await Reminders.schedule(at: time)) { reminderOn = false } }
        } else {
            Reminders.cancel()
        }
    }
}

/// First launch: name, daily goal, and what to expect.
struct OnboardingView: View {
    static func goalLabel(_ xp: Int) -> String {
        switch xp {
        case 20: return "Casual · 5 min a day"
        case 50: return "Regular · 10 min a day"
        default: return "Serious · 20 min a day"
        }
    }

    @EnvironmentObject private var progress: ProgressStore
    @AppStorage("onboarded") private var onboarded = false
    @State private var page = 0

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            switch page {
            case 0:
                Image(systemName: "bubble.left.and.bubble.right.fill").font(.system(size: 72)).foregroundStyle(Theme.coral)
                Text("¡Bienvenido a Charla!").font(.largeTitle.weight(.bold)).multilineTextAlignment(.center)
                Text("Learn Latin American Spanish by speaking it. Short lessons, then real conversations with a partner that lives on your iPhone.")
                    .multilineTextAlignment(.center).foregroundStyle(.secondary)
            case 1:
                Text("What's your name?").font(.title.weight(.bold))
                TextField("Name", text: $progress.name)
                    .font(.title2).multilineTextAlignment(.center)
                    .padding().background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
                Text("Your conversation partners will use it.").font(.footnote).foregroundStyle(.secondary)
            default:
                Text("Daily goal").font(.title.weight(.bold))
                VStack(spacing: 10) {
                    ForEach([20, 50, 100], id: \.self) { xp in
                        ChoiceButton(title: Self.goalLabel(xp), selected: progress.dailyGoal == xp) { progress.dailyGoal = xp }
                    }
                }
            }
            Spacer()
            Button(page < 2 ? "Continue" : "¡Vamos!") {
                if page < 2 { withAnimation { page += 1 } } else { onboarded = true }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(28)
    }
}
