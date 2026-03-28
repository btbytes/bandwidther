import Foundation

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
