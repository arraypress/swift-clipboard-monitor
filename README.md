# Swift Clipboard Monitor

A lightweight macOS library for observing the system clipboard and reacting to changes in real time. It polls `NSPasteboard`, captures every available representation (text, image, file URLs, and raw typed data), and delivers rich snapshots through a closure, an `AsyncStream`, a Combine publisher, or a SwiftUI view modifier. Built-in ignore rules let you safely skip transient data from password managers.

## Features

- 📋 **Full clipboard capture** — collects text, images, file URLs, available types, and raw data for every change
- 🔁 **Closure callbacks** — `start(onChange:)` delivers a `ClipboardContent` snapshot whenever the pasteboard changes
- 🌊 **AsyncStream support** — iterate clipboard changes with `for await content in monitor.stream()`
- 🔗 **Combine publisher** — subscribe via `monitor.publisher()` for reactive pipelines
- 🖼️ **SwiftUI integration** — `.onClipboardChange { ... }` modifier and a `ClipboardMonitor.Observable` object with history
- 🔒 **Password manager safety** — ships a curated block list and ignores transient/concealed data by default
- 🚦 **Rate limiting** — `minimumTimeBetweenUpdates` throttles rapid clipboard churn
- ⏱️ **Configurable polling** — tune `pollingInterval` to balance responsiveness and overhead
- 🏷️ **Source attribution** — reads the copying app's bundle ID when available
- 🧾 **History tracking** — the observable keeps a trimmed, configurable history of recent items
- 🐞 **Debug logging** — opt-in `os.log` output for diagnosing behavior

## Requirements

- macOS 15.0+
- Swift 6.0+
- Xcode 16.0+

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/arraypress/swift-clipboard-monitor.git", from: "1.0.0")
]
```

## Usage

### Basic Monitoring

```swift
import ClipboardMonitor

let monitor = ClipboardMonitor()

monitor.start { content in
    guard !content.shouldIgnore else { return }
    print("Clipboard changed:", content.stringValue ?? "")
}

// Later
monitor.stop()
```

### Blocking Password Managers

```swift
import ClipboardMonitor

let monitor = ClipboardMonitor(blockPasswordManagers: true)
monitor.start { content in
    // Transient/concealed data and known password managers are flagged via content.shouldIgnore
    guard !content.shouldIgnore else { return }
    print(content.stringValue ?? "")
}
```

### AsyncStream

```swift
import ClipboardMonitor

let monitor = ClipboardMonitor()

for await content in monitor.stream() {
    guard !content.shouldIgnore else { continue }
    print("Changed:", content.stringValue ?? "")
}
```

### Combine Publisher

```swift
import Combine
import ClipboardMonitor

let monitor = ClipboardMonitor()
var cancellables = Set<AnyCancellable>()

monitor.publisher()
    .filter { !$0.shouldIgnore }
    .sink { content in
        print("Changed:", content.stringValue ?? "")
    }
    .store(in: &cancellables)
```

### SwiftUI

```swift
import SwiftUI
import ClipboardMonitor

struct ContentView: View {
    var body: some View {
        Text("Copy something")
            .onClipboardChange { content in
                print("Clipboard:", content.stringValue ?? "")
            }
    }
}
```

Or use the observable object directly for live state and history:

```swift
import SwiftUI
import ClipboardMonitor

struct HistoryView: View {
    @StateObject private var clipboard = ClipboardMonitor.Observable(blockPasswordManagers: true)

    var body: some View {
        VStack {
            Text(clipboard.current?.stringValue ?? "Empty")
            List(clipboard.history, id: \.changeCount) { item in
                Text(item.stringValue ?? "<non-text>")
            }
            Button("Clear History") { clipboard.clearHistory() }
        }
    }
}
```

### Configuration

```swift
let monitor = ClipboardMonitor()
monitor.pollingInterval = 0.5
monitor.minimumTimeBetweenUpdates = 1.0
monitor.debugLogging = true
monitor.ignoreRules.blockedAppBundleIds.insert("com.example.app")
monitor.ignoreRules.ignoreSelfPastes = true
```

## How It Works

`ClipboardMonitor` runs a `Timer.publish` poller on the main run loop and compares `NSPasteboard.general.changeCount` against the last seen value. When it changes, it reads every available type into a `ClipboardContent` snapshot, evaluates the configured `IgnoreRules` (transient/concealed data, blocked bundle IDs, self-pastes), and notifies subscribers.

## Models

### `ClipboardContent`

| Property | Type | Description |
|----------|------|-------------|
| `timestamp` | `Date` | When this content was detected |
| `changeCount` | `Int` | Pasteboard change count at capture time |
| `sourceAppBundleId` | `String?` | Bundle ID of the copying app, if available |
| `isTransient` | `Bool` | Whether the data is transient/concealed |
| `stringValue` | `String?` | Text content, if present |
| `image` | `NSImage?` | Image content, if present |
| `fileURLs` | `[URL]?` | File URLs, if present |
| `availableTypes` | `[NSPasteboard.PasteboardType]` | All types on the pasteboard |
| `allData` | `[NSPasteboard.PasteboardType: Data]` | Raw data keyed by type |
| `shouldIgnore` | `Bool` | Whether ignore rules flagged this content |
| `totalSize` | `Int` | Total size of all data in bytes (computed) |
| `hasRichText` | `Bool` | Whether RTF/RTFD/HTML is present (computed) |
| `hasImage` | `Bool` | Whether TIFF/PNG/PDF is present (computed) |

`ClipboardContent` also exposes `hasType(_:)`, `data(forType:)`, and `isFrom(bundleId:)` helpers.

### `IgnoreRules`

| Property | Type | Description |
|----------|------|-------------|
| `blockedAppBundleIds` | `Set<String>` | Bundle IDs to ignore |
| `ignoreTransientData` | `Bool` | Ignore transient/concealed data (default `true`) |
| `ignoreSelfPastes` | `Bool` | Ignore pastes from the host app (default `false`) |

`IgnoreRules.passwordManagersSafe` provides a preset with common password manager bundle IDs blocked.

## Use Cases

- Clipboard history and manager apps
- Snippet capture and productivity tools
- Security-aware utilities that need to skip sensitive copies
- Automations that react to copied URLs, files, or images

## Testing

```bash
swift test
```

The test suite covers change detection, content capture, ignore-rule evaluation (including transient data and blocked bundle IDs), and rate limiting.

## License

MIT License — see LICENSE file for details.

## Author

Created by David Sherlock ([ArrayPress](https://github.com/arraypress)) in 2026.
