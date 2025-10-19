import SwiftUI
import Combine

struct FastingTimerView: View {
    @AppStorage(Keys.isFasting) private var isFasting = false
    @AppStorage(Keys.fastingStart) private var fastingStart = 0.0

    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var elapsed: TimeInterval {
        guard isFasting, fastingStart > 0 else { return 0 }
        return max(now.timeIntervalSince1970 - fastingStart, 0)
    }

    var body: some View {
        VStack(spacing: 24) {
            if isFasting {
                Text(format(elapsed))
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .onReceive(timer) { date in
                        now = date
                    }

                Button(role: .destructive, action: endFast) {
                    Text("End Fast")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Text("Not fasting right now.")
                    .foregroundColor(.secondary)

                Button(action: startFast) {
                    Text("Start Fast")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }

    private func startFast() {
        fastingStart = Date().timeIntervalSince1970
        isFasting = true
    }

    private func endFast() {
        isFasting = false
    }

    private func format(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(interval)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

#Preview {
    FastingTimerView()
}
