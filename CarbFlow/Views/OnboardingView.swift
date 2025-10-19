import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Keys.carbTarget) private var carbTarget = 30
    @AppStorage(Keys.hasOnboarded) private var hasOnboarded = false

    var body: some View {
        VStack(spacing: 28) {
            VStack(spacing: 12) {
                Text("Welcome to CarbFlow")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Educational only, not medical advice.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 10) {
                Text("What CarbFlow is not")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                        Text("A substitute for professional medical guidance—always consult your doctor.")
                    }
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                        Text("A diagnosis or treatment plan. Use it to learn and track habits, not for emergencies.")
                    }
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                        Text("Personalised nutrition advice. Lessons will help you decide on carb goals when you are ready.")
                    }
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: continueOnboarding) {
                Text("Continue")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundColor(.white)
            }
        }
        .padding()
        .onAppear {
            if carbTarget == 0 {
                carbTarget = 30
            }
        }
    }

    private func continueOnboarding() {
        hasOnboarded = true
        dismiss()
    }
}

#Preview {
    OnboardingView()
}
