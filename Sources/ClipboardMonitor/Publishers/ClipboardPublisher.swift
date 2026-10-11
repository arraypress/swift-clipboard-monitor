//
//  ClipboardPublisher.swift
//  ClipboardMonitor
//
//  Created by David Sherlock on 10/7/25.
//

import AppKit
import Combine
import Foundation

extension ClipboardMonitor {
    
    /// Returns a Combine publisher that emits clipboard changes
    ///
    /// Note: Each call creates a new monitoring session. For multiple subscribers,
    /// consider sharing the publisher with `.share()` operator.
    ///
    /// ```swift
    /// monitor.publisher()
    ///     .filter { !$0.shouldIgnore }
    ///     .sink { content in
    ///         print("Changed:", content.stringValue)
    ///     }
    ///     .store(in: &cancellables)
    /// ```
    public func publisher() -> AnyPublisher<ClipboardContent, Never> {
        Timer.publish(
            every: pollingInterval,
            tolerance: pollingInterval * 0.1,
            on: .main,
            in: .common
        )
        .autoconnect()
        .prepend([Date()]) // Check immediately
        .map { [weak self] _ in
            self?.pasteboard.changeCount ?? 0
        }
        .removeDuplicates() // Only emit when changeCount changes
        .compactMap { [weak self] changeCount -> ClipboardContent? in
            guard let self else { return nil }
            
            // Rate limiting
            let now = Date()
            if now.timeIntervalSince(self.lastNotificationTime) < self.minimumTimeBetweenUpdates {
                return nil
            }
            self.lastNotificationTime = now
            
            var content = self.captureAllContent(changeCount: changeCount)
            content.shouldIgnore = self.shouldIgnoreContent(content)
            return content
        }
        .eraseToAnyPublisher()
    }
    
}
