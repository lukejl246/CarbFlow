#if canImport(UIKit)
import XCTest
import SwiftUI
@testable import CarbFlow

final class ScannerPolicySnapshotTests: SnapshotTestCase {
    func testScannerPolicySnapshot() {
        let view = ScannerPolicyCard(onClose: {})
        let image = render(NavigationStack { view })
        assertSnapshot(image)
    }
}
#endif
