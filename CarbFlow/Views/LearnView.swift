import SwiftUI

struct LearnView: View {
    @AppStorage(Keys.currentDay) private var currentDay = 1
    @State private var lockedAlert = false
    @State private var lockedRowID: Int?

    private let totalDays = ProgramModel.modules.count

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 18) {
                    ForEach(ProgramModel.modules) { module in
                        learnRow(for: module)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color(.systemGray6).ignoresSafeArea())
            .navigationTitle("Learn")
            .alert("Unlock by completing previous days.", isPresented: $lockedAlert) {
                Button("OK", role: .cancel) { }
            }
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
    private func learnRow(for module: DayModule) -> some View {
        let locked = module.day > currentDay
        if locked {
            LearnRow(
                module: module,
                isLocked: true,
                totalDays: totalDays,
                accentColor: accentColor(for: module.day)
            )
            .scaleEffect(lockedRowID == module.day ? 0.95 : 1.0)
            .onTapGesture {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.55)) {
                    lockedRowID = module.day
                }
                lockedAlert = true
            }
        } else {
            NavigationLink {
                DayDetailView(day: module.day)
            } label: {
                LearnRow(
                    module: module,
                    isLocked: false,
                    totalDays: totalDays,
                    accentColor: accentColor(for: module.day)
                )
            }
            .buttonStyle(.plain)
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
    let module: DayModule
    let isLocked: Bool
    let totalDays: Int
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(accentColor.opacity(0.16))
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
                Text("Complete Day \(max(module.day - 1, 1)) to unlock this lesson.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                ProgressView(value: Double(module.day) / Double(totalDays))
                    .tint(accentColor)
                Text("Lesson \(module.day) of \(totalDays)")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.06), radius: 12, y: 6)
        )
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

#Preview {
    LearnView()
}
