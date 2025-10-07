//
//  ClipboardContent.swift
//  ClipboardMonitor
//
//  Created by David Sherlock on 10/7/25.
//

import AppKit

/// Represents clipboard content at a point in time
public struct ClipboardContent: Sendable, Equatable {
    
    /// When this content was detected
    public let timestamp: Date
    
    /// The clipboard change count when this was captured
    public let changeCount: Int
    
    /// Bundle ID of the app that copied this data (if available)
    public let sourceAppBundleId: String?
    
    /// Whether this is transient/concealed data (e.g., from password manager)
    public let isTransient: Bool
    
    /// String content, if available
    public let stringValue: String?
    
    /// Image content, if available
    public let image: NSImage?
    
    /// File URLs, if available
    public let fileURLs: [URL]?
    
    /// All available types on the clipboard
    public let availableTypes: [NSPasteboard.PasteboardType]
    
    /// All raw data by type (for full access)
    public let allData: [NSPasteboard.PasteboardType: Data]
    
    /// Whether this content should be ignored based on rules
    public internal(set) var shouldIgnore: Bool = false
    
    /// Total size of clipboard data in bytes
    public var totalSize: Int {
        allData.values.reduce(0) { $0 + $1.count }
    }
    
    /// Whether clipboard contains rich text
    public var hasRichText: Bool {
        hasType(.rtf) || hasType(.rtfd) || hasType(.html)
    }
    
    /// Whether clipboard contains images
    public var hasImage: Bool {
        hasType(.tiff) || hasType(.png) || hasType(.pdf)
    }
    
    /// Check if clipboard has specific type
    public func hasType(_ type: NSPasteboard.PasteboardType) -> Bool {
        availableTypes.contains(type)
    }
    
    /// Get raw data for a specific type
    public func data(forType type: NSPasteboard.PasteboardType) -> Data? {
        allData[type]
    }
    
    /// Check if this came from a specific app
    public func isFrom(bundleId: String) -> Bool {
        sourceAppBundleId == bundleId
    }
    
    /// Equatable implementation - based on changeCount and timestamp
    public static func == (lhs: ClipboardContent, rhs: ClipboardContent) -> Bool {
        lhs.changeCount == rhs.changeCount &&
        lhs.timestamp == rhs.timestamp
    }
    
}
