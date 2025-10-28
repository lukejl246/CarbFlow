import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct HelpCardView: View {
    @State private var hasAppeared = false
    @State private var showFallbackAlert = false
    @State private var fallbackAlertMessage = "Email address copied. Paste it into your preferred mail app."
    @State private var expandedFAQs: Set<String> = []

    private var versionSummary: String {
        let marketing = AppVersion.current.marketing
        let build = AppVersion.current.build
        return "App Version: \(marketing) (\(build))"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                helpCard
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
        .background(Color(.systemGray6).ignoresSafeArea())
        .trackScreen("Help")
        .breadcrumbScreen("Help")
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 24)
        .animation(.easeInOut(duration: 0.25), value: hasAppeared)
        .onAppear {
            guard !hasAppeared else { return }
            hasAppeared = true
        }
        .navigationTitle("Help")
        .alert("Email copied", isPresented: $showFallbackAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(fallbackAlertMessage)
        }
    }

    private var helpCard: some View {
        VStack(alignment: .leading, spacing: 24) {
            section(title: "Getting Started", message: "Open the Dashboard to see today at a glance.")

            section(title: "Logging Food", message: "Food logging is paused right now. Jot notes in Day detail to remember what you ate.")

            section(title: "Fasting", message: "Fasting timers are paused. Use day notes to record start and end times if you're experimenting.")

            privacySection

            faqSection

            helpSection

            Text("Not medical advice")
                .font(.footnote)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
        )
    }

    private func section(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Privacy & Data")
                .font(.headline)
            Text("Your entries stay on device unless you opt in to sync or share. Review the Privacy Policy for details.")
                .font(.body)
                .foregroundColor(.secondary)
            if let url = URL(string: Links.privacyURL) {
                Link("Privacy Policy", destination: url)
                    .font(.subheadline.weight(.semibold))
                    .onTapGesture {
                        cf_logEvent("help-privacy-tap", [:])
                    }
            }
        }
    }

    private var helpSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Need help?")
                .font(.headline)

            Button(action: composeSupportEmail) {
                Text("Email Support")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .frame(minHeight: 44)
            }
        }
    }

    private func composeSupportEmail() {
        cf_logEvent("help-email-tap", [:])
        Links.openSupportMail { copySupportEmailToClipboard() }
    }

    private var faqSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick answers")
                .font(.headline)
            VStack(spacing: 10) {
                faqDisclosure(id: "log_food", question: "How do I log food?") {
                    Text("Meal logging is currently unavailable. Use day notes or reflections to capture meals until tracking returns.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                faqDisclosure(id: "start_fast", question: "Can I track fasts?") {
                    Text("Fasting timers are not available in this build. Note your start and end times in Day reflections for now.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                faqDisclosure(id: "data_storage", question: "Where is my data stored?") {
                    Text("Entries stay on your device unless you connect sync or exports. Review Privacy Policy for details.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func faqDisclosure<Content: View>(id: String,
                                              question: String,
                                              @ViewBuilder answer: @escaping () -> Content) -> some View {
        DisclosureGroup(isExpanded: Binding(
            get: { expandedFAQs.contains(id) },
            set: { newValue in
                if newValue {
                    expandedFAQs.insert(id)
                } else {
                    expandedFAQs.remove(id)
                }
            }
        )) {
            answer()
                .padding(.top, 6)
        } label: {
            Text(question)
                .font(.body.weight(.semibold))
                .foregroundColor(.primary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemGray6))
        )
    }

    private func copySupportEmailToClipboard() {
#if canImport(UIKit)
        UIPasteboard.general.string = Links.supportEmail
#endif
        fallbackAlertMessage = "We copied \(Links.supportEmail) so you can email us from any app."
        showFallbackAlert = true
    }
}

#Preview {
    NavigationStack {
        HelpCardView()
    }
}
