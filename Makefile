BUILDCONFIG ?= release
APPNAME     := WebAppMirror.app
BUNDLE      := $(APPNAME)

ifeq ($(BUILDCONFIG),release)
	BUILDARGS := -c release
	BUILDDIR  := .build/release
else
	BUILDDIR  := .build/debug
endif

all: $(BUNDLE)

$(BUNDLE): build
	rm -rf "$(BUNDLE)"
	mkdir -p "$(BUNDLE)/Contents/MacOS"
	mkdir -p "$(BUNDLE)/Contents/Resources"
	mkdir -p "$(BUNDLE)/Contents" && printf '<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n<plist version="1.0">\n<dict>\n\t<key>CFBundleExecutable</key>\n\t<string>WebAppMirror</string>\n\t<key>CFBundleIdentifier</key>\n\t<string>local.web-app-mirror</string>\n\t<key>CFBundleName</key>\n\t<string>WebAppMirror</string>\n\t<key>CFBundleShortVersionString</key>\n\t<string>1.0</string>\n\t<key>CFBundleVersion</key>\n\t<string>1</string>\n\t<key>LSMinimumSystemVersion</key>\n\t<string>26.0</string>\n\t<key>NSHighResolutionCapable</key>\n\t<true/>\n</dict>\n</plist>\n' > "$(BUNDLE)/Contents/Info.plist"
	cp "$(BUILDDIR)/WebAppMirror" "$(BUNDLE)/Contents/MacOS/WebAppMirror"
	codesign --force --sign - --entitlements WebAppMirror.entitlements "$(BUNDLE)"

build:
	swift build $(BUILDARGS)

clean:
	rm -rf "$(BUNDLE)"
	swift package clean

.PHONY: all clean build
