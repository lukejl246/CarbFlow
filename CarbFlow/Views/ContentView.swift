import SwiftUI

struct ContentView: View {
    @AppStorage(Keys.currentDay) private var currentDay = 1
    @AppStorage(Keys.hasOnboarded) private var hasOnboarded = false
    @State private var selectedTab: Tab = .home
    @State private var showOnboarding = false

    private var isUnlocked: Bool {
        currentDay > 1
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Group {
                if isUnlocked {
                    NavigationStack {
                        LearnView()
                    }
                } else {
                    LockedPlaceholderView(title: "Learn", message: "Complete Day 1 to unlock")
                }
            }
            .tabItem {
                Label("Learn", systemImage: isUnlocked ? "book" : "lock.fill")
            }
            .tag(Tab.learn)

            NavigationStack {
                HomeView()
            }
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
                if isUnlocked {
                    NavigationStack {
                        FastingTimerView()
                    }
                } else {
                    LockedPlaceholderView(title: "Timer", message: "Complete Day 1 to unlock")
                }
            }
            .tabItem {
                Label("Timer", systemImage: isUnlocked ? "timer" : "lock.fill")
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
