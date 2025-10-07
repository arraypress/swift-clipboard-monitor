//
//  ClipboardViewModifier.swift
//  ClipboardMonitor
//
//  Created by David Sherlock on 10/7/25.
//

#if canImport(SwiftUI)
import SwiftUI

// MARK: - View Extension

extension View {
    
    /// Monitor clipboard changes in SwiftUI views
    ///
    /// ```swift
    /// Text("Content")
    ///     .onClipboardChange { content in
    ///         print("Clipboard changed:", content.stringValue ?? "")
    ///     }
    /// ```
    public func onClipboardChange(
        ignoringPasswordManagers: Bool = true,
        perform action: @escaping (ClipboardContent) -> Void
    ) -> some View {
        modifier(ClipboardChangeModifier(
            ignoringPasswordManagers: ignoringPasswordManagers,
            action: action
        ))
    }
}

// MARK: - View Modifier

/// Private view modifier that holds the monitor instance
private struct ClipboardChangeModifier: ViewModifier {
    @StateObject private var monitor = ClipboardMonitor.Observable()
    let ignoringPasswordManagers: Bool
    let action: (ClipboardContent) -> Void
    
    init(ignoringPasswordManagers: Bool, action: @escaping (ClipboardContent) -> Void) {
        self.ignoringPasswordManagers = ignoringPasswordManagers
        self.action = action
    }
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                if ignoringPasswordManagers {
                    monitor.monitor.ignoreRules = .passwordManagersSafe
                }
            }
            .onChange(of: monitor.current) { _, newValue in
                if let newValue, !newValue.shouldIgnore {
                    action(newValue)
                }
            }
    }
}
#endif
