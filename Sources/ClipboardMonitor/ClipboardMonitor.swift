//
//  ClipboardMonitor.swift
//  ClipboardMonitor
//
//  Created by David Sherlock on 2024.
//

import AppKit
import Combine
import os.log

/// Monitors the macOS clipboard for changes and publishes updates.
///
/// ## Usage
///
/// ```swift
/// let monitor = ClipboardMonitor()
///
/// // Basic usage
/// monitor.start { content in
///     guard !content.shouldIgnore else { return }
///     print("Clipboard changed:", content.stringValue ?? "")
/// }
/// ```
@MainActor
public final class ClipboardMonitor: @unchecked Sendable {
    
    // MARK: - Configuration
    
    /// How often to check the clipboard (in seconds)
    public var pollingInterval: TimeInterval = 0.3 {
        didSet {
            if isMonitoring {
                stop()
                if let handler = currentHandler {
                    start(onChange: handler)
                }
            }
        }
    }
    
    /// Minimum time between update notifications (0 = no rate limiting)
    public var minimumTimeBetweenUpdates: TimeInterval = 0.0
    
    /// Rules for ignoring certain clipboard content
    public var ignoreRules = IgnoreRules()
    
    /// Enable debug logging
    public var debugLogging = false
    
    // MARK: - Internal Properties
    
    /// The active Combine cancellable for the polling timer
    internal var cancellable: AnyCancellable?
    
    /// Tracks the last known clipboard change count to detect changes
    internal var lastChangeCount: Int = -1
    
    /// Timestamp of the last notification sent (for rate limiting)
    internal var lastNotificationTime = Date.distantPast
    
    /// Reference to the system pasteboard
    internal let pasteboard = NSPasteboard.general
    
    /// Storage for the current change handler callback
    internal var currentHandler: ((ClipboardContent) -> Void)?
    
    /// Flag indicating whether monitoring is currently active
    internal var isMonitoring = false
    
    /// System logger for debug output
    internal let logger = Logger(subsystem: "ClipboardMonitor", category: "Monitor")
    
    /// Continuation for AsyncStream support
    internal var streamContinuation: AsyncStream<ClipboardContent>.Continuation?
    
    // MARK: - Special Pasteboard Types
    
    /// Pasteboard type indicating the source application bundle ID
    internal static let sourceAppBundleIdType = NSPasteboard.PasteboardType("org.nspasteboard.source")
    
    /// Pasteboard type indicating concealed/sensitive data
    internal static let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
    
    /// Pasteboard type indicating transient data (typically from password managers)
    internal static let transientType = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")
    
    // MARK: - Initialization
    
    public init() {}
    
    /// Convenience initializer with password manager protection
    /// - Parameter blockPasswordManagers: If true, applies password manager blocking rules
    public convenience init(blockPasswordManagers: Bool) {
        self.init()
        if blockPasswordManagers {
            self.ignoreRules = .passwordManagersSafe
        }
    }
    
    // MARK: - Control
    
    /// Start monitoring the clipboard
    ///
    /// - Parameter onChange: Closure called whenever clipboard changes
    public func start(onChange: @escaping (ClipboardContent) -> Void) {
        // Stop any existing monitoring
        stop()
        
        currentHandler = onChange
        isMonitoring = true
        
        // Initialize with current state
        lastChangeCount = pasteboard.changeCount
        
        log("Started monitoring (interval: \(pollingInterval)s)")
        
        // Set up timer-based polling
        cancellable = Timer.publish(
            every: pollingInterval,
            tolerance: pollingInterval * 0.1,
            on: .main,
            in: .common
        )
        .autoconnect()
        .sink { [weak self] _ in
            self?.checkForChanges(onChange: onChange)
        }
    }
    
    /// Stop monitoring the clipboard
    public func stop() {
        cancellable?.cancel()
        cancellable = nil
        currentHandler = nil
        isMonitoring = false
        streamContinuation?.finish()
        streamContinuation = nil
        log("Stopped monitoring")
    }
    
    // MARK: - Internal Methods
    
    /// Checks if the clipboard has changed and notifies the handler if so.
    ///
    /// This method is called periodically by the polling timer. It compares the current
    /// clipboard change count with the last known value to detect changes.
    ///
    /// - Parameter onChange: The callback to invoke when a change is detected
    internal func checkForChanges(onChange: (ClipboardContent) -> Void) {
        let currentChangeCount = pasteboard.changeCount
        
        // Only process if clipboard actually changed
        guard currentChangeCount != lastChangeCount else {
            return
        }
        
        // Rate limiting
        let now = Date()
        if minimumTimeBetweenUpdates > 0 &&
            now.timeIntervalSince(lastNotificationTime) < minimumTimeBetweenUpdates {
            log("Skipped update due to rate limiting")
            return
        }
        
        lastChangeCount = currentChangeCount
        lastNotificationTime = now
        
        // Capture ALL clipboard content
        var content = captureAllContent(changeCount: currentChangeCount)
        
        // Apply ignore rules
        content.shouldIgnore = shouldIgnoreContent(content)
        
        log("Clipboard changed (count: \(currentChangeCount), ignored: \(content.shouldIgnore))")
        
        onChange(content)
    }
    
    /// Captures all available data from the clipboard.
    ///
    /// This method reads all available types from the pasteboard and creates a comprehensive
    /// snapshot of the clipboard content, including text, images, files, and raw data.
    ///
    /// - Parameter changeCount: The current clipboard change count
    /// - Returns: A `ClipboardContent` instance containing all clipboard data
    internal func captureAllContent(changeCount: Int) -> ClipboardContent {
        let types = pasteboard.types ?? []
        
        // Capture ALL data for ALL types
        var allData: [NSPasteboard.PasteboardType: Data] = [:]
        for type in types {
            if let data = pasteboard.data(forType: type) {
                allData[type] = data
            }
        }
        
        // Check for transient/concealed markers
        let isTransient = types.contains(Self.transientType) || types.contains(Self.concealedType)
        
        // Get source app bundle ID
        let sourceAppBundleId = pasteboard.string(forType: Self.sourceAppBundleIdType)
        
        return ClipboardContent(
            timestamp: Date(),
            changeCount: changeCount,
            sourceAppBundleId: sourceAppBundleId,
            isTransient: isTransient,
            stringValue: pasteboard.string(forType: .string),
            image: NSImage(pasteboard: pasteboard),
            fileURLs: pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL],
            availableTypes: types,
            allData: allData
        )
    }
    
    /// Determines whether clipboard content should be ignored based on configured rules.
    ///
    /// Evaluates the content against the current ignore rules, including:
    /// - Transient/concealed data filtering
    /// - Blocked application bundle IDs
    /// - Self-paste filtering
    ///
    /// - Parameter content: The clipboard content to evaluate
    /// - Returns: `true` if the content should be ignored, `false` otherwise
    internal func shouldIgnoreContent(_ content: ClipboardContent) -> Bool {
        // Ignore transient/concealed data (password managers use this)
        if ignoreRules.ignoreTransientData && content.isTransient {
            log("Ignoring transient data")
            return true
        }
        
        // Ignore specific apps
        if let sourceApp = content.sourceAppBundleId {
            if ignoreRules.blockedAppBundleIds.contains(sourceApp) {
                log("Ignoring blocked app: \(sourceApp)")
                return true
            }
            
            // Ignore self if configured
            if ignoreRules.ignoreSelfPastes && sourceApp == Bundle.main.bundleIdentifier {
                log("Ignoring self paste")
                return true
            }
        }
        
        return false
    }
    
    /// Logs a debug message if debug logging is enabled.
    ///
    /// Messages are logged using the system logger with public privacy level.
    ///
    /// - Parameter message: The message to log
    internal func log(_ message: String) {
        guard debugLogging else { return }
        logger.debug("[\(message, privacy: .public)]")
    }
    
}
