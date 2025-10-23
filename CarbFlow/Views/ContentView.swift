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
    @StateObject private var carbStore = CarbIntakeStore()

    private static let fastingUnlockDay = 18
    private var carbTrackerUnlocked: Bool { currentDay > 2 }
    
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
            learnTab
                .tabItem {
                    Label("Learn", systemImage: learnUnlocked ? "book" : "lock.fill")
                }
                .tag(Tab.learn)

            carbTrackerTab
                .tabItem {
                    Label("Carbs", systemImage: carbTrackerUnlocked ? "leaf" : "lock.fill")
                }
                .tag(Tab.carbs)

            homeTab
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(Tab.home)

            timerTab
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
                .environmentObject(carbStore)
        }
    }

    private enum Tab {
        case learn
        case carbs
        case home
        case timer
    }

    private var learnTab: some View {
        NavigationStack {
            if learnUnlocked {
                LearnView(goToToday: { selectedTab = .home })
            } else {
                LockedPlaceholderView(title: "Learn", message: "Complete Day 1 to unlock")
            }
        }
        .environmentObject(contentStore)
        .environmentObject(quizStore)
        .environmentObject(historyStore)
        .environmentObject(listStore)
        .environmentObject(carbStore)
    }

    private var carbTrackerTab: some View {
        NavigationStack {
            if carbTrackerUnlocked {
                CarbTrackerView()
            } else {
                LockedPlaceholderView(title: "Carbs", message: "Complete Day 2 (Carb Targets) to unlock")
            }
        }
        .environmentObject(contentStore)
        .environmentObject(quizStore)
        .environmentObject(historyStore)
        .environmentObject(listStore)
        .environmentObject(carbStore)
    }

    private var homeTab: some View {
        NavigationStack {
            HomeView()
        }
        .environmentObject(contentStore)
        .environmentObject(quizStore)
        .environmentObject(historyStore)
        .environmentObject(listStore)
        .environmentObject(carbStore)
    }

    private var timerTab: some View {
        NavigationStack {
            if timerUnlocked {
                FastingTimerView()
            } else {
                LockedPlaceholderView(title: "Timer", message: "Complete Day 18 (Meal Timing) to unlock")
            }
        }
        .environmentObject(contentStore)
        .environmentObject(quizStore)
        .environmentObject(historyStore)
        .environmentObject(listStore)
        .environmentObject(carbStore)
    }
}

#Preview {
    ContentView()
}
