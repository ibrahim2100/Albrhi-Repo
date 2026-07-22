TARGET := iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = Instagram
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Albrhi

$(TWEAK_NAME)_FILES = $(shell find src -type f \( -iname \*.x -o -iname \*.xm -o -iname \*.m \)) $(wildcard modules/JGProgressHUD/*.m)
$(TWEAK_NAME)_FRAMEWORKS = UIKit Foundation CoreGraphics Photos CoreServices SystemConfiguration SafariServices Security QuartzCore AVFoundation VideoToolbox CoreMedia CoreVideo
$(TWEAK_NAME)_CFLAGS = -DDISABLE_ROOTLESS_COMPAT_WARNING -fobjc-arc -Ivendor/dav1d/include -Wno-unsupported-availability-guard -Wno-unused-value -Wno-deprecated-declarations -Wno-nullability-completeness -Wno-unused-function -Wno-incompatible-pointer-types -Wno-arc-performSelector-leaks

# dav1d decodes the AV1 ladder that iOS cannot, feeding the on-device transcoder.
# Both the rootless and roothide packages build as arm64 (build.sh changes only
# the package scheme, not ARCHS), so the arm64 slice is the only one linked; the
# arm64e archive is vendored and ready should an arm64e build ever be enabled.
$(TWEAK_NAME)_LDFLAGS = vendor/dav1d/lib/libdav1d-arm64.a
$(TWEAK_NAME)_LOGOSFLAGS = --c warnings=none

CCFLAGS += -std=c++11

include $(THEOS_MAKE_PATH)/tweak.mk

# Build FLEXing for sideloading (not building in dev-mode)
ifdef SIDELOAD
	$(TWEAK_NAME)_SUBPROJECTS += modules/flexing
endif
