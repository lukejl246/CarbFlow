import SwiftUI

struct LearnView: View {
    @AppStorage(Keys.currentDay) private var currentDay = 1
    @AppStorage(Keys.hasSetCarbTarget) private var hasSetCarbTarget = false
    @EnvironmentObject private var contentStore: ContentStore
    @EnvironmentObject private var quizStore: QuizStore

    @State private var lockedAlert = false
    @State private var lockedRowID: Int?
    @State private var lockedReason: String?

    var goToToday: () -> Void = {}

    private var totalDays: Int {
        contentStore.totalDays
    }

    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [Color(.systemGray6), Color(.systemGray5)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var unlockContext: UnlockContext {
        UnlockContext(
            currentDay: currentDay,
            hasSetCarbTarget: hasSetCarbTarget,
            quizCorrectDays: quizStore.correctDaysSet()
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 18) {
                    ForEach(contentStore.days) { module in
                        let result = UnlockRules.canOpen(day: module.day, content: contentStore, ctx: unlockContext)
                        learnRow(for: module, canOpen: result.allowed, reason: result.reason)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(backgroundGradient.ignoresSafeArea())
            .navigationTitle("Learn")
            .alert(
                "Locked",
                isPresented: $lockedAlert,
                actions: {
                    Button("Go to Today") { goToToday() }
                    Button("Cancel", role: .cancel) { }
                },
                message: {
                    Text(lockedReason ?? "Complete earlier lessons first.")
                }
            )
            .onChange(of: lockedAlert) { newValue in
                if !newValue {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        lockedRowID = nil
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func learnRow(for module: ContentDay, canOpen: Bool, reason: String?) -> some View {
        let accent = accentColor(for: module.day)

        if canOpen {
            NavigationLink {
                DayDetailView(day: module.day)
            } label: {
                LearnRow(
                    module: module,
                    isLocked: false,
                    totalDays: totalDays,
                    accentColor: accent,
                    lockReason: nil
                )
            }
            .buttonStyle(.plain)
        } else {
            LearnRow(
                module: module,
                isLocked: true,
                totalDays: totalDays,
                accentColor: accent,
                lockReason: reason
            )
            .scaleEffect(lockedRowID == module.day ? 0.95 : 1.0)
            .onTapGesture {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.55)) {
                    lockedRowID = module.day
                }
                lockedReason = reason ?? "Complete earlier lessons first."
                lockedAlert = true
            }
        }
    }

    private func accentColor(for day: Int) -> Color {
        let palette: [Color] = [
            Color(red: 0.42, green: 0.61, blue: 0.99),
            Color(red: 0.42, green: 0.78, blue: 0.64),
            Color(red: 0.95, green: 0.65, blue: 0.28),
            Color(red: 0.67, green: 0.58, blue: 0.95),
            Color(red: 0.97, green: 0.47, blue: 0.45)
        ]
        let index = max((day - 1) % palette.count, 0)
        return palette[index]
    }
}

private struct LearnRow: View {
    let module: ContentDay
    let isLocked: Bool
    let totalDays: Int
    let accentColor: Color
    let lockReason: String?

    var body: some View {
        LearnCard(accentColor: accentColor) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(accentColor.opacity(0.12))
                                .frame(width: 36, height: 36)
                            Image(systemName: "text.book.closed.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(accentColor)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Day \(module.day)")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                            Text(module.title)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                    }

                    Spacer()

                    statusCapsule
                }

                Text(module.summary)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if isLocked {
                    Text(lockReason ?? "Complete earlier lessons first.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                } else {
                    ProgressView(value: Double(module.day) / Double(totalDays))
                        .tint(accentColor)
                        .padding(.top, 2)
                    Text("Lesson \(module.day) of \(totalDays)")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var statusCapsule: some View {
        let labelText = isLocked ? "Locked" : "Open"
        let symbol = isLocked ? "lock.fill" : "arrow.right.circle.fill"
        let foreground = isLocked ? Color.secondary : accentColor
        let background = isLocked ? Color.gray.opacity(0.18) : accentColor.opacity(0.18)

        return Label(labelText, systemImage: symbol)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(background)
            )
            .foregroundColor(foreground)
    }
}

private struct LearnCard<Content: View>: View {
    private let accentColor: Color
    private let content: Content

    init(accentColor: Color, @ViewBuilder content: () -> Content) {
        self.accentColor = accentColor
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            content
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.white.opacity(0.96))
                .shadow(color: Color.black.opacity(0.04), radius: 12, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(accentColor.opacity(0.14), lineWidth: 1)
        )
    }
}

#Preview {
    let store = ContentStore()
    let quizStore = QuizStore(contentStore: store)
    let listStore = ContentListStore()
    return LearnView()
        .environmentObject(store)
        .environmentObject(quizStore)
        .environmentObject(listStore)
}
