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

# MediaPlayer is here for the Download Centre's player, and only for the lock screen:
# what is playing, how far through it is, and the buttons that skip to the next one.
#
# AVKit is deliberately *not* here. AVPlayerViewController was the first player and it
# cannot be given a "next" -- there is no supported way into its transport bar -- and a
# list of saved videos you cannot move through is a file opener. The player is built on
# AVPlayerLayer instead, which is AVFoundation, already linked for the downloads.
$(TWEAK_NAME)_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore AVFoundation MediaPlayer CoreMedia Photos Network AVKit UserNotifications

include $(ROOT)/shared/tweak.mk
