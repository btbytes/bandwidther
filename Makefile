SWIFT_FILES = Models.swift Formatting.swift DNSCache.swift NettopParser.swift ConnectionParser.swift NetworkMonitor.swift AppSettings.swift App.swift AppDelegate.swift Views/BarView.swift Views/ContentView.swift Views/ProcessBandwidthRow.swift Views/ProcessRow.swift Views/RateCardView.swift Views/SectionHeader.swift Views/SettingsView.swift Views/SortButton.swift Views/SparklineView.swift
TARGET = Bandwidther
APP_BUNDLE = $(TARGET).app
APP_CONTENTS = $(APP_BUNDLE)/Contents
APP_MACOS = $(APP_CONTENTS)/MacOS
APP_RESOURCES = $(APP_CONTENTS)/Resources

VERSION := $(shell cat VERSION)
MAJOR_MINOR := $(word 1,$(subst ., ,$(VERSION))).$(word 2,$(subst ., ,$(VERSION)))
PATCH := $(word 3,$(subst ., ,$(VERSION)))

$(APP_BUNDLE): $(SWIFT_FILES)
	mkdir -p $(APP_MACOS) $(APP_RESOURCES)
	swiftc -parse-as-library -framework SwiftUI -framework AppKit -o $(APP_MACOS)/$(TARGET) $(SWIFT_FILES)
	/usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string $(TARGET)" $(APP_CONTENTS)/Info.plist
	/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string com.btbytes.bandwidther" $(APP_CONTENTS)/Info.plist
	/usr/libexec/PlistBuddy -c "Add :CFBundleName string $(TARGET)" $(APP_CONTENTS)/Info.plist
	/usr/libexec/PlistBuddy -c "Add :CFBundlePackageType string APPL" $(APP_CONTENTS)/Info.plist
	/usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $(MAJOR_MINOR)" $(APP_CONTENTS)/Info.plist
	/usr/libexec/PlistBuddy -c "Add :CFBundleVersion string $(PATCH)" $(APP_CONTENTS)/Info.plist
	/usr/libexec/PlistBuddy -c "Add :LSMinimumSystemVersion string 14.0" $(APP_CONTENTS)/Info.plist
	/usr/libexec/PlistBuddy -c "Add :NSPrincipalClass string NSApplication" $(APP_CONTENTS)/Info.plist

.PHONY: run
run: $(APP_BUNDLE)
	open $(APP_BUNDLE)

.PHONY: format
format:
	swift-format -i *.swift Views/*.swift

.PHONY: clean
clean:
	rm -rf $(APP_BUNDLE)
