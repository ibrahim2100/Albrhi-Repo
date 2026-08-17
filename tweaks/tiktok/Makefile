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

# Photos for a saved video; AVFoundation to read a downloaded file's own track list,
# which is the only reliable way to tell a video from an audio-only file -- an
# extension on the URL and the response's own MIME type were both tried first and both
# were wrong on a real device.
$(TWEAK_NAME)_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore Photos AVFoundation

# src/ on the include path, so a header is imported by the name it has rather than by
# counting ../ from wherever the importing file happens to sit. See CLAUDE.md for what
# counting cost the other tweaks.
$(TWEAK_NAME)_CFLAGS = -Isrc

include $(ROOT)/shared/tweak.mk
