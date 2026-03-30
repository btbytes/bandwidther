SWIFT_FILES = Models.swift Formatting.swift DNSCache.swift NettopParser.swift ConnectionParser.swift NetworkMonitor.swift AppSettings.swift App.swift AppDelegate.swift Views/BarView.swift Views/ContentView.swift Views/ProcessBandwidthRow.swift Views/ProcessRow.swift Views/RateCardView.swift Views/SectionHeader.swift Views/SettingsView.swift Views/SortButton.swift Views/SparklineView.swift
TARGET = Bandwidther

$(TARGET): $(SWIFT_FILES)
	swiftc -parse-as-library -framework SwiftUI -framework AppKit -o $@ $(SWIFT_FILES)


.PHONY:
run:
	./$(TARGET)

.PHONY:
format:
	swift-format -i *.swift Views/*.swift

.PHONY:
clean:
	rm -f $(TARGET)
