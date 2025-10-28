#if canImport(UIKit)
import XCTest
import SwiftUI
@testable import CarbFlow

final class PrivacyViewSnapshotTests: SnapshotTestCase {
    func testPrivacyViewSnapshot() {
        let view = NavigationStack { PrivacyView() }
        let image = render(view)
        assertSnapshot(image)
    }
}
#endif
