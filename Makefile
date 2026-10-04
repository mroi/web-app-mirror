CONFIG ?= release
BUNDLE = WebAppMirror.app

ifeq ($(CONFIG),release)
	BUILDARGS = -c release
	BUILDDIR = .build/release
else
	BUILDDIR = .build/debug
endif

.PHONY: all build run clean

all: $(BUNDLE)

$(BUNDLE): %.app: build %.plist %.entitlements
	rm -rf "$(BUNDLE)"
	mkdir -p "$(BUNDLE)/Contents/MacOS"
	mkdir -p "$(BUNDLE)/Contents/Resources"
	cp "$(BUILDDIR)/$*" "$(BUNDLE)/Contents/MacOS/"
	cp "$(BUILDDIR)/$*_$*.bundle/Contents/Resources"/* "$(BUNDLE)/Contents/Resources/"
	cp "$*.plist" "$(BUNDLE)/Contents/Info.plist"
	codesign --force --sign - --entitlements "$*.entitlements" "$(BUNDLE)"

build:
	swift build $(BUILDARGS)

run:
	open "$(BUNDLE)"

clean:
	rm -rf "$(BUNDLE)"
	swift package clean
