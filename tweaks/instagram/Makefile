#
# Albrhi for Instagram.
#
# Only what is true of this app lives here; everything shared with the other
# tweaks in this repository is in shared/tweak.mk, included at the bottom.
#
ROOT := ../..

TARGET := iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = Instagram
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Albrhi

$(TWEAK_NAME)_FILES = $(shell find src -type f \( -iname \*.x -o -iname \*.xm -o -iname \*.m \))
$(TWEAK_NAME)_FRAMEWORKS = UIKit Foundation CoreGraphics Photos CoreServices SystemConfiguration SafariServices Security QuartzCore AVFoundation UniformTypeIdentifiers VideoToolbox CoreMedia CoreVideo
$(TWEAK_NAME)_CFLAGS = -I$(ROOT)/vendor/dav1d/include

# dav1d decodes the AV1 ladder that iOS cannot, feeding the on-device transcoder.
# Both the rootless and roothide packages build as arm64 (build.sh changes only
# the package scheme, not ARCHS), so the arm64 slice is the only one linked; the
# arm64e archive is vendored and ready should an arm64e build ever be enabled.
#
# Instagram's alone: no other tweak here needs an AV1 decoder.
$(TWEAK_NAME)_LDFLAGS = $(ROOT)/vendor/dav1d/lib/libdav1d-arm64.a

include $(ROOT)/shared/tweak.mk
