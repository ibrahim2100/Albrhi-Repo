TARGET := iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = Instagram
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Albrhi

$(TWEAK_NAME)_FILES = $(shell find src -type f \( -iname \*.x -o -iname \*.xm -o -iname \*.m \)) $(wildcard modules/JGProgressHUD/*.m)
$(TWEAK_NAME)_FRAMEWORKS = UIKit Foundation CoreGraphics Photos CoreServices SystemConfiguration SafariServices Security QuartzCore AVFoundation UniformTypeIdentifiers VideoToolbox CoreMedia CoreVideo
$(TWEAK_NAME)_CFLAGS = -DDISABLE_ROOTLESS_COMPAT_WARNING -fobjc-arc -Ivendor/dav1d/include -Wno-unsupported-availability-guard -Wno-unused-value -Wno-deprecated-declarations -Wno-nullability-completeness -Wno-unused-function -Wno-incompatible-pointer-types -Wno-arc-performSelector-leaks

# dav1d decodes the AV1 ladder that iOS cannot, feeding the on-device transcoder.
# Both the rootless and roothide packages build as arm64 (build.sh changes only
# the package scheme, not ARCHS), so the arm64 slice is the only one linked; the
# arm64e archive is vendored and ready should an arm64e build ever be enabled.
$(TWEAK_NAME)_LDFLAGS = vendor/dav1d/lib/libdav1d-arm64.a
$(TWEAK_NAME)_LOGOSFLAGS = --c warnings=none

CCFLAGS += -std=c++11

include $(THEOS_MAKE_PATH)/tweak.mk

# Build FLEXing for sideloading (not building in dev-mode)
ifdef SIDELOAD
	$(TWEAK_NAME)_SUBPROJECTS += modules/flexing
endif

# A dylib that carries its own hooking, so it can be injected on its own — by
# TrollStore, a certificate, SideStore, LiveContainer, anything — without
# CydiaSubstrate having to be present alongside it.
#
# Off by default and never set for the jailbreak packages: those keep using
# Substrate exactly as they always have, and this cannot affect them.
#
# src/Compat/SCISubstrateShim.m supplies MSHookMessageEx itself. Defining it in
# our own binary means the linker resolves it internally, and -dead_strip_dylibs
# then drops the now-unreferenced CydiaSubstrate load command — which is what
# makes the result genuinely standalone rather than merely appearing to be.
# CI verifies that with otool rather than trusting it.
ifdef SELFCONTAINED
	$(TWEAK_NAME)_CFLAGS += -DSCI_SELFCONTAINED
	$(TWEAK_NAME)_LDFLAGS += -Wl,-dead_strip_dylibs
endif
