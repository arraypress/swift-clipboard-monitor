# Swift Clipboard Monitor

A robust macOS clipboard monitoring library for Swift that provides real-time notifications when clipboard content changes, with built-in security features for password managers.

## Features

- 🔄 **Real-time clipboard monitoring** with configurable polling interval
- 🔐 **Password manager protection** - automatically ignores sensitive data from 1Password, LastPass, Bitwarden, and more
- 📊 **Multiple consumption patterns**: Callbacks, Combine publishers, and AsyncStream
- 🎨 **SwiftUI support** with ObservableObject and view modifiers
- 🏷️ **Rich metadata**: source app, timestamps, data types, and more
- ⚡ **Rate limiting** to prevent excessive processing
- 🐛 **Debug logging** support

## Requirements

- macOS 15.0+
- Swift 5.9+
- Xcode 15.0+

## Installation

### Swift Package Manager

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/arraypress/swift-clipboard-monitor.git", from: "1.0.0")
]
```

Or in Xcode:
1. File → Add Package Dependencies
2. Enter the repository URL
3. Choose version requirements

## Usage

### Basic Monitoring

```swift
import ClipboardMonitor

let monitor = ClipboardMonitor()

// Start monitoring with a callback
monitor.start { content in
    guard !content.shouldIgnore else { return }
    
    print("Clipboard changed!")
    print("Text: \(content.stringValue ?? "none")")
    print("Source: \(content.sourceAppBundleId ?? "unknown")")
    print("Types: \(content.availableTypes)")
}

// Stop monitoring when done
monitor.stop()
```

### Password Manager Protection

```swift
// Block password managers automatically
let monitor = ClipboardMonitor(blockPasswordManagers: true)

// Or configure manually
monitor.ignoreRules = .passwordManagersSafe

// Add custom blocked apps
monitor.ignoreRules.blockedAppBundleIds.insert("com.suspicious.app")
```

### Async/Await with AsyncStream

```swift
let monitor = ClipboardMonitor()

for await content in monitor.stream() {
    guard !content.shouldIgnore else { continue }
    
    if let text = content.stringValue {
        print("New text: \(text)")
    }
    
    if content.hasImage {
        print("Image copied!")
    }
}
```

### Combine Publisher

```swift
import Combine

var cancellables = Set<AnyCancellable>()
let monitor = ClipboardMonitor()

monitor.publisher()
    .filter { !$0.shouldIgnore }
    .filter { $0.hasRichText }
    .sink { content in
        print("Rich text copied: \(content.stringValue ?? "")")
    }
    .store(in: &cancellables)
```

### SwiftUI Integration

#### Using ObservableObject

```swift
import SwiftUI

struct ContentView: View {
    @StateObject private var clipboard = ClipboardMonitor.Observable(
        blockPasswordManagers: true
    )
    
    var body: some View {
        VStack {
            Text("Current: \(clipboard.current?.stringValue ?? "Empty")")
            
            List(clipboard.history, id: \.changeCount) { item in
                Text(item.stringValue ?? "Non-text content")
                    .font(.caption)
            }
        }
        .onChange(of: clipboard.current) { _, newValue in
            if let content = newValue {
                handleClipboardChange(content)
            }
        }
    }
}
```

#### Using View Modifier

```swift
struct MyView: View {
    var body: some View {
        Text("Monitoring clipboard...")
            .onClipboardChange { content in
                print("Clipboard changed: \(content.stringValue ?? "")")
            }
    }
}
```

## Configuration Options

### Polling Interval

```swift
// Check every 100ms instead of default 300ms
monitor.pollingInterval = 0.1
```

### Rate Limiting

```swift
// Minimum 1 second between notifications
monitor.minimumTimeBetweenUpdates = 1.0
```

### Debug Logging

```swift
// Enable detailed logging
monitor.debugLogging = true
```

### Ignore Rules

```swift
// Ignore clipboard changes from your own app
monitor.ignoreRules.ignoreSelfPastes = true

// Don't ignore transient data (not recommended)
monitor.ignoreRules.ignoreTransientData = false
```

## Clipboard Content Properties

The `ClipboardContent` struct provides rich information about clipboard data:

```swift
let content: ClipboardContent = ...

// Basic properties
content.timestamp           // When content was captured
content.changeCount         // macOS clipboard change count
content.stringValue         // Text content if available
content.image              // NSImage if available
content.fileURLs           // Array of file URLs if available

// Metadata
content.sourceAppBundleId  // App that set the clipboard
content.isTransient        // Whether data is marked as sensitive
content.shouldIgnore       // Whether to ignore based on rules
content.totalSize          // Total size in bytes

// Type checking
content.hasRichText        // Has RTF/HTML content
content.hasImage           // Has image content
content.hasType(.pdf)      // Check for specific type

// Raw data access
content.availableTypes     // All pasteboard types
content.allData           // Dictionary of all raw data
content.data(forType: .html) // Get specific type data
```

## Security Considerations

This library helps protect sensitive data by:

1. **Ignoring transient/concealed data** - Password managers mark sensitive data with special flags
2. **Blocking known password managers** - Pre-configured list of common password manager bundle IDs
3. **Source app detection** - Know which app set the clipboard

The library includes protection for:
- 1Password (7 & 8)
- LastPass
- Dashlane
- Bitwarden
- Keeper Security

## Performance

- **Efficient polling** - Only processes when clipboard actually changes
- **Rate limiting** - Prevent excessive processing
- **Weak references** - Proper memory management in publishers
- **MainActor isolation** - Thread-safe pasteboard access

## Testing

The library includes comprehensive tests. Run them with:

```bash
swift test
```

Note: Some tests may show sandbox warnings for file URLs - this is normal and doesn't affect functionality.

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## License

MIT License - see LICENSE file for details

## Author

Created by David Sherlock (ArrayPress) in 2025.

## Acknowledgments

- Thanks to the Swift community for feedback and suggestions
- Special thanks to password manager developers for implementing clipboard security markers
