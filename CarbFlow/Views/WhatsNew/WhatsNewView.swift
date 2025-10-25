import SwiftUI

struct WhatsNewView: View {
    @ObservedObject var store: WhatsNewStore
    @Environment(\.dismiss) private var dismiss
    @State private var hasAppeared = false

    var body: some View {
        ZStack {
            Color(.systemGray6)
                .ignoresSafeArea()

            content
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 20)
                .animation(.easeInOut(duration: 0.25), value: hasAppeared)
        }
        .onAppear {
            guard !hasAppeared else { return }
            hasAppeared = true
        }
    }

    private var content: some View {
        VStack(spacing: 24) {
            Text(store.payload.headline)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            ScrollView {
                VStack(spacing: 20) {
                    ForEach(store.payload.items) { item in
                        WhatsNewCard(item: item)
                    }
                }
                .frame(maxWidth: .infinity)
            }

            VStack(spacing: 12) {
                Button(action: handlePrimaryAction) {
                    Text("Got it")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                .foregroundColor(.white)
                .background(Color.accentColor)
                .cornerRadius(12)
                .frame(minHeight: 52)

                Button(action: handleReleaseNotesTap) {
                    Text("Full release notes")
                        .font(.subheadline)
                        .underline()
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
            }
        }
    }

    private func handlePrimaryAction() {
        store.markSeen()
        dismiss()
    }

    private func handleReleaseNotesTap() {
        cf_logEvent("whatsnew_release_notes_tap", ["version": store.payload.versionKey])
    }
}

private struct WhatsNewCard: View {
    let item: WhatsNewItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let systemImage = item.systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.accentColor)
                    .frame(width: 32, height: 32)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            Text(item.title)
                .font(.headline)
                .foregroundColor(.primary)

            Text(item.subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
    }
}

struct WhatsNewView_Previews: PreviewProvider {
    static var previews: some View {
        let defaults = UserDefaults(suiteName: "WhatsNewPreview")!
        defaults.removePersistentDomain(forName: "WhatsNewPreview")
        let store = WhatsNewStore(userDefaults: defaults)
        return WhatsNewView(store: store)
    }
}
