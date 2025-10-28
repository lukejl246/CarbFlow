import SwiftUI

struct VerifiedBadge: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.seal.fill")
                .font(.caption.weight(.bold))
            Text("Verified")
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .foregroundStyle(Color.accentColor)
        .background(
            Capsule(style: .continuous)
                .fill(Color.accentColor.opacity(0.12))
        )
        .accessibilityElement()
        .accessibilityLabel("Verified nutrition entry")
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    VerifiedBadge()
        .padding()
}
