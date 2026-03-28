import SwiftUI

struct ContentView: View {
    @State private var monitor = NetworkMonitor()

    var leftColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionHeader(title: "Per-Process Bandwidth", icon: "cpu")
                Spacer()
                Text("\(monitor.processBandwidths.count) processes")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 12) {
                Text("Sort:")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                ForEach(ProcessSortKey.allCases, id: \.self) { key in
                    SortButton(
                        label: key.rawValue,
                        key: key,
                        currentKey: $monitor.processSortKey,
                        ascending: $monitor.processSortAscending,
                        action: { monitor.resortProcesses() }
                    )
                }
            }

            let maxRate = monitor.processBandwidths.map { $0.totalPerSec }.max() ?? 1.0

            if monitor.processBandwidths.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Sampling network traffic...")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 20)
                    Spacer()
                }
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(monitor.processBandwidths) { proc in
                        ProcessBandwidthRow(proc: proc, maxRate: maxRate)
                        Divider()
                    }
                }
            }
        }
        .padding(10)
        .background(Color.primary.opacity(0.03))
        .cornerRadius(8)
    }

    var rightColumn: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bandwidther")
                        .font(.system(size: 20, weight: .bold))
                    if let status = monitor.nettopStatus {
                        Text("Nettop unavailable: \(status)")
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                            .lineLimit(2)
                    } else {
                        Text("All interfaces (via nettop delta mode)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    let total = monitor.connectionSummary.internetCount + monitor.connectionSummary.lanCount
                    Text("\(total) connections")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    HStack(spacing: 8) {
                        HStack(spacing: 3) {
                            Circle().fill(.blue).frame(width: 6, height: 6)
                            Text("\(monitor.connectionSummary.internetCount) internet")
                                .font(.system(size: 11))
                        }
                        HStack(spacing: 3) {
                            Circle().fill(.green).frame(width: 6, height: 6)
                            Text("\(monitor.connectionSummary.lanCount) LAN")
                                .font(.system(size: 11))
                        }
                    }
                    .foregroundColor(.secondary)
                }
            }

            HStack(spacing: 10) {
                RateCardView(
                    title: "DOWNLOAD",
                    rate: formatBytesRate(monitor.currentRate.bytesInPerSec),
                    icon: "arrow.down.circle.fill",
                    color: .blue
                )
                RateCardView(
                    title: "UPLOAD",
                    rate: formatBytesRate(monitor.currentRate.bytesOutPerSec),
                    icon: "arrow.up.circle.fill",
                    color: .orange
                )
            }

            VStack(alignment: .leading, spacing: 6) {
                SectionHeader(title: "Bandwidth (last 60s)", icon: "chart.xyaxis.line")

                ZStack(alignment: .topTrailing) {
                    SparklineView(
                        data: monitor.rateHistory.map { $0.bytesInPerSec },
                        color: .blue
                    )

                    SparklineView(
                        data: monitor.rateHistory.map { $0.bytesOutPerSec },
                        color: .orange
                    )

                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 1).fill(.blue).frame(width: 12, height: 2)
                            Text("In").font(.system(size: 9)).foregroundColor(.secondary)
                        }
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 1).fill(.orange).frame(width: 12, height: 2)
                            Text("Out").font(.system(size: 9)).foregroundColor(.secondary)
                        }
                    }
                    .padding(4)
                    .background(.ultraThinMaterial)
                    .cornerRadius(4)
                }
                .frame(height: 80)
                .padding(8)
                .background(Color.primary.opacity(0.03))
                .cornerRadius(8)
            }

            VStack(alignment: .leading, spacing: 6) {
                SectionHeader(title: "Cumulative Total", icon: "clock.arrow.circlepath")
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 10))
                            .foregroundColor(.blue)
                        Text(formatTotalBytes(monitor.totalBytesIn))
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                        Text(formatTotalBytes(monitor.totalBytesOut))
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                    }
                }
                .padding(8)
                .background(Color.primary.opacity(0.03))
                .cornerRadius(8)
            }

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    SectionHeader(title: "Internet", icon: "globe")
                    if monitor.connectionSummary.internetProcesses.isEmpty {
                        Text("No connections")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .padding(.vertical, 4)
                    } else {
                        let sorted = monitor.connectionSummary.internetProcesses.sorted { $0.value > $1.value }
                        ForEach(sorted, id: \.key) { proc, count in
                            ProcessRow(name: proc, count: count, color: .blue)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color.blue.opacity(0.04))
                .cornerRadius(8)

                VStack(alignment: .leading, spacing: 6) {
                    SectionHeader(title: "LAN / Local", icon: "network")
                    if monitor.connectionSummary.lanProcesses.isEmpty {
                        Text("No connections")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .padding(.vertical, 4)
                    } else {
                        let sorted = monitor.connectionSummary.lanProcesses.sorted { $0.value > $1.value }
                        ForEach(sorted, id: \.key) { proc, count in
                            ProcessRow(name: proc, count: count, color: .green)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color.green.opacity(0.04))
                .cornerRadius(8)
            }

            VStack(alignment: .leading, spacing: 6) {
                SectionHeader(title: "Internet Destinations", icon: "mappin.and.ellipse")

                let dests = Array(Set(monitor.connectionSummary.internetDestinations)).sorted().prefix(20)
                if dests.isEmpty {
                    Text("None")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                } else {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(dests), id: \.self) { dest in
                            if let endpoint = monitor.parseDestinationString(dest) {
                                let hostname = monitor.dnsCache.hostname(for: endpoint.host)
                                VStack(alignment: .leading, spacing: 1) {
                                    if let hostname = hostname {
                                        Text("\(hostname):\(endpoint.port)")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                    }
                                    Text(dest)
                                        .font(.system(size: hostname != nil ? 10 : 11, design: .monospaced))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            } else {
                                Text(dest)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
            .padding(10)
            .background(Color.primary.opacity(0.03))
            .cornerRadius(8)
        }
    }

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
}

class ContentHostingController: NSHostingController<ContentView> {
    init() {
        super.init(rootView: ContentView())
    }
    @objc required dynamic init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
