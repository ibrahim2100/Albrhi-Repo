#
# Albrhi NextUp.
#
# A port of NextUp 3 by Yves (github.com/Yves000/NextUp3), GPLv3 — the same licence
# this repository ships under, which is why the code is carried over rather than only
# read for architecture the way the unlicensed TikTok references are. See control and
# CHANGELOG.md for the attribution this obliges, and CLAUDE.md for what was changed.
#
# Only what is true of this project lives here; everything shared with the other
# tweaks in this repository is in shared/tweak.mk, included at the bottom.
#
# **Seven target processes, and they are two different jobs.** Five providers run
# inside media apps and read that app's own playback queue; the display side runs in
# SpringBoard (Lock Screen, Dynamic Island) and MediaRemoteUI (the now-playing UI that
# Control Center hosts). They talk over a LightMessaging mach service plus Darwin
# notifications, because a provider cannot draw into SpringBoard and SpringBoard cannot
# read another app's queue. Every hook is gated at runtime on the host process and the
# iOS major version, so one binary serves all seven and iOS 14.2 through 26.
#
ROOT := ../..

# 14.2 is upstream's floor and the Lock Screen hooks are written down to it. Kept
# rather than raised to this repository's usual 15.0: the version gating is runtime
# (NUIOSMajor()), so a lower deployment target costs nothing and dropping iOS 14
# support would be a regression this port has no reason to introduce.
TARGET := iphone:clang:latest:14.2
INSTALL_TARGET_PROCESSES = MediaRemoteUI Music Podcasts SpringBoard YouTubeMusic YouTube Spotify

# arm64e as well as arm64, unlike every other tweak here. This one injects into
# SpringBoard on modern devices, where the process is arm64e and an arm64-only slice is
# simply not loaded.
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AlbrhiNU

AlbrhiNU_FILES = $(shell find src -type f \( -iname \*.x -o -iname \*.xm -o -iname \*.m \))

# ImageIO for the artwork downscale; the rest is what the row and the hooks draw with.
AlbrhiNU_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore ImageIO

# LIGHTMESSAGING_TIMEOUT (ms) bounds the synchronous mach round trip. Upstream's own
# note, kept verbatim in intent because the failure it describes is severe: without it
# the display's main-thread query blocks forever against a suspended app whose runloop
# never services the port, and SpringBoard hangs until the watchdog resprings.
AlbrhiNU_CFLAGS = -Isrc -Isrc/hooks -I$(ROOT)/vendor/LightMessaging -I$(ROOT)/vendor/libSandy \
	-DLIGHTMESSAGING_USE_ROCKETBOOTSTRAP=0 -DLIGHTMESSAGING_TIMEOUT=250 \
	$(NU_PTRAUTH_CFLAGS)

# arm64e pointer authentication, probed rather than hardcoded — upstream's reasoning,
# and it describes a crash rather than a warning: clang 17 signs the class_ro pointer of
# every Objective-C class, and only libobjc from iOS 17 on authenticates that slot. An
# older runtime dereferences the signed pointer as-is and the injected process dies in
# readClass() while dyld is still mapping the tweak. A clang that rejects the flag does
# not emit the signing either, so probing is the whole test.
NU_PTRAUTH_CFLAGS := $(shell $(TARGET_CC) -x objective-c -fsyntax-only -fno-ptrauth-objc-class-ro /dev/null >/dev/null 2>&1 && echo -fno-ptrauth-objc-class-ro)
export NU_PTRAUTH_CFLAGS

include $(ROOT)/shared/tweak.mk

# The localisation bundle ships through layout/, not as a Theos subproject.
#
# NULocalization.h finds its .strings by walking up from this dylib's own path to
# <jbroot>/Library/PreferenceBundles/NUPrefs.bundle — the one lookup that resolves on
# rootful, rootless and roothide alike. Upstream shipped that bundle as its Settings
# pane; this port's settings live in Albrhi Panel instead, so what is left is 27 .lproj
# tables and an Info.plist with no executable named in it.
#
# A BUNDLE subproject was the obvious way to do that and the wrong one: it exists to
# compile and link something, and this has no sources at all. layout/ is copied into the
# package verbatim, which is exactly the job — and it drops the aggregate.mk include that
# would otherwise sit after shared/tweak.mk has already pulled in tweak.mk.
