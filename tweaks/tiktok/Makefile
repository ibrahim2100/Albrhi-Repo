#
# Albrhi for TikTok.
#
# Only what is true of this app lives here; everything shared with the other
# tweaks in this repository is in shared/tweak.mk, included at the bottom.
#
ROOT := ../..

TARGET := iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = TikTok
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AlbrhiTT

$(TWEAK_NAME)_FILES = $(shell find src -type f \( -iname \*.x -o -iname \*.xm -o -iname \*.m \))

# Photos for a saved video; AVFoundation is not linked yet because nothing here plays or
# probes a stream -- add it the day a feature actually needs one, not before.
$(TWEAK_NAME)_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore Photos

# src/ on the include path, so a header is imported by the name it has rather than by
# counting ../ from wherever the importing file happens to sit. See CLAUDE.md for what
# counting cost the other tweaks.
$(TWEAK_NAME)_CFLAGS = -Isrc

include $(ROOT)/shared/tweak.mk
