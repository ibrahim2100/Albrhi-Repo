#
# Albrhi Panel — a preference bundle, not a tweak.
#
# It injects into nothing. Settings loads it when its row is tapped, it reads
# what is on the device, and it shows it. That is why this includes
# shared/bundle.mk rather than shared/tweak.mk.
#
# It ships no root helper. An earlier version did, to edit other developers'
# filter files, and that was a different product answering a question nobody
# asked — removed rather than left switched off, because a setuid root binary
# shipped for an unwanted feature is pure risk with no return.
#
ROOT := ../..

# The SDK is pinned, and this is the one line that makes the bundle link.
#
# `latest` picks the newest SDK available, which on a CI runner is Xcode's own --
# and Apple stopped shipping private-framework stubs, so that SDK has no
# PrivateFrameworks directory at all. The linker said so exactly:
#
#   search path '.../iPhoneOS26.5.sdk/System/Library/PrivateFrameworks' not found
#
# The iPhoneOS16.2 SDK the workflow downloads does carry them, and Preferences is
# a private framework. Naming the version is what points Theos at it.
#
# This couples the Makefile to the SDK the workflow fetches, and that is deliberate
# rather than overlooked: if the two ever disagree Theos fails immediately saying
# the SDK is missing, which is a better failure than linking against the wrong one.
# The two shipping tweaks can stay on `latest` because neither needs a private
# framework.
TARGET := iphone:clang:16.2:15.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = AlbrhiPanel

$(BUNDLE_NAME)_FILES = $(shell find src -type f \( -iname \*.m -o -iname \*.mm \))

# PHPickerViewController -- the CarPlay wallpaper picker -- needs PhotosUI. It is the
# one page in this bundle that needs anything beyond what shared/bundle.mk already
# links, which is why this is added here rather than there.
$(BUNDLE_NAME)_FRAMEWORKS += PhotosUI

include $(ROOT)/shared/bundle.mk


# Settings has to be restarted to pick up a rebuilt bundle; it caches the ones
# it has loaded and will keep showing the old one otherwise.
after-install::
	install.exec "killall -9 Preferences" || true
