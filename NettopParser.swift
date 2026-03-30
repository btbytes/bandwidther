import Foundation

struct NettopParser {
  static func parseCSVBlock(_ lines: [String]) -> [String: NettopProcessData] {
    var result: [String: NettopProcessData] = [:]

    for line in lines {
      let fields = parseCSVLine(line)
      guard fields.count >= 3 else { continue }

      let nameField = fields[0].trimmingCharacters(in: .whitespaces)
      if nameField.isEmpty || nameField.hasPrefix("time") { continue }

      let bytesInStr = fields[1].trimmingCharacters(in: .whitespaces)
      let bytesOutStr = fields[2].trimmingCharacters(in: .whitespaces)
      guard let bytesIn = UInt64(bytesInStr), let bytesOut = UInt64(bytesOutStr) else { continue }

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

  private static func parseCSVLine(_ line: String) -> [String] {
    var fields: [String] = []
    var current = ""
    var inQuotes = false

    for char in line {
      switch char {
      case "\"" where inQuotes:
        inQuotes = false
      case "\"" where !inQuotes:
        inQuotes = true
      case "," where !inQuotes:
        fields.append(current)
        current = ""
      default:
        current.append(char)
      }
    }
    fields.append(current)
    return fields
  }

  static func runAsync() async -> NettopResult {
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

    return await withCheckedContinuation { continuation in
      DispatchQueue.global(qos: .utility).async {
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()

        let stderr =
          String(data: errorData, encoding: .utf8)?
          .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard proc.terminationStatus == 0 else {
          let detail = stderr.isEmpty ? "nettop exited with status \(proc.terminationStatus)" : stderr
          continuation.resume(returning: NettopResult(errorMessage: detail))
          return
        }

        guard let output = String(data: data, encoding: .utf8), !output.isEmpty else {
          let detail = stderr.isEmpty ? "nettop returned no output" : stderr
          continuation.resume(returning: NettopResult(errorMessage: detail))
          return
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
          continuation.resume(returning: NettopResult(errorMessage: "nettop did not return a baseline and delta sample"))
          return
        }

        var result = NettopResult()
        result.totals = Self.parseCSVBlock(blocks[0])
        result.deltas = Self.parseCSVBlock(blocks[1])
        continuation.resume(returning: result)
      }
    }
  }
}
