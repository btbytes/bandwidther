SWIFT_FILES = $(shell find . -name '*.swift' -not -path './.build/*')
TARGET = Bandwidther

$(TARGET): $(SWIFT_FILES)
	swiftc -parse-as-library -framework SwiftUI -framework AppKit -o $@ $(SWIFT_FILES)

.PHONY:
clean:
	rm -f $(TARGET)
