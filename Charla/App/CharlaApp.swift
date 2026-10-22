import SwiftUI

@main
struct CharlaApp: App {
    @StateObject private var progress = ProgressStore.shared
    @AppStorage("onboarded") private var onboarded = false
    @Environment(\.scenePhase) private var scenePhase

    init() {
        Audio.configure()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if onboarded {
                    RootView()
                } else {
                    OnboardingView()
                }
            }
            .environmentObject(progress)
            .tint(Theme.coral)
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { progress.refreshStreak() }
            }
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var progress: ProgressStore

    var body: some View {
        TabView {
            NavigationStack { LearnView() }
                .tabItem { Label("Learn", systemImage: "book.fill") }
            NavigationStack { PracticeView() }
                .tabItem { Label("Practice", systemImage: "bubble.left.and.bubble.right.fill") }
                .badge(progress.dueCards.count)
            NavigationStack { ProfileView() }
                .tabItem { Label("Profile", systemImage: "person.fill") }
        }
    }
}
