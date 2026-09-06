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

#
# **NOHOOKS: the same dylib with every hook compiled out, for one question.**
#
#   make NOHOOKS=1
#
# A device reports the app hanging on its logo. The trail says our constructor entered, read a
# preference, passed the gate and finished -- and then no hook of ours fired at all before the
# guard gave up eight seconds later. That leaves two possibilities that no amount of reading can
# separate: a hook whose *installation* changes the app, or the mere presence of this dylib --
# its `+load`s, its licence code, the frameworks it links.
#
# This build answers it. Every `.x` is left out -- `src/Features` and `src/Tweak.x` alike -- and a
# small constructor of its own takes their place, so what loads is the launch guard, the trail and
# the diagnostics and **not one hook**. If the app launches with it, the fault is a hook; if it
# still hangs, no hook was ever the fault.
#
# The `.x` files have to go rather than be `#if`-ed out: **Logos runs before the preprocessor**, so
# a `#if` hides a `%hook` from the compiler and not from Logos, which still emits the code that
# installs it -- and the build then fails on symbols for methods that were never compiled.
#
ifdef NOHOOKS
$(TWEAK_NAME)_FILES = nohooks/SCIYTNoHooks.m src/SCIYTLaunchGuard.m \
	src/Diagnostics/SCIYTDiagnostics.m src/Localization/SCILocalize.m
# Named one by one rather than found: the settings pages reference the feature classes this build
# leaves out, so a `find` that keeps them links against classes that are not there. What is left is
# the guard, the trail, the report and the strings it prints -- which is the whole of what this
# build has to be able to do.
$(TWEAK_NAME)_CFLAGS += -DSCI_NOHOOKS=1
else
$(TWEAK_NAME)_FILES = $(shell find src -type f \( -iname \*.x -o -iname \*.xm -o -iname \*.m \) )
endif

# MediaPlayer is here for the Download Centre's player, and only for the lock screen:
# what is playing, how far through it is, and the buttons that skip to the next one.
#
# AVKit is deliberately *not* here. AVPlayerViewController was the first player and it
# cannot be given a "next" -- there is no supported way into its transport bar -- and a
# list of saved videos you cannot move through is a file opener. The player is built on
# AVPlayerLayer instead, which is AVFoundation, already linked for the downloads.
$(TWEAK_NAME)_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore AVFoundation MediaPlayer CoreMedia Photos Network AVKit UserNotifications

include $(ROOT)/shared/tweak.mk
