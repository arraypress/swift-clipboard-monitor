//
//  ClipboardMonitorTests.swift
//  Tests for ClipboardMonitor
//

import XCTest
import AppKit
import Combine
@testable import ClipboardMonitor

@MainActor
final class ClipboardMonitorTests: XCTestCase {
    
    var monitor: ClipboardMonitor!
    let pasteboard = NSPasteboard.general
    var cancellables = Set<AnyCancellable>()
    
    override func setUp() {
        super.setUp()
        monitor = ClipboardMonitor()
        cancellables.removeAll()
        
        // Clear clipboard before each test
        pasteboard.clearContents()
    }
    
    override func tearDown() {
        monitor.stop()
        pasteboard.clearContents()
        cancellables.removeAll()
        super.tearDown()
    }
    
    // MARK: - Basic Functionality Tests
    
    func testChangeCountDetection() {
        let initialChangeCount = pasteboard.changeCount
        
        // Change clipboard
        pasteboard.clearContents()
        pasteboard.setString("Test", forType: .string)
        
        let newChangeCount = pasteboard.changeCount
        XCTAssertNotEqual(initialChangeCount, newChangeCount, "Change count should increment")
    }
    
    func testStringCapture() {
        let expectation = expectation(description: "String capture")
        let testString = "Hello, World!"
        
        monitor.start { content in
            if content.stringValue == testString {
                XCTAssertEqual(content.stringValue, testString)
                XCTAssertTrue(content.hasType(.string))
                expectation.fulfill()
            }
        }
        
        // Trigger clipboard change after small delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.pasteboard.clearContents()
            self.pasteboard.setString(testString, forType: .string)
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testImageCapture() {
        let expectation = expectation(description: "Image capture")
        
        // Create a simple test image
        let testImage = NSImage(size: NSSize(width: 100, height: 100))
        testImage.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: 100, height: 100).fill()
        testImage.unlockFocus()
        
        monitor.start { content in
            if content.image != nil {
                XCTAssertNotNil(content.image)
                XCTAssertTrue(content.hasType(.tiff) || content.hasType(.png))
                expectation.fulfill()
            }
        }
        
        // Trigger clipboard change
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.pasteboard.clearContents()
            self.pasteboard.writeObjects([testImage])
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testFileURLCapture() {
        let expectation = expectation(description: "File URL capture")
        let testURL = URL(fileURLWithPath: "/tmp/test.txt")
        
        monitor.start { content in
            if let fileURLs = content.fileURLs, !fileURLs.isEmpty {
                XCTAssertEqual(fileURLs.first, testURL)
                expectation.fulfill()
            }
        }
        
        // Trigger clipboard change
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.pasteboard.clearContents()
            self.pasteboard.writeObjects([testURL as NSURL])
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testMultipleTypes() {
        let expectation = expectation(description: "Multiple types")
        let testString = "Test String"
        let testURL = URL(fileURLWithPath: "/tmp/test.txt")
        
        monitor.start { content in
            if content.stringValue == testString {
                XCTAssertNotNil(content.stringValue)
                XCTAssertTrue(content.availableTypes.count >= 2)
                expectation.fulfill()
            }
        }
        
        // Trigger clipboard change with multiple types
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.pasteboard.clearContents()
            self.pasteboard.setString(testString, forType: .string)
            self.pasteboard.writeObjects([testURL as NSURL])
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    // MARK: - Transient Data Tests
    
    func testTransientDataDetection() {
        let expectation = expectation(description: "Transient detection")
        let transientType = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")
        
        monitor.start { content in
            if content.hasType(transientType) {
                XCTAssertTrue(content.isTransient)
                expectation.fulfill()
            }
        }
        
        // Simulate password manager paste
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.pasteboard.clearContents()
            self.pasteboard.setString("sensitive", forType: .string)
            self.pasteboard.setData(Data(), forType: transientType)
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testConcealedDataDetection() {
        let expectation = expectation(description: "Concealed detection")
        let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
        
        monitor.start { content in
            if content.hasType(concealedType) {
                XCTAssertTrue(content.isTransient)
                expectation.fulfill()
            }
        }
        
        // Simulate password manager paste
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.pasteboard.clearContents()
            self.pasteboard.setString("password123", forType: .string)
            self.pasteboard.setData(Data(), forType: concealedType)
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testTransientDataIgnored() {
        let expectation = expectation(description: "Transient ignored")
        let transientType = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")
        
        monitor.ignoreRules.ignoreTransientData = true
        
        monitor.start { content in
            if content.isTransient {
                XCTAssertTrue(content.shouldIgnore)
                expectation.fulfill()
            }
        }
        
        // Simulate password manager paste
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.pasteboard.clearContents()
            self.pasteboard.setString("sensitive", forType: .string)
            self.pasteboard.setData(Data(), forType: transientType)
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    // MARK: - Source App Tests
    
    func testSourceAppDetection() {
        let expectation = expectation(description: "Source app detection")
        let sourceType = NSPasteboard.PasteboardType("org.nspasteboard.source")
        let testBundleId = "com.test.app"
        
        monitor.start { content in
            if let sourceApp = content.sourceAppBundleId {
                XCTAssertEqual(sourceApp, testBundleId)
                XCTAssertTrue(content.isFrom(bundleId: testBundleId))
                expectation.fulfill()
            }
        }
        
        // Set source app
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.pasteboard.clearContents()
            self.pasteboard.setString("test", forType: .string)
            self.pasteboard.setString(testBundleId, forType: sourceType)
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testBlockedAppIgnored() {
        let expectation = expectation(description: "Blocked app ignored")
        let sourceType = NSPasteboard.PasteboardType("org.nspasteboard.source")
        let blockedApp = "com.agilebits.onepassword7"
        
        monitor.ignoreRules.blockedAppBundleIds.insert(blockedApp)
        
        monitor.start { content in
            if let sourceApp = content.sourceAppBundleId, sourceApp == blockedApp {
                XCTAssertTrue(content.shouldIgnore)
                expectation.fulfill()
            }
        }
        
        // Simulate 1Password paste
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.pasteboard.clearContents()
            self.pasteboard.setString("password123", forType: .string)
            self.pasteboard.setString(blockedApp, forType: sourceType)
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testPasswordManagersSafePreset() {
        let rules = IgnoreRules.passwordManagersSafe
        
        XCTAssertTrue(rules.blockedAppBundleIds.contains("com.agilebits.onepassword7"))
        XCTAssertTrue(rules.blockedAppBundleIds.contains("com.1password.1password"))
        XCTAssertTrue(rules.blockedAppBundleIds.contains("com.lastpass.LastPass"))
        XCTAssertTrue(rules.blockedAppBundleIds.contains("com.bitwarden.desktop"))
        XCTAssertTrue(rules.ignoreTransientData)
    }
    
    // MARK: - All Data Capture Tests
    
    func testAllDataCaptured() {
        let expectation = expectation(description: "All data captured")
        let testString = "Test"
        
        monitor.start { content in
            if content.stringValue == testString {
                XCTAssertFalse(content.allData.isEmpty)
                XCTAssertNotNil(content.data(forType: .string))
                expectation.fulfill()
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.pasteboard.clearContents()
            self.pasteboard.setString(testString, forType: .string)
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testCustomTypeData() {
        let expectation = expectation(description: "Custom type data")
        let customType = NSPasteboard.PasteboardType("com.test.customtype")
        let testData = "Custom Data".data(using: .utf8)!
        
        monitor.start { content in
            if content.hasType(customType) {
                let retrievedData = content.data(forType: customType)
                XCTAssertEqual(retrievedData, testData)
                expectation.fulfill()
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.pasteboard.clearContents()
            self.pasteboard.setData(testData, forType: customType)
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    // MARK: - Control Tests
    
    func testStartStop() {
        let expectation1 = expectation(description: "First capture")
        let expectation2 = expectation(description: "Should not capture after stop")
        expectation2.isInverted = true // Should NOT be fulfilled
        
        var captureCount = 0
        
        monitor.start { _ in
            captureCount += 1
            if captureCount == 1 {
                expectation1.fulfill()
            } else if captureCount > 1 {
                expectation2.fulfill() // This should not happen
            }
        }
        
        // First change
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.pasteboard.clearContents()
            self.pasteboard.setString("First", forType: .string)
        }
        
        // Stop monitoring
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.monitor.stop()
            
            // Change clipboard again after stopping
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.pasteboard.clearContents()
                self.pasteboard.setString("Second", forType: .string)
            }
        }
        
        wait(for: [expectation1, expectation2], timeout: 2.0)
    }
    
    func testPollingInterval() {
        monitor.pollingInterval = 0.1 // Very fast for testing
        
        let expectation = expectation(description: "Fast polling")
        let startTime = Date()
        
        monitor.start { content in
            if content.stringValue == "Test" {
                let elapsed = Date().timeIntervalSince(startTime)
                // Should detect within ~0.3 seconds (3 polling cycles)
                XCTAssertLessThan(elapsed, 0.4)
                expectation.fulfill()
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.pasteboard.clearContents()
            self.pasteboard.setString("Test", forType: .string)
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Combine Publisher Tests
    
    func testPublisher() {
        let expectation = expectation(description: "Publisher emits")
        let testString = "Publisher Test"
        
        monitor.publisher()
            .sink { content in
                if content.stringValue == testString {
                    XCTAssertEqual(content.stringValue, testString)
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.pasteboard.clearContents()
            self.pasteboard.setString(testString, forType: .string)
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testPublisherIgnoreRules() {
        let expectation = expectation(description: "Publisher respects ignore rules")
        let transientType = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")
        
        monitor.ignoreRules.ignoreTransientData = true
        
        monitor.publisher()
            .sink { content in
                if content.isTransient {
                    XCTAssertTrue(content.shouldIgnore)
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.pasteboard.clearContents()
            self.pasteboard.setString("sensitive", forType: .string)
            self.pasteboard.setData(Data(), forType: transientType)
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    // MARK: - Convenience Initializer Tests
    
    func testPasswordManagerInitializer() {
        let safeMonitor = ClipboardMonitor(blockPasswordManagers: true)
        
        XCTAssertTrue(safeMonitor.ignoreRules.blockedAppBundleIds.contains("com.agilebits.onepassword7"))
        XCTAssertTrue(safeMonitor.ignoreRules.ignoreTransientData)
    }
}
