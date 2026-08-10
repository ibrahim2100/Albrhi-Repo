#
# Albrhi for Locket.
#
# Only what is true of this app lives here; everything shared with the other
# tweaks in this repository is in shared/tweak.mk, included at the bottom.
#
ROOT := ../..

TARGET := iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = Locket
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AlbrhiLK

$(TWEAK_NAME)_FILES = $(shell find src -type f \( -iname \*.x -o -iname \*.xm -o -iname \*.m \))

# UIKit for the small status screen the two-finger hold opens; Foundation for the file
# and preference calls. No media framework: this release intercepts detection, it does
# not download anything.
$(TWEAK_NAME)_FRAMEWORKS = UIKit Foundation

# src/ on the include path, so a header is imported by the name it has rather than by
# counting ../ from wherever the importing file happens to sit. The reason is written in
# the X tweak's Makefile and in CLAUDE.md.
$(TWEAK_NAME)_CFLAGS = -Isrc

include $(ROOT)/shared/tweak.mk
