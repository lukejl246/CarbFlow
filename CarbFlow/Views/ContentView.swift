import SwiftUI

struct ContentView: View {
    @AppStorage(Keys.currentDay) private var currentDay = 1
    @AppStorage(Keys.hasOnboarded) private var hasOnboarded = false
    @State private var selectedTab: Tab = .home
    @State private var showOnboarding = false
    @StateObject private var historyStore = FastingHistoryStore()
    @StateObject private var contentStore: ContentStore
    @StateObject private var quizStore: QuizStore
    @StateObject private var listStore: ContentListStore

    private static let fastingUnlockDay = 18
    
    init() {
        let contentStore = ContentStore()
        _contentStore = StateObject(wrappedValue: contentStore)
        _quizStore = StateObject(wrappedValue: QuizStore(contentStore: contentStore))
        _listStore = StateObject(wrappedValue: ContentListStore())
    }


    private var learnUnlocked: Bool { currentDay > 1 }
    private var timerUnlocked: Bool { currentDay > ContentView.fastingUnlockDay }

    var body: some View {
        TabView(selection: $selectedTab) {
            Group {
                if learnUnlocked {
                    NavigationStack {
                        LearnView(goToToday: { selectedTab = .home })
                    }
                    .environmentObject(contentStore)
                    .environmentObject(quizStore)
                    .environmentObject(historyStore)
                    .environmentObject(listStore)
                } else {
                    LockedPlaceholderView(title: "Learn", message: "Complete Day 1 to unlock")
                }
            }
            .tabItem {
                Label("Learn", systemImage: learnUnlocked ? "book" : "lock.fill")
            }
            .tag(Tab.learn)

            NavigationStack {
                HomeView()
            }
            .environmentObject(contentStore)
            .environmentObject(quizStore)
            .environmentObject(historyStore)
            .environmentObject(listStore)
            .tabItem {
                VStack(spacing: 4) {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "house.fill")
                                .foregroundStyle(.white)
                                .font(.system(size: 20, weight: .semibold))
                        )
                    Text("Home")
                }
            }
            .tag(Tab.home)

            Group {
                if timerUnlocked {
                    NavigationStack {
                        FastingTimerView()
                    }
                    .environmentObject(contentStore)
                    .environmentObject(quizStore)
                    .environmentObject(historyStore)
                    .environmentObject(listStore)
                } else {
                    LockedPlaceholderView(title: "Timer", message: "Complete Day 18 (Meal Timing) to unlock")
                }
            }
            .tabItem {
                Label("Timer", systemImage: timerUnlocked ? "timer" : "lock.fill")
            }
            .tag(Tab.timer)
        }
        .onAppear {
            if !hasOnboarded {
                showOnboarding = true
            }
        }
        .onChange(of: hasOnboarded) { newValue in
            if !newValue {
                showOnboarding = true
            }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView()
                .environmentObject(contentStore)
                .environmentObject(quizStore)
                .environmentObject(listStore)
        }
    }

    private enum Tab {
        case learn
        case home
        case timer
    }
}

#Preview {
    ContentView()
}
