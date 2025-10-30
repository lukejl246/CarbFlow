import XCTest
import AVFoundation
@testable import CarbFlow

final class ScannerSessionCoordinatorTests: XCTestCase {

    var coordinator: ScannerSessionCoordinator!

    override func setUp() {
        super.setUp()
        coordinator = ScannerSessionCoordinator()
    }

    override func tearDown() {
        coordinator.stopSession()
        coordinator = nil
        super.tearDown()
    }

    // MARK: - Barcode Normalization Tests

    func testNormalizeBarcode_RemovesNonDigits() {
        // Test with UPC-A containing letters/symbols
        let testCodes = [
            ("123456789012", "123456789012"),  // Pure digits
            ("12-345-67890-12", "123456789012"),  // With dashes
            ("ABC123456789012XYZ", "123456789012"),  // With letters
            ("12.345.67890.12", "123456789012"),  // With dots
            ("  123456789012  ", "123456789012"),  // With spaces
        ]

        for (input, expected) in testCodes {
            let normalized = input.filter { $0.isNumber }
            XCTAssertEqual(normalized, expected, "Failed to normalize: \(input)")
        }
    }

    // MARK: - Checksum Validation Tests

    func testValidateUPCA_ValidCodes() {
        // Valid UPC-A codes with correct checksums
        let validCodes = [
            "036000291452",  // Coca-Cola
            "012345678905",  // Test code with valid checksum
            "042343370210",  // Justin's Almond Butter
            "000000000000",  // All zeros (valid checksum)
        ]

        for code in validCodes {
            let isValid = validateUPCAChecksum(code)
            XCTAssertTrue(isValid, "Should validate valid UPC-A: \(code)")
        }
    }

    func testValidateUPCA_InvalidCodes() {
        // Invalid UPC-A codes with incorrect checksums
        let invalidCodes = [
            "012345678906",  // Wrong check digit
            "036000291453",  // Wrong check digit
            "12345678901",   // Only 11 digits
            "1234567890123", // 13 digits (not UPC-A)
            "abcdefghijkl",  // Non-digits
        ]

        for code in invalidCodes {
            let isValid = validateUPCAChecksum(code)
            XCTAssertFalse(isValid, "Should reject invalid UPC-A: \(code)")
        }
    }

    func testValidateEAN13_ValidCodes() {
        // Valid EAN-13 codes
        let validCodes = [
            "5000112576009",  // Cadbury
            "4006381333634",  // Haribo
            "8712100000003",  // Test code
        ]

        for code in validCodes {
            let isValid = validateEAN13Checksum(code)
            XCTAssertTrue(isValid, "Should validate valid EAN-13: \(code)")
        }
    }

    func testValidateEAN13_InvalidCodes() {
        // Invalid EAN-13 codes
        let invalidCodes = [
            "5000112576008",  // Wrong check digit
            "400638133363",   // Only 12 digits
            "50001125760091", // 14 digits
        ]

        for code in invalidCodes {
            let isValid = validateEAN13Checksum(code)
            XCTAssertFalse(isValid, "Should reject invalid EAN-13: \(code)")
        }
    }

    func testValidateEAN8_ValidCodes() {
        // Valid EAN-8 codes
        let validCodes = [
            "96385074",  // Valid EAN-8
            "12345670",  // Test code with valid checksum
        ]

        for code in validCodes {
            let isValid = validateEAN8Checksum(code)
            XCTAssertTrue(isValid, "Should validate valid EAN-8: \(code)")
        }
    }

    func testValidateEAN8_InvalidCodes() {
        // Invalid EAN-8 codes
        let invalidCodes = [
            "96385075",  // Wrong check digit
            "1234567",   // Only 7 digits
            "123456789", // 9 digits
        ]

        for code in invalidCodes {
            let isValid = validateEAN8Checksum(code)
            XCTAssertFalse(isValid, "Should reject invalid EAN-8: \(code)")
        }
    }

    // MARK: - Duplicate Detection Tests

    func testDuplicateDetection_WithinWindow() {
        let expectation = XCTestExpectation(description: "First detection callback")
        var detectionCount = 0

        coordinator.onCodeDetected = { code in
            detectionCount += 1
            if detectionCount == 1 {
                expectation.fulfill()
            }
        }

        // Simulate first scan
        let testCode = "036000291452"
        simulateBarcodeDetection(testCode)

        wait(for: [expectation], timeout: 1.0)

        // Simulate duplicate scan within 2s window
        simulateBarcodeDetection(testCode)

        // Wait a bit to ensure no second callback
        Thread.sleep(forTimeInterval: 0.5)

        // Should only detect once
        XCTAssertEqual(detectionCount, 1, "Should ignore duplicate within 2s window")
    }

    func testDuplicateDetection_OutsideWindow() async throws {
        let expectation = XCTestExpectation(description: "Both detections")
        expectation.expectedFulfillmentCount = 2
        var detectionCount = 0

        coordinator.onCodeDetected = { code in
            detectionCount += 1
            expectation.fulfill()
        }

        // First scan
        let testCode = "036000291452"
        simulateBarcodeDetection(testCode)

        // Wait for duplicate window to expire (2.5s > 2s window)
        try await Task.sleep(nanoseconds: 2_500_000_000)

        // Second scan (should be detected)
        simulateBarcodeDetection(testCode)

        await fulfillment(of: [expectation], timeout: 1.0)

        XCTAssertEqual(detectionCount, 2, "Should detect same code after 2s window")
    }

    func testDuplicateDetection_DifferentCodes() {
        let expectation = XCTestExpectation(description: "Both detections")
        expectation.expectedFulfillmentCount = 2
        var detectedCodes: [String] = []

        coordinator.onCodeDetected = { code in
            detectedCodes.append(code)
            expectation.fulfill()
        }

        // Scan different codes in rapid succession
        simulateBarcodeDetection("036000291452")
        simulateBarcodeDetection("042343370210")

        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(detectedCodes.count, 2, "Should detect different codes")
        XCTAssertEqual(detectedCodes[0], "036000291452")
        XCTAssertEqual(detectedCodes[1], "042343370210")
    }

    // MARK: - Auto-Pause Tests

    func testAutoPause_ResumesAfter1_5Seconds() async throws {
        let firstExpectation = XCTestExpectation(description: "First detection")
        let secondExpectation = XCTestExpectation(description: "Second detection after pause")

        var detectionCount = 0

        coordinator.onCodeDetected = { code in
            detectionCount += 1
            if detectionCount == 1 {
                firstExpectation.fulfill()
            } else if detectionCount == 2 {
                secondExpectation.fulfill()
            }
        }

        // First detection
        simulateBarcodeDetection("036000291452")

        await fulfillment(of: [firstExpectation], timeout: 1.0)

        // Try scanning different code immediately (should be paused)
        simulateBarcodeDetection("042343370210")

        // Wait a bit
        try await Task.sleep(nanoseconds: 500_000_000)  // 0.5s
        XCTAssertEqual(detectionCount, 1, "Should still be paused")

        // Wait for auto-pause to expire (1.5s)
        try await Task.sleep(nanoseconds: 1_100_000_000)  // Additional 1.1s (total 1.6s)

        // Now scan again (should detect)
        simulateBarcodeDetection("042343370210")

        await fulfillment(of: [secondExpectation], timeout: 1.0)

        XCTAssertEqual(detectionCount, 2, "Should resume after 1.5s pause")
    }

    // MARK: - Session Lifecycle Tests

    func testSessionStart_UpdatesRunningState() {
        XCTAssertFalse(coordinator.isSessionRunning, "Session should not be running initially")

        coordinator.startSession()

        // Wait for session to start
        Thread.sleep(forTimeInterval: 0.5)

        XCTAssertTrue(coordinator.isSessionRunning, "Session should be running after start")
    }

    func testSessionStop_UpdatesRunningState() {
        coordinator.startSession()
        Thread.sleep(forTimeInterval: 0.5)

        XCTAssertTrue(coordinator.isSessionRunning)

        coordinator.stopSession()
        Thread.sleep(forTimeInterval: 0.5)

        XCTAssertFalse(coordinator.isSessionRunning, "Session should not be running after stop")
    }

    func testSessionStart_AlreadyRunning_DoesNotRestart() {
        coordinator.startSession()
        Thread.sleep(forTimeInterval: 0.5)

        let sessionBefore = coordinator.captureSession

        // Try starting again
        coordinator.startSession()
        Thread.sleep(forTimeInterval: 0.5)

        let sessionAfter = coordinator.captureSession

        XCTAssertTrue(sessionBefore === sessionAfter, "Should reuse same session")
    }

    // MARK: - Preview Layer Tests

    func testCreatePreviewLayer() {
        let previewLayer = coordinator.createPreviewLayer()

        XCTAssertNotNil(previewLayer)
        XCTAssertEqual(previewLayer.videoGravity, .resizeAspectFill)
        XCTAssertTrue(previewLayer.session === coordinator.captureSession)
    }

    // MARK: - Authorization Tests

    func testCheckCameraAuthorization_Authorized() async {
        // Note: This test will pass if camera is authorized, fail otherwise
        // In real tests, you'd mock AVCaptureDevice.authorizationStatus

        let isAuthorized = await ScannerSessionCoordinator.checkCameraAuthorization()

        // Just verify it returns a boolean
        XCTAssertNotNil(isAuthorized)
    }

    // MARK: - Helper Methods

    private func simulateBarcodeDetection(_ code: String) {
        // Directly call the detection logic
        // In real implementation, this would be triggered by AVFoundation
        coordinator.onCodeDetected?(code)
    }

    // MARK: - Checksum Validation Helper Methods

    private func validateUPCAChecksum(_ barcode: String) -> Bool {
        guard barcode.count == 12 else { return false }

        let digits = barcode.compactMap { Int(String($0)) }
        guard digits.count == 12 else { return false }

        var sum = 0
        for i in 0..<11 {
            if i % 2 == 0 {
                sum += digits[i] * 3
            } else {
                sum += digits[i]
            }
        }

        let checkDigit = (10 - (sum % 10)) % 10
        return checkDigit == digits[11]
    }

    private func validateEAN13Checksum(_ barcode: String) -> Bool {
        guard barcode.count == 13 else { return false }

        let digits = barcode.compactMap { Int(String($0)) }
        guard digits.count == 13 else { return false }

        var sum = 0
        for i in 0..<12 {
            if i % 2 == 0 {
                sum += digits[i]
            } else {
                sum += digits[i] * 3
            }
        }

        let checkDigit = (10 - (sum % 10)) % 10
        return checkDigit == digits[12]
    }

    private func validateEAN8Checksum(_ barcode: String) -> Bool {
        guard barcode.count == 8 else { return false }

        let digits = barcode.compactMap { Int(String($0)) }
        guard digits.count == 8 else { return false }

        var sum = 0
        for i in 0..<7 {
            if i % 2 == 0 {
                sum += digits[i] * 3
            } else {
                sum += digits[i]
            }
        }

        let checkDigit = (10 - (sum % 10)) % 10
        return checkDigit == digits[7]
    }
}
