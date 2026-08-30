#
# Albrhi for Twitter / X.
#
# Only what is true of this app lives here; everything shared with the other
# tweaks in this repository is in shared/tweak.mk, included at the bottom.
#
ROOT := ../..

TARGET := iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = Twitter
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AlbrhiTW

$(TWEAK_NAME)_FILES = $(shell find src -type f \( -iname \*.x -o -iname \*.xm -o -iname \*.m \))

# Photos is here for saving a download, and nothing else. There is still no player and
# no encoder in this tweak: X hands out finished MP4 files, so a download is a fetch and
# a write, and AVFoundation would be linked for code that does not exist.
$(TWEAK_NAME)_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore Photos SafariServices LocalAuthentication

# src/ on the include path, so a header is imported by the name it has rather than by
# counting ../ from wherever the importing file happens to sit. The other two tweaks
# count, and CLAUDE.md already records what that cost when their sources moved a level
# deeper -- four files broke at once and nothing but the compiler noticed.
$(TWEAK_NAME)_CFLAGS = -Isrc

include $(ROOT)/shared/tweak.mk
