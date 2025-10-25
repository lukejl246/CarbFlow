import SwiftUI

struct TrackBreadcrumbsModifier: ViewModifier {
    let name: String

    func body(content: Content) -> some View {
        content
            .onAppear {
                cf_breadcrumbScreen(name)
            }
    }
}

extension View {
    func breadcrumbScreen(_ name: String) -> some View {
        modifier(TrackBreadcrumbsModifier(name: name))
    }
}
