#
# Albrhi CarPlay.
#
# Only what is true of this project lives here; everything shared with the
# other tweaks in this repository is in shared/tweak.mk, included at the
# bottom.
#
# Two dylibs, because this tweak needs two genuinely different injection
# scopes and mixing them into one filter would make AlbrhiCP.dylib load into
# every app on the device unconditionally, whether or not the audio fix or
# screen watcher has anything to do there:
#
#   AlbrhiCP     SpringBoard (where the CarPlay screen connects and where the
#                admission spoof runs) and Camera (the recording-quality
#                fix). A %ctor gate on the bundle identifier decides which
#                hooks a given process gets -- the same shape SCIPanelGate
#                already uses to tell one host process from another.
#
#   AlbrhiCPApp  Every app that links UIKit -- AlbrhiCPApp.plist filters on
#                com.apple.UIKit/UIKitCore rather than a bundle identifier,
#                which is the standard MobileSubstrate idiom for "every
#                foreground app" (Substrate's Bundles filter matches any
#                loaded bundle in the process, not only the main one) without
#                reaching system daemons that never link UIKit at all. It
#                rewrites its own incoming CarPlay scene role, but only for a
#                bundle identifier the user actually enabled -- see
#                SCICPSceneBridge.h.
#
# common/ holds what both binaries need identically -- SCILog.h and the bridged-app
# list both halves of the app-display feature read the same preference through --
# and is compiled into both, not just placed on both include paths, since it has its
# own .m file now. shared/ stays for what every *tweak* in the repository needs.
#
ROOT := ../..

TARGET := iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = SpringBoard Camera
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AlbrhiCP AlbrhiCPApp

COMMON_FILES = $(shell find common -type f \( -iname \*.x -o -iname \*.xm -o -iname \*.m \))

AlbrhiCP_FILES = $(shell find src -type f \( -iname \*.x -o -iname \*.xm -o -iname \*.m \)) $(COMMON_FILES)

# AVFoundation for the audio policy (AVCaptureSession, AVAudioSession). UIKit for the
# screen-connect notifications and the diagnostics report. No CarPlay.framework: nothing
# here yet requests a CPTemplateApplicationScene of our own -- that framework is for an
# app that wants Apple's sanctioned CarPlay entry point, which is deliberately not what
# this project is building.
AlbrhiCP_FRAMEWORKS = UIKit Foundation AVFoundation

AlbrhiCP_CFLAGS = -Isrc -Icommon

AlbrhiCPApp_FILES = $(shell find appsrc -type f \( -iname \*.x -o -iname \*.xm -o -iname \*.m \)) $(COMMON_FILES)
AlbrhiCPApp_FRAMEWORKS = UIKit Foundation
AlbrhiCPApp_CFLAGS = -Iappsrc -Icommon

include $(ROOT)/shared/tweak.mk
