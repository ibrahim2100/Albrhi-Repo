#
# NUPrefs.bundle — resources only.
#
# Upstream shipped this as its PreferenceLoader Settings pane; this port's settings
# live in Albrhi Panel, so nothing here is compiled. What survives is the .lproj tree:
# NULocalization.h resolves its .strings by walking up from the tweak dylib's own path
# to <jbroot>/Library/PreferenceBundles/NUPrefs.bundle, so the *name and location* are
# load-bearing and are upstream's on purpose. Rename either and every string in the row
# silently falls back to compiled-in English — including Arabic.
#
export ARCHS = arm64 arm64e
export TARGET = iphone:clang:latest:14.2

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = NUPrefs
NUPrefs_INSTALL_PATH = /Library/PreferenceBundles

include $(THEOS_MAKE_PATH)/bundle.mk
