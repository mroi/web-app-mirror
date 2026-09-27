CONFIG ?= release
BUNDLE = WebAppMirror.app

ifeq ($(CONFIG),release)
	BUILDARGS = -c release
	BUILDDIR = .build/release
else
	BUILDDIR = .build/debug
endif

.PHONY: all build clean

all: $(BUNDLE)

$(BUNDLE): build WebAppMirror.plist WebAppMirror.entitlements
	rm -rf "$(BUNDLE)"
	mkdir -p "$(BUNDLE)/Contents/MacOS"
	mkdir -p "$(BUNDLE)/Contents/Resources"
	cp "$(BUILDDIR)/WebAppMirror" "$(BUNDLE)/Contents/MacOS/WebAppMirror"
	cp WebAppMirror.plist "$(BUNDLE)/Contents/Info.plist"
	codesign --force --sign - --entitlements WebAppMirror.entitlements "$(BUNDLE)"

build:
	swift build $(BUILDARGS)

clean:
	rm -rf "$(BUNDLE)"
	swift package clean
