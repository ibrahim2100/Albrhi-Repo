#
# Albrhi NextUp — its own row in Settings.
#
# A preference bundle, not a tweak: it injects into nothing, Settings loads it when the
# row is tapped, and it reads what is on the device. Hence shared/bundle.mk.
#
# It is a subproject rather than a second target in the tweak's own Makefile because a
# space-separated TWEAK_NAME builds two of the *same* kind of thing, and these are two
# different kinds — a dylib injected into other processes, and a bundle Settings loads.
#
# The page used to live inside Albrhi Panel, reached from a row there. It is here now so
# that installing this tweak installs its settings: a page that ships in another package
# is a page that is missing whenever that package is not installed, and Albrhi is a
# social-app tweak that has nothing to do with this one.
#
ROOT := ../../..

# The pinned SDK, for the same reason Albrhi Panel pins it: Preferences is a private
# framework and Xcode's own newest SDK ships no PrivateFrameworks directory at all.
TARGET := iphone:clang:16.2:15.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = AlbrhiNextUp

AlbrhiNextUp_FILES = $(shell find ../src/Settings ../src/Localization -type f -iname \*.m)
AlbrhiNextUp_CFLAGS += -I../src -I../src/Localization

include $(ROOT)/shared/bundle.mk
