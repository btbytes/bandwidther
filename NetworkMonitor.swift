import Foundation
import SwiftUI

@Observable
final class NetworkMonitor {
  var currentRate: BandwidthRate = .zero
  var totalBytesIn: UInt64 = 0
  var totalBytesOut: UInt64 = 0
  var nettopStatus: String?
  var connectionSummary: ConnectionSummary = ConnectionSummary()
  var dnsCache = DNSCache()
  var rateHistory: [BandwidthRate] = []
  var processBandwidths: [ProcessBandwidth] = []
  var processSortKey: ProcessSortKey {
    didSet {
      UserDefaults.standard.set(processSortKey.rawValue, forKey: "processSortKey")
      resortProcesses()
    }
  }
  var processSortAscending: Bool {
    didSet {
      UserDefaults.standard.set(processSortAscending, forKey: "processSortAscending")
      resortProcesses()
    }
  }

  @ObservationIgnored
  private nonisolated(unsafe) var connTimer: Timer?
  @ObservationIgnored
  private nonisolated(unsafe) var nettopTimer: Timer?

  init() {
    let storedKey = UserDefaults.standard.string(forKey: "processSortKey")
    processSortKey = ProcessSortKey(rawValue: storedKey ?? "") ?? .totalRate
    processSortAscending = UserDefaults.standard.object(forKey: "processSortAscending") as? Bool ?? false

    refreshConnections()
    connTimer = Timer.scheduledTimer(
      withTimeInterval: AppConstants.connectionRefreshInterval, repeats: true
    ) { [weak self] _ in
      Task { @MainActor [weak self] in
        self?.refreshConnections()
      }
    }
    refreshNettop()
    nettopTimer = Timer.scheduledTimer(
      withTimeInterval: AppConstants.nettopRefreshInterval, repeats: true
    ) { [weak self] _ in
      Task { @MainActor [weak self] in
        self?.refreshNettop()
      }
    }
  }

  deinit {
    connTimer?.invalidate()
    nettopTimer?.invalidate()
  }

  func refreshNettop() {
    Task {
      let result = await NettopParser.runAsync()
      await MainActor.run {
        processNettopResult(result)
      }
    }
  }

  private func processNettopResult(_ result: NettopResult) {
    if let errorMessage = result.errorMessage {
      nettopStatus = errorMessage
      return
    }

    var procs: [ProcessBandwidth] = []
    var sumRateIn: Double = 0
    var sumRateOut: Double = 0
    var sumTotalIn: UInt64 = 0
    var sumTotalOut: UInt64 = 0

    let allNames = Set(result.totals.keys).union(result.deltas.keys)

    for name in allNames {
      let total = result.totals[name]
      let delta = result.deltas[name]

      let rateIn = Double(delta?.bytesIn ?? 0)
      let rateOut = Double(delta?.bytesOut ?? 0)
      let totalIn = total?.bytesIn ?? 0
      let totalOut = total?.bytesOut ?? 0
      let pidCount = max(total?.pids.count ?? 0, delta?.pids.count ?? 0)

      sumRateIn += rateIn
      sumRateOut += rateOut
      sumTotalIn += totalIn
      sumTotalOut += totalOut

      if totalIn > 0 || totalOut > 0 {
        procs.append(
          ProcessBandwidth(
            id: name,
            name: name,
            bytesInPerSec: rateIn,
            bytesOutPerSec: rateOut,
            totalBytesIn: totalIn,
            totalBytesOut: totalOut,
            connections: pidCount
          ))
      }
    }

    let rate = BandwidthRate(bytesInPerSec: sumRateIn, bytesOutPerSec: sumRateOut)
    currentRate = rate
    totalBytesIn = sumTotalIn
    totalBytesOut = sumTotalOut
    nettopStatus = nil
    rateHistory.append(rate)
    if rateHistory.count > AppConstants.maxRateHistory {
      rateHistory.removeFirst()
    }

    processBandwidths = sortProcesses(procs)
  }

  func sortProcesses(_ procs: [ProcessBandwidth]) -> [ProcessBandwidth] {
    let sorted: [ProcessBandwidth]
    switch processSortKey {
    case .totalRate:
      sorted = procs.sorted { $0.totalPerSec > $1.totalPerSec }
    case .download:
      sorted = procs.sorted { $0.bytesInPerSec > $1.bytesInPerSec }
    case .upload:
      sorted = procs.sorted { $0.bytesOutPerSec > $1.bytesOutPerSec }
    case .totalBytes:
      sorted = procs.sorted { $0.totalBytes > $1.totalBytes }
    case .name:
      sorted = procs.sorted {
        $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
      }
    }
    return processSortAscending ? sorted.reversed() : sorted
  }

  func resortProcesses() {
    processBandwidths = sortProcesses(processBandwidths)
  }

  func refreshConnections() {
    Task {
      let summary = await ConnectionParser.parseAsync()
      let allDests = Array(summary.internetDestinations) + Array(summary.lanDestinations)

      await MainActor.run {
        self.connectionSummary = summary
        for dest in allDests {
          if let endpoint = ConnectionParser.parseEndpoint(dest) {
            self.dnsCache.resolve(endpoint.host)
          }
        }
      }
    }
  }

  func parseDestinationString(_ destination: String) -> NetworkEndpoint? {
    ConnectionParser.parseEndpoint(destination)
  }
}
