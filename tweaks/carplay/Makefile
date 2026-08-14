#
# Albrhi CarPlay.
#
# Only what is true of this project lives here; everything shared with the
# other tweaks in this repository is in shared/tweak.mk, included at the
# bottom.
#
# Two processes, one dylib: SpringBoard, where the CarPlay screen connects
# and where any future dashboard has to live (that is where the live
# scene-hosting machinery this project studied lives too), and Camera, where
# the recording-quality fix runs. A %ctor gate on the bundle identifier
# decides which hooks a given process actually gets -- the same shape
# SCIPanelGate already uses to tell one host process from another.
#
ROOT := ../..

TARGET := iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = SpringBoard Camera
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AlbrhiCP

$(TWEAK_NAME)_FILES = $(shell find src -type f \( -iname \*.x -o -iname \*.xm -o -iname \*.m \))

# AVFoundation for the audio policy (AVCaptureSession, AVAudioSession). UIKit for the
# screen-connect notifications and the diagnostics report. No CarPlay.framework: nothing
# here yet requests a CPTemplateApplicationScene of our own -- that framework is for an
# app that wants Apple's sanctioned CarPlay entry point, which is deliberately not what
# this project is building.
$(TWEAK_NAME)_FRAMEWORKS = UIKit Foundation AVFoundation

$(TWEAK_NAME)_CFLAGS = -Isrc

include $(ROOT)/shared/tweak.mk
