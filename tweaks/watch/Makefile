#
# Albrhi Watch.
#
# The pairing core is `watched` by 34306 (github.com/34306/watched), MIT, carried over as
# code rather than read for architecture -- MIT permits exactly that, and the licence text
# ships beside this file as LICENSE-watched. See control and CHANGELOG.md for the
# attribution that obliges, and CLAUDE.md for what this port changed.
#
# **One process today, and the filter is where that is decided.** Pairing is answered
# inside SpringBoard; the photo, music, maps and companion-app subsystems live in their own
# apps and each needs its own confirmed hook before its bundle id is added to
# AlbrhiWatch.plist. A filter that lists a process the tweak has nothing to say to is a
# dylib loaded into that process for nothing.
#
ROOT := ../..

# 15.0, matching the pairing core's own floor. Every hook is chosen at runtime from the
# class list, so a device older than the classes simply installs nothing.
TARGET := iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = SpringBoard

# arm64e as well as arm64: this loads into SpringBoard, which is arm64e on every modern
# device, and an arm64-only slice is simply not loaded there.
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AlbrhiWatch

# src/Settings is the preference bundle's, not the dylib's -- it is a PSListController and
# links against Preferences, which SpringBoard's injected dylib has no business pulling in.
# Pruned here and named by the subproject below, so one file belongs to exactly one binary.
AlbrhiWatch_FILES = $(shell find src -type f -not -path 'src/Settings/*' \( -iname \*.x -o -iname \*.xm -o -iname \*.m \))

AlbrhiWatch_CFLAGS = -fobjc-arc -I$(ROOT) -Isrc \
	-DDISABLE_ROOTLESS_COMPAT_WARNING \
	-Wno-deprecated-declarations -Wno-nullability-completeness -Wno-unused-function

AlbrhiWatch_FRAMEWORKS = Foundation UIKit Security

#
# **shared/tweak.mk is deliberately not included, the same decision Albrhi NextUp made.**
#
# It appends the whole JGProgressHUD module to every tweak that includes it, and this one
# draws nothing: it answers compatibility questions inside SpringBoard and shows its
# interface in Settings. Twelve source files of a HUD library compiled into SpringBoard
# because an include is the habit is exactly what that decision was about.
#
# **SCIPanelGate is not compiled in either, and that is a fix rather than a saving.** It asks
# whether `app_enabled_<bundleid>` is set, the panel only ever sets that from an app's own row,
# and this tweak is collapsed into one grouped row -- so the answer was no, forever, and nothing
# installed at all. The master switch on this tweak's own page is the gate now. See src/Prefs.h.
#
include $(THEOS_MAKE_PATH)/tweak.mk

#
# **The MIT licence ships inside the package, not only beside the source.**
#
# MIT asks for one thing in return for permission to use the code: that its notice travels with
# every copy. A `.deb` on somebody's phone is a copy, and the repository file they will never see
# does not satisfy that. `layout/` is copied into the package verbatim by Theos, with the
# jailbreak prefix applied for whichever scheme is being built, so the notice lands beside the
# tweak on rootless and roothide alike.
#


#
# **And the settings page, as a subproject.**
#
# It ships in this package now rather than inside Albrhi Panel. A page that lives in another
# package is a page that is simply absent whenever that package is not installed -- and Albrhi
# is a tweak for social apps, which this one has nothing to do with. Separate tweaks, separate
# rows in Settings.
#
# A subproject rather than a second name in TWEAK_NAME: that builds two dylibs, and this is a
# preference bundle, which is a different kind of thing with a different makefile behind it.
#
SUBPROJECTS += prefs

include $(THEOS_MAKE_PATH)/aggregate.mk
