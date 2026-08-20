#
# Albrhi for Spotify.
#
# **The ad blocking is carried over from EeveeSpotify** (github.com/SideloadLabs/
# EeveeSpotifyReincarnated), GPLv3 -- the same licence this repository ships under, which is
# what makes carrying code over lawful here, exactly as it was for Albrhi NextUp. The notice
# ships inside the package as layout/Library/Albrhi/Spotify/LICENSE-eevee, and control and
# CHANGELOG.md carry the attribution. It does not come out.
#
# **What was deliberately not carried over is the Premium unlock.** That tweak's own
# description offers a paid subscription for free; this project refused the same thing once
# already, by name, when Locket's Check0verPlus was reviewed and left alone. The three files
# here block advertising and never ask what the account is -- which is how they were written
# upstream, and the reason they could be taken without the rest.
#
ROOT := ../..

# 15.0: below that the Orion runtime this tweak depends on is not worth supporting, and
# Spotify itself has moved on.
TARGET := iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = Spotify

ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AlbrhiSpotify

AlbrhiSpotify_FILES = $(shell find src -type f \( -iname \*.swift -o -iname \*.x -o -iname \*.m \))

AlbrhiSpotify_CFLAGS = -fobjc-arc -I$(ROOT) -Isrc \
	-DDISABLE_ROOTLESS_COMPAT_WARNING \
	-Wno-deprecated-declarations -Wno-nullability-completeness -Wno-unused-function

# The bridging header is how the Swift side reaches SCIVersionString and SCILocalized: Theos
# compiles the .m alongside the .swift files, but Swift needs the declarations imported by hand.
AlbrhiSpotify_SWIFTFLAGS = -Osize -import-objc-header src/Localization/SCILocalize.h \
	-Xfrontend -runtime-compatibility-version -Xfrontend none

#
# **`-runtime-compatibility-version none` is not an optimisation; without it this does not link.**
#
# Swift emits a force-load reference to `swiftCompatibility56` when the deployment target is old
# enough to need the back-deployment shims, and that library is not in the iPhoneOS 16.2 SDK this
# repository pins -- so the link fails on an undefined symbol in a file that compiled perfectly.
# The shims exist for Swift-runtime features on OS versions older than this tweak supports at all,
# so declining them costs nothing here and is the difference between a build and a wall of
# `ld: symbol(s) not found`.
#

#
# **`-D ROOTHIDE` is not a packaging detail — it selects a different code path, and its absence
# crashed Spotify.**
#
# The ported ad blocker has two branches. Under `ROOTHIDE` it activates one small hook group per
# target class, each guarded by that class *and* the method it hooks being present. Without the
# define it takes the other branch: **one group covering all five hooks, activated when any single
# target class is found** -- so a build of Spotify missing two of the five is hooked for classes it
# does not have, and Orion does not fail politely.
#
# This port built for the roothide scheme and never defined the flag, so a roothide device silently
# took the branch written for everything else. Upstream's own makefile sets it, which is where this
# was finally read from after the crash survived a fix aimed at the wrong group.
#
# **A conditional compiled out is not a conditional you can see**, and this is the second thing in
# this tweak that compiled, linked, installed and behaved as though a decision had been made
# somewhere else. Worth checking for any ported file the moment a build flag appears in its
# `#if`s -- there is no warning for taking the wrong one.
#
# NOTE: no tab in column one anywhere below. Make reads the first character before expanding
# anything, and a tab there is an attempted recipe -- which cost this repository a build once.
#
ifeq ($(THEOS_PACKAGE_SCHEME),roothide)
AlbrhiSpotify_SWIFTFLAGS += -D ROOTHIDE
AlbrhiSpotify_LDFLAGS += -Xlinker -rpath -Xlinker @loader_path/.jbroot/Library/Frameworks
endif

AlbrhiSpotify_FRAMEWORKS = Foundation UIKit

#
# **shared/tweak.mk is deliberately not included**, the same decision Albrhi NextUp and Albrhi
# Watch made: it appends the whole JGProgressHUD module to every tweak that includes it, and
# this one draws nothing of its own inside Spotify. Its interface is a page in Albrhi Panel.
#
include $(THEOS_MAKE_PATH)/tweak.mk
