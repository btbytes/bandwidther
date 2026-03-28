import Foundation
import SwiftUI

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

  deinit {
    connTimer?.invalidate()
    nettopTimer?.invalidate()
  }

  func refreshNettop() {
    Task {
      let result = await runNettopAsync()
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
    if rateHistory.count > maxHistory {
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
      let summary = await parseConnectionsAsync()
      let allDests = summary.internetDestinations + summary.lanDestinations

      await MainActor.run {
        self.connectionSummary = summary
        for dest in allDests {
          if let endpoint = self.parseDestinationString(dest) {
            self.dnsCache.resolve(endpoint.host)
          }
        }
      }
    }
  }

  private func parseConnectionsAsync() async -> ConnectionSummary {
    var summary = ConnectionSummary()

    let pipe = Pipe()
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
    process.arguments = ["-n", "-P", "-iTCP"]
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice

    do { try process.run() } catch { return summary }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()

    guard let output = String(data: data, encoding: .utf8) else { return summary }

    for line in output.split(separator: "\n") {
      let cols = line.split(separator: " ", omittingEmptySubsequences: true)
      guard cols.count >= 10 else { continue }
      let stateToken = String(cols.last ?? "")
      guard stateToken.hasPrefix("("), stateToken.hasSuffix(")") else { continue }

      let state = String(stateToken.dropFirst().dropLast())
      guard state == "ESTABLISHED" || state == "SYN_SENT" || state == "CLOSE_WAIT" else { continue }

      let procName = String(cols[0])
      guard let connField = cols.dropLast().last(where: { $0.contains("->") }) else { continue }
      guard let remote = parseRemoteEndpoint(from: String(connField)) else { continue }

      if isLocalAddress(remote.host) {
        summary.lanCount += 1
        summary.lanDestinations.append(remote.displayString)
        summary.lanProcesses[procName, default: 0] += 1
      } else {
        summary.internetCount += 1
        summary.internetDestinations.append(remote.displayString)
        summary.internetProcesses[procName, default: 0] += 1
      }
    }

    return summary
  }

  private func parseRemoteEndpoint(from connection: String) -> NetworkEndpoint? {
    let parts = connection.split(separator: ">", maxSplits: 1).map(String.init)
    guard parts.count == 2 else { return nil }
    return parseEndpoint(parts[1])
  }

  func parseDestinationString(_ destination: String) -> NetworkEndpoint? {
    parseEndpoint(destination)
  }

  private func parseEndpoint(_ endpoint: String) -> NetworkEndpoint? {
    let trimmed = endpoint.trimmingCharacters(in: .whitespaces)
    if trimmed.hasPrefix("["),
      let closeBracket = trimmed.firstIndex(of: "]"),
      let colon = trimmed[closeBracket...].firstIndex(of: ":")
    {
      let host = String(trimmed[trimmed.index(after: trimmed.startIndex)..<closeBracket])
      let port = String(trimmed[trimmed.index(after: colon)...])
      guard !host.isEmpty, !port.isEmpty else { return nil }
      return NetworkEndpoint(host: host, port: port)
    }

    guard let colon = trimmed.lastIndex(of: ":") else { return nil }
    let host = String(trimmed[..<colon])
    let port = String(trimmed[trimmed.index(after: colon)...])
    guard !host.isEmpty, !port.isEmpty else { return nil }
    return NetworkEndpoint(host: host, port: port)
  }

  private func isLocalAddress(_ host: String) -> Bool {
    if host == "localhost" || host == "::1" { return true }
    if host.hasPrefix("fe80:") || host.hasPrefix("FE80:") { return true }
    if host.hasPrefix("fc") || host.hasPrefix("FC") || host.hasPrefix("fd") || host.hasPrefix("FD")
    {
      return true
    }

    if host.hasPrefix("10.") || host.hasPrefix("127.") || host.hasPrefix("169.254.") { return true }
    if host.hasPrefix("192.168.") { return true }
    if host.hasPrefix("172.") {
      let parts = host.split(separator: ".")
      if parts.count >= 2, let second = Int(parts[1]), (16...31).contains(second) { return true }
    }
    return false
  }
}

private func parseNettopCSVBlock(_ lines: [String]) -> [String: NettopProcessData] {
  var result: [String: NettopProcessData] = [:]
  for line in lines {
    let cols = line.split(separator: ",", omittingEmptySubsequences: false).map {
      String($0).trimmingCharacters(in: .whitespaces)
    }
    guard cols.count >= 3 else { continue }
    let nameField = cols[0]
    if nameField.isEmpty || nameField.hasPrefix("time") { continue }

    guard let bytesIn = UInt64(cols[1]), let bytesOut = UInt64(cols[2]) else { continue }

    var procName = nameField
    var pid = ""
    if let dotRange = nameField.range(of: ".", options: .backwards) {
      let suffix = String(nameField[dotRange.upperBound...])
      if Int(suffix) != nil {
        procName = String(nameField[nameField.startIndex..<dotRange.lowerBound])
        pid = suffix
      }
    }
    if procName.isEmpty { continue }

    var existing = result[procName] ?? NettopProcessData()
    existing.bytesIn += bytesIn
    existing.bytesOut += bytesOut
    if !pid.isEmpty { existing.pids.insert(pid) }
    result[procName] = existing
  }
  return result
}

private func runNettopAsync() async -> NettopResult {
  let pipe = Pipe()
  let errorPipe = Pipe()
  let proc = Process()
  proc.executableURL = URL(fileURLWithPath: "/usr/bin/nettop")
  proc.arguments = ["-d", "-P", "-L", "2", "-s", "1", "-x", "-n", "-J", "bytes_in,bytes_out"]
  proc.standardOutput = pipe
  proc.standardError = errorPipe

  do { try proc.run() } catch {
    return NettopResult(errorMessage: "Failed to start nettop: \(error.localizedDescription)")
  }
  let data = pipe.fileHandleForReading.readDataToEndOfFile()
  let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
  proc.waitUntilExit()

  let stderr =
    String(data: errorData, encoding: .utf8)?
    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
  guard proc.terminationStatus == 0 else {
    let detail = stderr.isEmpty ? "nettop exited with status \(proc.terminationStatus)" : stderr
    return NettopResult(errorMessage: detail)
  }

  guard let output = String(data: data, encoding: .utf8), !output.isEmpty else {
    let detail = stderr.isEmpty ? "nettop returned no output" : stderr
    return NettopResult(errorMessage: detail)
  }

  let allLines = output.split(separator: "\n", omittingEmptySubsequences: false).map { String($0) }

  var blocks: [[String]] = []
  var current: [String] = []
  for line in allLines {
    if line.hasPrefix(",bytes_in") {
      if !current.isEmpty { blocks.append(current) }
      current = []
    } else {
      current.append(line)
    }
  }
  if !current.isEmpty { blocks.append(current) }

  guard blocks.count >= 2 else {
    return NettopResult(errorMessage: "nettop did not return a baseline and delta sample")
  }

  var result = NettopResult()
  if blocks.count >= 1 { result.totals = parseNettopCSVBlock(blocks[0]) }
  if blocks.count >= 2 { result.deltas = parseNettopCSVBlock(blocks[1]) }
  return result
}
