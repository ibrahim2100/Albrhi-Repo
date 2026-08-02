#
# Albrhi for YouTube.
#
# Only what is true of this app lives here; everything shared with the other
# tweaks in this repository is in shared/tweak.mk, included at the bottom.
#
ROOT := ../..

TARGET := iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = YouTube
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AlbrhiYT

$(TWEAK_NAME)_FILES = $(shell find src -type f \( -iname \*.x -o -iname \*.xm -o -iname \*.m \))

# AVKit is here for the Download Centre's player and nothing else: a saved video is
# played inside the tweak rather than handed to another app, and AVPlayerViewController
# is the whole of that feature.
$(TWEAK_NAME)_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore AVFoundation AVKit CoreMedia Photos

include $(ROOT)/shared/tweak.mk
