import SwiftUI

struct ProcessBandwidthRow: View {
    let proc: ProcessBandwidth
    let maxRate: Double

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(proc.name)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .lineLimit(1)
                Spacer()
                Text(formatBytesRate(proc.totalPerSec))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(proc.totalPerSec > 0 ? .primary : .secondary)
            }
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 8))
                        .foregroundColor(.blue)
                    Text(formatBytesRate(proc.bytesInPerSec))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.blue)
                }
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 8))
                        .foregroundColor(.orange)
                    Text(formatBytesRate(proc.bytesOutPerSec))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.orange)
                }
                Spacer()
                if proc.connections > 1 {
                    Text("\(proc.connections) pids")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                Text(formatTotalBytes(proc.totalBytes))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            if maxRate > 0 {
                HStack(spacing: 2) {
                    BarView(fraction: proc.bytesInPerSec / maxRate, color: .blue)
                    BarView(fraction: proc.bytesOutPerSec / maxRate, color: .orange)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
