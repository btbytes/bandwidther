# Bandwidther Code Walkthrough

- *2026-03-28 by Showboat 0.6.1*
- *2026-03-28 by Opencode+ Minimax  2.5*

Bandwidther is a native macOS menu bar app that monitors per-process network bandwidth in real time. The application has been refactored from a single ~1000-line file into a modular structure with 15 Swift files organized into clear layers. This makes the codebase easier to maintain and understand.

## Project Structure

```
Bandwidther/
├── App.swift              # @main entry point
├── AppDelegate.swift      # Menu bar integration
├── Models.swift           # Data models
├── DNSCache.swift         # Reverse DNS resolution
├── NetworkMonitor.swift   # Central coordinator & data collection
├── Formatting.swift       # Human-readable byte formatting
└── Views/
    ├── ContentView.swift          # Main two-column layout
    ├── SparklineView.swift       # Real-time bandwidth chart
    ├── ProcessBandwidthRow.swift # Per-process table rows
    ├── RateCardView.swift        # Download/upload rate cards
    ├── ProcessRow.swift         # Internet/LAN process lists
    ├── SectionHeader.swift       # Section headers
    ├── SortButton.swift         # Sort column buttons
    ├── BarView.swift            # Proportional bandwidth bars
    └── MenuBarIconView.swift    # Status bar icon
```

## 1. Data Models (Models.swift)

The app defines data types that flow through the entire pipeline:

```swift
// Models.swift
struct BandwidthRate {
    let bytesInPerSec: Double
    let bytesOutPerSec: Double

    var totalPerSec: Double { bytesInPerSec + bytesOutPerSec }

    static let zero = BandwidthRate(bytesInPerSec: 0, bytesOutPerSec: 0)
}

struct ProcessBandwidth: Identifiable {
    let id: String
    let name: String
    let bytesInPerSec: Double
    let bytesOutPerSec: Double
    let totalBytesIn: UInt64
    let totalBytesOut: UInt64
    let connections: Int

    var totalPerSec: Double { bytesInPerSec + bytesOutPerSec }
    var totalBytes: UInt64 { totalBytesIn + totalBytesOut }
}

enum ProcessSortKey: String, CaseIterable {
    case totalRate = "Rate"
    case download = "Down"
    case upload = "Up"
    case totalBytes = "Total"
    case name = "Name"
}

struct ConnectionSummary {
    var internetCount: Int = 0
    var lanCount: Int = 0
    var internetProcesses: [String: Int] = [:]
    var lanProcesses: [String: Int] = [:]
    var internetDestinations: [String] = []
    var lanDestinations: [String] = []
}

struct NetworkEndpoint {
    let host: String
    let port: String

    var displayString: String {
        if host.contains(":") {
            return "[\(host)]:\(port)"
        }
        return "\(host):\(port)"
    }
}

struct NettopProcessData {
    var bytesIn: UInt64 = 0
    var bytesOut: UInt64 = 0
    var pids: Set<String> = []
}

struct NettopResult {
    var totals: [String: NettopProcessData] = [:]
    var deltas: [String: NettopProcessData] = [:]
    var errorMessage: String?
}
```

- **`BandwidthRate`** — a single snapshot of download/upload bytes-per-second. The sparkline graph stores 60 of these.
- **`ProcessBandwidth`** — one row in the per-process table: name, current rates, cumulative totals, and PID count. Conforms to `Identifiable` (keyed on process name) so SwiftUI `ForEach` can diff it.
- **`ProcessSortKey`** — the five columns the user can sort by. `CaseIterable` drives the sort-button bar.
- **`ConnectionSummary`** — aggregated connection counts and destination lists, split into internet vs LAN.
- **`NetworkEndpoint`** — represents a remote endpoint with host and port, handling both IPv4 and IPv6 addresses.
- **`NettopProcessData`** / **`NettopResult`** — internal structures for parsing nettop output.

## 2. Reverse DNS Cache (DNSCache.swift)

The `DNSCache` class resolves IP addresses to hostnames asynchronously. It now supports both IPv4 and IPv6:

```swift
// DNSCache.swift
@Observable
final class DNSCache {
    private(set) var resolved: [String: String] = [:]
    private var pending: Set<String> = []
    private let queue = DispatchQueue(label: "dns-resolver", attributes: .concurrent)

    func resolve(_ ip: String) {
        if resolved[ip] != nil || pending.contains(ip) { return }
        pending.insert(ip)

        queue.async { [weak self] in
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result: Int32

            if ip.contains(":") {
                // IPv6
                var sa = sockaddr_in6()
                sa.sin6_len = UInt8(MemoryLayout<sockaddr_in6>.size)
                sa.sin6_family = sa_family_t(AF_INET6)
                result = inet_pton(AF_INET6, ip, &sa.sin6_addr) == 1
                    ? withUnsafePointer(to: &sa) { saPtr in
                        saPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                            getnameinfo(sockPtr, socklen_t(MemoryLayout<sockaddr_in6>.size),
                                        &hostname, socklen_t(hostname.count),
                                        nil, 0, NI_NAMEREQD)
                        }
                    }
                    : EAI_NONAME
            } else {
                // IPv4
                var sa = sockaddr_in()
                sa.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
                sa.sin_family = sa_family_t(AF_INET)
                result = inet_pton(AF_INET, ip, &sa.sin_addr) == 1
                    ? withUnsafePointer(to: &sa) { saPtr in
                        saPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                            getnameinfo(sockPtr, socklen_t(MemoryLayout<sockaddr_in>.size),
                                        &hostname, socklen_t(hostname.count),
                                        nil, 0, NI_NAMEREQD)
                        }
                    }
                    : EAI_NONAME
            }
            // ... result handling
        }
    }
}
```

Key design points:

- **IPv4/IPv6 dual support** — detects whether the IP contains `:` to determine address family, then constructs the appropriate `sockaddr_in` or `sockaddr_in6`.
- **Deduplication** — the `pending` set prevents multiple in-flight lookups for the same IP.
- **Failure sentinel** — failed lookups store an empty string (`""`) rather than `nil`, preventing infinite retries.
- **Thread safety** — lookups run on a concurrent dispatch queue; results dispatch to main queue for SwiftUI updates.
- **@Observable macro** — modern Swift observation (iOS 17+/macOS 14+) replaces `@Published` + `ObservableObject`.

## 3. NetworkMonitor — Central Coordinator (NetworkMonitor.swift)

`NetworkMonitor` is the heart of the app, using Swift's modern `@Observable` macro and async/await:

```swift
// NetworkMonitor.swift (lines 1-50)
@Observable
final class NetworkMonitor {
    var currentRate: BandwidthRate = .zero
    var totalBytesIn: UInt64 = 0
    var totalBytesOut: UInt64 = 0
    var nettopStatus: String?
    var connectionSummary: ConnectionSummary = ConnectionSummary()
    var dnsCache: DNSCache = DNSCache()
    var rateHistory: [BandwidthRate] = []
    var processBandwidths: [ProcessBandwidth] = []
    var processSortKey: ProcessSortKey = .totalRate
    var processSortAscending: Bool = false

    private var connTimer: Timer?
    private var nettopTimer: Timer?
    private let maxHistory = 60

    init() {
        refreshConnections()
        connTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.refreshConnections()
        }
        refreshNettop()
        nettopTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.refreshNettop()
        }
    }
}
```

Two independent polling loops run every 3 seconds:

1. **`refreshNettop()`** — uses Swift's `Task` to run `runNettopAsync()` on a background thread, then processes results on the main thread via `processNettopResult()`.

2. **`refreshConnections()`** — runs `lsof -n -P -iTCP` to get connection info, classifies as internet vs LAN, and triggers DNS resolution.

### Nettop Parser

The nettop invocation uses delta mode (`-d`) for more reliable measurements:

```swift
// NetworkMonitor.swift (lines 258-270)
private func runNettopAsync() async -> NettopResult {
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/usr/bin/nettop")
    proc.arguments = ["-d", "-P", "-L", "2", "-s", "1", "-x", "-n", "-J", "bytes_in,bytes_out"]
    // ...
}
```

- **`-d`** — delta mode (new in recent macOS), provides cleaner per-interval data
- **`-P`** — per-process summary mode
- **`-L 2`** — two samples (cumulative + delta)
- **`-s 1`** — one-second interval
- **`-x`** — raw numeric output
- **`-n`** — skip DNS resolution
- **`-J bytes_in,bytes_out`** — restrict to these columns

### Connection Parsing (NetworkMonitor.swift)

The connection tracking now uses `lsof` directly instead of `netstat`:

```swift
// NetworkMonitor.swift (lines 138-179)
private func parseConnectionsAsync() async -> ConnectionSummary {
    var summary = ConnectionSummary()

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
    process.arguments = ["-n", "-P", "-iTCP"]
    // ... parse ESTABLISHED/SYN_SENT/CLOSE_WAIT connections
    // ... classify as LAN or Internet via isLocalAddress()
}
```

**IPv6 and Local Address Detection:**

```swift
// NetworkMonitor.swift (lines 209-223)
private func isLocalAddress(_ host: String) -> Bool {
    if host == "localhost" || host == "::1" { return true }
    if host.hasPrefix("fe80:") || host.hasPrefix("FE80:") { return true }  // link-local
    if host.hasPrefix("fc") || host.hasPrefix("FC") || host.hasPrefix("fd") || host.hasPrefix("FD") {
        return true  // IPv6 unique local addresses
    }

    // IPv4 private ranges
    if host.hasPrefix("10.") || host.hasPrefix("127.") || host.hasPrefix("169.254.") { return true }
    if host.hasPrefix("192.168.") { return true }
    if host.hasPrefix("172.") {
        let parts = host.split(separator: ".")
        if parts.count >= 2, let second = Int(parts[1]), (16...31).contains(second) { return true }
    }
    return false
}
```

## 4. Formatting Helpers (Formatting.swift)

Three small functions convert raw byte counts to human-readable strings:

```swift
// Formatting.swift
func formatBytes(_ bytes: Double) -> String {
    if bytes >= 1_073_741_824 { return String(format: "%.2f GB", bytes / 1_073_741_824) }
    if bytes >= 1_048_576 { return String(format: "%.1f MB", bytes / 1_048_576) }
    if bytes >= 1024 { return String(format: "%.1f KB", bytes / 1024) }
    return String(format: "%.0f B", bytes)
}

func formatBytesRate(_ bps: Double) -> String {
    return "\(formatBytes(bps))/s"
}

func formatTotalBytes(_ bytes: UInt64) -> String {
    return formatBytes(Double(bytes))
}
```

Standard binary prefix formatting (KB/MB/GB with 1024-based thresholds).

## 5. SwiftUI Views

The UI is organized in the `Views/` directory with composable components.

### SparklineView (Views/SparklineView.swift)

Draws a real-time bandwidth graph as a filled line chart:

```swift
// Views/SparklineView.swift
struct SparklineView: View {
    let data: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let maxVal = max((data.max() ?? 1), 1)
            let w = geo.size.width
            let h = geo.size.height

            if data.count > 1 {
                Path { path in
                    for (i, val) in data.enumerated() {
                        let x = w * CGFloat(i) / CGFloat(data.count - 1)
                        let y = h - (h * CGFloat(val / maxVal))
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(color, lineWidth: 1.5)

                Path { path in
                    path.move(to: CGPoint(x: 0, y: h))
                    // ... fill area under curve
                }
                .fill(color.opacity(0.15))
            }
        }
    }
}
```

### ContentView — Main Layout (Views/ContentView.swift)

The `ContentView` assembles everything into a two-column popover:

```swift
// Views/ContentView.swift (lines 253-269)
var body: some View {
    HStack(alignment: .top, spacing: 0) {
        ScrollView {
            rightColumn.padding(16)
        }
        .frame(minWidth: 440)

        Divider()

        ScrollView {
            leftColumn.padding(16)
        }
        .frame(width: 420)
    }
    .frame(width: 900, height: 700)
    .background(.background)
}
```

The layout is a fixed 900x700 `HStack` with two independently-scrollable `ScrollView` columns:

- **Right column (440pt min)** — the overview: app title, connection counts, download/upload rate cards, sparkline chart, cumulative totals, internet/LAN process breakdowns, and destination list with reverse DNS
- **Left column (420pt)** — the per-process bandwidth table with sort controls

The `ContentView` creates a single `@State private var monitor = NetworkMonitor()` — this is the sole source of truth.

### Other View Components

- **`RateCardView`** — colored download/upload boxes showing icon + label + large monospaced rate
- **`SectionHeader`** — icon + bold title, used consistently across sections
- **`ProcessRow`** — a single row in the internet/LAN process lists (colored dot + name + count)
- **`BarView`** — a tiny proportional bar (4px tall) used in per-process rows
- **`SortButton`** — clickable column header that tracks active sort key and toggles ascending/descending

## 6. Menu Bar Integration (AppDelegate.swift)

The `AppDelegate` handles AppKit-side menu bar integration:

```swift
// AppDelegate.swift
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "arrow.up.arrow.down", accessibilityDescription: "Bandwidther")
            button.action = #selector(togglePopover)
            button.target = self
        }

        let popover = NSPopover()
        popover.contentSize = NSSize(width: 900, height: 750)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: ContentView())
        self.popover = popover

        NSApp.setActivationPolicy(.accessory)
    }

    @objc func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
```

1. Creates status bar item with SF Symbol icon
2. Creates `NSPopover` with `.transient` behavior containing SwiftUI `ContentView`
3. `NSApp.setActivationPolicy(.accessory)` hides app from Dock
4. `togglePopover` shows/hides popover with keyboard focus

## 7. App Entry Point (App.swift)

```swift
// App.swift
@main
struct BandwidtherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
```

Uses `@NSApplicationDelegateAdaptor` to bridge SwiftUI's `App` protocol to the AppKit delegate. The `body` contains only an empty `Settings` scene — all UI comes through the popover.

## 8. Data Flow Summary

```
@main BandwidtherApp
  └─ AppDelegate
       └─ NSPopover ─── ContentView
                           └─ @State NetworkMonitor
                                ├── Timer (3s) → refreshNettop()
                                │     └─ Task → runNettopAsync()
                                │         └─ Process("/usr/bin/nettop")
                                │             └─ parseNettopCSVBlock() × 2
                                │                 └─ processNettopResult()
                                │                     ├─ currentRate, totalBytesIn/Out
                                │                     ├─ rateHistory (sparkline)
                                │                     └─ processBandwidths (table)
                                │
                                └── Timer (3s) → refreshConnections()
                                      └─ Task → parseConnectionsAsync()
                                          └─ Process("/usr/sbin/lsof")
                                              ├─ isLocalAddress() → IPv4/IPv6 classification
                                              └─ DNSCache.resolve() → reverse DNS
```

## 9. Key Architectural Changes

| Aspect | Original (Single File) | Refactored |
|--------|----------------------|------------|
| Observation | `@Published` + `ObservableObject` | `@Observable` macro |
| Concurrency | GCD closures | `async/await` + `Task` |
| DNS | IPv4 only | IPv4 + IPv6 |
| Connections | `netstat` + `lsof` | `lsof` only |
| Nettop | Standard | Delta mode (`-d`) |
| Structure | Single 1000-line file | 15 modular files |

## 10. Build and Run

The app compiles with a single `swiftc` invocation:

```bash
swiftc -parse-as-library -framework SwiftUI -framework AppKit -o Bandwidther *.swift Views/*.swift
./Bandwidther
```

Or use the included Makefile:

```bash
make
make run
```

The `-parse-as-library` flag is needed because the file uses `@main` rather than a top-level code entry point. No third-party dependencies, no Package.swift, no Xcode project — just Swift files and the system toolchain.
