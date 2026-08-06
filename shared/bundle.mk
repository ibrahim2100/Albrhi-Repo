#
# Everything a preference bundle in this repository shares.
#
# Separate from shared/tweak.mk on purpose. That file exists to build a
# MobileSubstrate dylib: it forces JGProgressHUD in, sets Logos flags, and ends
# with tweak.mk. A preference bundle is a different product -- bundle.mk, no
# filter plist, no injection, and it links against Preferences rather than into
# somebody else's app.
#
# Teaching tweak.mk to be both would mean editing the one file both shipping
# tweaks depend on, to serve a third that does not resemble them. The rule this
# project already follows for check.py applies here too: leave the expensive
# thing alone and add beside it.
#
# ROOT must be set by the includer to the repository root.
#

ifeq ($(ROOT),)
$(error ROOT must be set to the repository root before including shared/bundle.mk)
endif

# The repository root on the include path, so shared code is imported by the
# path it really has rather than by counting ../ from wherever it is used.
$(BUNDLE_NAME)_CFLAGS += -I$(ROOT)

$(BUNDLE_NAME)_CFLAGS += -fobjc-arc \
	-Wno-deprecated-declarations -Wno-nullability-completeness \
	-Wno-unused-function -Wno-unsupported-availability-guard

# Preferences owns the process this bundle is loaded into, and every class it
# needs -- PSListController, PSSpecifier -- lives there.
$(BUNDLE_NAME)_PRIVATE_FRAMEWORKS = Preferences
$(BUNDLE_NAME)_FRAMEWORKS += UIKit Foundation CoreGraphics

# Where a preference bundle has to land for Settings to find it. Under rootless
# this is rewritten to /var/jb/... by Theos itself, which is why it is written
# as an absolute path here and not adjusted by hand.
$(BUNDLE_NAME)_INSTALL_PATH = /Library/PreferenceBundles

include $(THEOS_MAKE_PATH)/bundle.mk
