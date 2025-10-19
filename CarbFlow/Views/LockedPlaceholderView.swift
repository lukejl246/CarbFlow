import SwiftUI

struct LockedPlaceholderView: View {
    let title: String
    let message: String

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 48))
                Text(title)
                    .font(.title3)
                    .fontWeight(.bold)
                Text(message)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
}

#Preview {
    LockedPlaceholderView(title: "Learn", message: "Complete Day 1 to unlock")
}
