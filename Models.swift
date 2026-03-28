import Foundation

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
