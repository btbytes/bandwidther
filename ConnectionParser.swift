import Foundation

struct ConnectionParser {
  static func parseAsync() async -> ConnectionSummary {
    var summary = ConnectionSummary()

    let pipe = Pipe()
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
    process.arguments = ["-n", "-P", "-iTCP", "-iUDP"]
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice

    do { try process.run() } catch { return summary }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()

    guard let output = String(data: data, encoding: .utf8) else { return summary }

    var isFirstLine = true
    for line in output.split(separator: "\n") {
      if isFirstLine {
        isFirstLine = false
        continue
      }

      let cols = line.split(whereSeparator: { $0.isWhitespace }).map(String.init)
      guard cols.count >= 9 else { continue }

      let procName = cols[0]
      let nameFieldIndex = cols.firstIndex(where: { $0.contains("->") })

      guard let connFieldIndex = nameFieldIndex else { continue }
      let connField = cols[connFieldIndex]

      guard let remote = parseRemoteEndpoint(from: connField) else { continue }

      let stateIndex = cols.firstIndex(where: {
        $0.hasPrefix("(") && $0.hasSuffix(")")
      })

      if let stateIndex = stateIndex {
        let state = cols[stateIndex].dropFirst().dropLast()
        guard state == "ESTABLISHED" || state == "SYN_SENT" || state == "CLOSE_WAIT" else { continue }
      }

      if isLocalAddress(remote.host) {
        summary.lanCount += 1
        summary.lanDestinations.insert(remote.displayString)
        summary.lanProcesses[procName, default: 0] += 1
      } else {
        summary.internetCount += 1
        summary.internetDestinations.insert(remote.displayString)
        summary.internetProcesses[procName, default: 0] += 1
      }
    }

    return summary
  }

  private static func parseRemoteEndpoint(from connection: String) -> NetworkEndpoint? {
    let parts = connection.split(separator: ">", maxSplits: 1).map(String.init)
    guard parts.count == 2 else { return nil }
    return parseEndpoint(parts[1])
  }

  static func parseEndpoint(_ endpoint: String) -> NetworkEndpoint? {
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

  static func isLocalAddress(_ host: String) -> Bool {
    if host == "localhost" || host == "::1" { return true }
    if host.hasPrefix("fe80:") || host.hasPrefix("FE80:") { return true }
    if host.hasPrefix("fc") || host.hasPrefix("FC") || host.hasPrefix("fd") || host.hasPrefix("FD") {
      return true
    }
    if host.hasPrefix("10.") || host.hasPrefix("127.") || host.hasPrefix("169.254.") { return true }
    if host.hasPrefix("192.168.") { return true }
    if host.hasPrefix("100.64.") || host.hasPrefix("100.65.") ||
       host.hasPrefix("100.66.") || host.hasPrefix("100.67.") ||
       host.hasPrefix("100.68.") || host.hasPrefix("100.69.") ||
       host.hasPrefix("100.70.") || host.hasPrefix("100.71.") ||
       host.hasPrefix("100.72.") || host.hasPrefix("100.73.") ||
       host.hasPrefix("100.74.") || host.hasPrefix("100.75.") ||
       host.hasPrefix("100.76.") || host.hasPrefix("100.77.") ||
       host.hasPrefix("100.78.") || host.hasPrefix("100.79.") ||
       host.hasPrefix("100.80.") || host.hasPrefix("100.81.") ||
       host.hasPrefix("100.82.") || host.hasPrefix("100.83.") ||
       host.hasPrefix("100.84.") || host.hasPrefix("100.85.") ||
       host.hasPrefix("100.86.") || host.hasPrefix("100.87.") ||
       host.hasPrefix("100.88.") || host.hasPrefix("100.89.") ||
       host.hasPrefix("100.90.") || host.hasPrefix("100.91.") ||
       host.hasPrefix("100.92.") || host.hasPrefix("100.93.") ||
       host.hasPrefix("100.94.") || host.hasPrefix("100.95.") ||
       host.hasPrefix("100.96.") || host.hasPrefix("100.97.") ||
       host.hasPrefix("100.98.") || host.hasPrefix("100.99.") ||
       host.hasPrefix("100.100.") || host.hasPrefix("100.101.") ||
       host.hasPrefix("100.102.") || host.hasPrefix("100.103.") ||
       host.hasPrefix("100.104.") || host.hasPrefix("100.105.") ||
       host.hasPrefix("100.106.") || host.hasPrefix("100.107.") ||
       host.hasPrefix("100.108.") || host.hasPrefix("100.109.") ||
       host.hasPrefix("100.110.") || host.hasPrefix("100.111.") ||
       host.hasPrefix("100.112.") || host.hasPrefix("100.113.") ||
       host.hasPrefix("100.114.") || host.hasPrefix("100.115.") ||
       host.hasPrefix("100.116.") || host.hasPrefix("100.117.") ||
       host.hasPrefix("100.118.") || host.hasPrefix("100.119.") ||
       host.hasPrefix("100.120.") || host.hasPrefix("100.121.") ||
       host.hasPrefix("100.122.") || host.hasPrefix("100.123.") ||
       host.hasPrefix("100.124.") || host.hasPrefix("100.125.") ||
       host.hasPrefix("100.126.") || host.hasPrefix("100.127.") {
      return true
    }
    if host.hasPrefix("198.18.") || host.hasPrefix("198.19.") { return true }
    if host.hasPrefix("172.") {
      let parts = host.split(separator: ".")
      if parts.count >= 2, let second = Int(parts[1]), (16...31).contains(second) { return true }
    }
    return false
  }
}
