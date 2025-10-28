#if canImport(UIKit)
import XCTest
import SwiftUI
@testable import CarbFlow

final class SnapshotTestCase: XCTestCase {
    func render<V: View>(_ view: V, size: CGSize = CGSize(width: 390, height: 844)) -> UIImage {
        let controller = UIHostingController(rootView: view)
        controller.view.bounds = CGRect(origin: .zero, size: size)
        controller.view.backgroundColor = .clear

        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = controller
        window.makeKeyAndVisible()

        controller.view.layoutIfNeeded()

        let renderer = UIGraphicsImageRenderer(size: size, format: UIGraphicsImageRendererFormat.default())
        return renderer.image { context in
            controller.view.layer.render(in: context.cgContext)
        }
    }

    func assertSnapshot(_ image: UIImage, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertGreaterThan(image.size.width, 0, "Snapshot width should be > 0", file: file, line: line)
        XCTAssertGreaterThan(image.size.height, 0, "Snapshot height should be > 0", file: file, line: line)
        let attachment = XCTAttachment(image: image)
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
#endif
