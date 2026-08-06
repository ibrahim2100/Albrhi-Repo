#
# Albrhi Panel — a preference bundle, not a tweak.
#
# It injects into nothing. Settings loads it when its row is tapped, it reads
# what is on the device, and it shows it. That is why this includes
# shared/bundle.mk rather than shared/tweak.mk.
#
ROOT := ../..

TARGET := iphone:clang:latest:15.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = AlbrhiPanel

$(BUNDLE_NAME)_FILES = $(shell find src -type f \( -iname \*.m -o -iname \*.mm \))

include $(ROOT)/shared/bundle.mk

# Settings has to be restarted to pick up a rebuilt bundle; it caches the ones
# it has loaded and will keep showing the old one otherwise.
after-install::
	install.exec "killall -9 Preferences" || true
