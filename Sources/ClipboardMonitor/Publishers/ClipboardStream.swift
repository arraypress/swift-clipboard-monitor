//
//  ClipboardStream.swift
//  ClipboardMonitor
//
//  Created by David Sherlock on 10/7/25.
//

import Foundation

extension ClipboardMonitor {
    
    /// Returns an AsyncStream that emits clipboard changes
    ///
    /// ```swift
    /// for await content in monitor.stream() {
    ///     guard !content.shouldIgnore else { continue }
    ///     print("Changed:", content.stringValue ?? "")
    /// }
    /// ```
    public func stream() -> AsyncStream<ClipboardContent> {
        AsyncStream { continuation in
            self.streamContinuation = continuation
            
            start { content in
                continuation.yield(content)
            }
            
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in
                    self?.stop()
                }
            }
        }
    }
    
}
