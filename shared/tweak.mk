#
# Everything every tweak in this repository shares.
#
# Theos requires a sandwich: common.mk before the definitions, tweak.mk after
# them. So a tweak's own Makefile opens with its identity (TARGET, TWEAK_NAME,
# the process it attaches to, its frameworks) and closes by including this file,
# which appends the parts that are the same whichever app is being patched.
#
# Anything genuinely specific to one app -- dav1d for Instagram's AV1 ladder,
# say -- belongs in that tweak's Makefile, not here.
#
# ROOT must be set by the includer to the repository root, relative to the
# tweak's own directory. Every shared path below is resolved through it, so
# modules/ and vendor/ stay at the top level and are shared rather than copied
# once per tweak.
#

ifeq ($(ROOT),)
$(error ROOT must be set to the repository root before including shared/tweak.mk)
endif

# JGProgressHUD backs the download progress UI and is not app-specific.
$(TWEAK_NAME)_FILES += $(wildcard $(ROOT)/modules/JGProgressHUD/*.m)

# The per-app switch Albrhi Panel writes. Shared rather than copied into each tweak:
# both sides have to agree on the preference domain and the key exactly, and two
# copies of that agreement drift into a switch that appears to work and changes
# nothing.
$(TWEAK_NAME)_FILES += $(ROOT)/shared/src/SCIPanelGate.m

# The repository root on the include path, so shared code is imported by the path
# it actually has -- "modules/JGProgressHUD/JGProgressHUD.h" -- rather than by
# counting ../ from whichever source file happens to need it. Four files reached
# modules/ that way and every one of them broke the moment the sources moved a
# level deeper; a header should not have to know how deep it is buried.
$(TWEAK_NAME)_CFLAGS += -I$(ROOT)

$(TWEAK_NAME)_CFLAGS += -DDISABLE_ROOTLESS_COMPAT_WARNING -fobjc-arc \
	-Wno-unsupported-availability-guard -Wno-unused-value \
	-Wno-deprecated-declarations -Wno-nullability-completeness \
	-Wno-unused-function -Wno-incompatible-pointer-types \
	-Wno-arc-performSelector-leaks

$(TWEAK_NAME)_LOGOSFLAGS = --c warnings=none

CCFLAGS += -std=c++11

include $(THEOS_MAKE_PATH)/tweak.mk

# Build FLEXing for sideloading (not building in dev-mode).
#
# Only the local sideload build reaches this; CI and the published .dylib use
# SELFCONTAINED below instead.
ifdef SIDELOAD
	$(TWEAK_NAME)_SUBPROJECTS += $(ROOT)/modules/flexing
endif

# A dylib that carries its own hooking, so it can be injected on its own -- by
# TrollStore, a certificate, SideStore, LiveContainer, anything -- without
# CydiaSubstrate having to be present alongside it.
#
# Off by default and never set for the jailbreak packages: those keep using
# Substrate exactly as they always have, and this cannot affect them.
#
# Compat/SCISubstrateShim.m supplies MSHookMessageEx itself. Defining it in our
# own binary means the linker resolves it internally, and -dead_strip_dylibs
# then drops the now-unreferenced CydiaSubstrate load command -- which is what
# makes the result genuinely standalone rather than merely appearing to be.
# CI verifies that with otool rather than trusting it.
ifdef SELFCONTAINED
	$(TWEAK_NAME)_CFLAGS += -DSCI_SELFCONTAINED
	$(TWEAK_NAME)_LDFLAGS += -Wl,-dead_strip_dylibs
endif
