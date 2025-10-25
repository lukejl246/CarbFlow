import SwiftUI

struct TrackScreenModifier: ViewModifier {
    let name: String

    func body(content: Content) -> some View {
        content
            .onAppear {
                logScreenView(screenName: name)
            }
    }
}

extension View {
    func trackScreen(_ name: String) -> some View {
        modifier(TrackScreenModifier(name: name))
    }
}
