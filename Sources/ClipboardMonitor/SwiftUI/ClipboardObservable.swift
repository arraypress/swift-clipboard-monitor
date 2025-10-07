//
//  ClipboardObservable.swift
//  ClipboardMonitor
//
//  Created by David Sherlock on 10/7/25.
//

#if canImport(SwiftUI)
import SwiftUI

extension ClipboardMonitor {
    
    /// Observable object for SwiftUI integration that monitors clipboard changes.
    ///
    /// This class provides a SwiftUI-friendly wrapper around ClipboardMonitor,
    /// automatically publishing changes to trigger view updates. It maintains
    /// both the current clipboard content and a configurable history.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// @StateObject private var clipboard = ClipboardMonitor.Observable()
    ///
    /// var body: some View {
    ///     Text(clipboard.current?.stringValue ?? "Empty")
    ///         .onChange(of: clipboard.current) { _, newValue in
    ///             // Handle change
    ///         }
    /// }
    /// ```
    @MainActor
    public final class Observable: ObservableObject {
        
        // MARK: - Published Properties
        
        /// The most recent clipboard content.
        ///
        /// This property is updated whenever the clipboard changes and will
        /// trigger SwiftUI view updates through the `@Published` wrapper.
        @Published public private(set) var current: ClipboardContent?
        
        /// Historical list of clipboard contents.
        ///
        /// Stores up to `maxHistorySize` items, with the most recent at index 0.
        /// Only non-ignored content is added to history.
        @Published public private(set) var history: [ClipboardContent] = []
        
        // MARK: - Configuration
        
        /// Maximum number of items to keep in history.
        ///
        /// When this value is changed, the history is immediately trimmed
        /// if it exceeds the new limit. Default is 10.
        public var maxHistorySize = 10 {
            didSet {
                trimHistory()
            }
        }
        
        // MARK: - Internal Properties
        
        /// The underlying clipboard monitor instance.
        ///
        /// Marked as internal to allow access from the view modifier
        /// for configuration purposes.
        internal let monitor = ClipboardMonitor()
        
        // MARK: - Initialization
        
        /// Creates a new observable clipboard monitor.
        ///
        /// - Parameter blockPasswordManagers: If `true`, applies default rules to
        ///   ignore clipboard data from known password managers. Default is `false`.
        public init(blockPasswordManagers: Bool = false) {
            if blockPasswordManagers {
                monitor.ignoreRules = .passwordManagersSafe
            }
            
            monitor.start { [weak self] content in
                self?.current = content
                if !content.shouldIgnore {
                    self?.addToHistory(content)
                }
            }
        }
        
        // MARK: - Private Methods
        
        /// Adds clipboard content to the history.
        ///
        /// Inserts the content at the beginning of the history array
        /// and triggers trimming to maintain size limit.
        ///
        /// - Parameter content: The clipboard content to add to history
        private func addToHistory(_ content: ClipboardContent) {
            history.insert(content, at: 0)
            trimHistory()
        }
        
        /// Trims the history array to respect `maxHistorySize`.
        ///
        /// Removes the oldest items if the history exceeds the maximum size.
        private func trimHistory() {
            if history.count > maxHistorySize {
                history = Array(history.prefix(maxHistorySize))
            }
        }
        
        // MARK: - Public Methods
        
        /// Clears all items from the clipboard history.
        ///
        /// The current clipboard content is not affected.
        public func clearHistory() {
            history.removeAll()
        }
        
        // MARK: - Cleanup
        
        deinit {
            // Clean up the monitor when Observable is deallocated
            // We need to dispatch to MainActor since stop() is MainActor-isolated
            let monitor = self.monitor
            Task { @MainActor in
                monitor.stop()
            }
        }
    }
}
#endif
