#if canImport(UIKit)
import XCTest
import SwiftUI
@testable import CarbFlow

final class LogViewSnapshotTests: SnapshotTestCase {
    func testLogViewSnapshot() {
        let view = NavigationStack { LogView() }
        let image = render(view)
        assertSnapshot(image)
    }
}
#endif
