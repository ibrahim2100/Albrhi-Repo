#
# Albrhi Licences — the panel as an app on the owner's own phone.
#
#   bash tools/build-app.sh
#
# **Why an app at all, when the panel is a web page that already works.** Three things the page
# cannot do from inside a browser, and each is the reason this exists rather than a nicety:
#
#   * the admin token lives in the **Keychain**, not in a browser's storage. That token is the
#     whole of the API's authority: anything holding it can issue and revoke licences;
#   * it is behind **Face ID**, so a phone handed to somebody for a moment is not a licence server
#     handed over with it;
#   * and it is an icon on a home screen rather than a URL to find, which is the difference
#     between checking the inbox on the way somewhere and not checking it.
#
# The screen is **native**, not the web panel in a WKWebView: seven UIKit pages over the same
# admin API. What that buys over the page is what an app can do and a browser cannot -- a tab bar
# with a badge on the requests it is waiting on, a background refresh that notices a new request
# while the app is closed, and a notification about it. The web panel stays where it is, for a
# desktop; the two talk to one server and neither is a copy of the other's screens.
#
TARGET := iphone:clang:16.2:15.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = AlbrhiLicences

AlbrhiLicences_FILES = $(shell find src -type f -iname \*.m)
AlbrhiLicences_FRAMEWORKS = UIKit Foundation LocalAuthentication Security \
	UserNotifications BackgroundTasks
AlbrhiLicences_CFLAGS = -fobjc-arc -I$(THEOS_PROJECT_DIR)/src \
	-Wno-deprecated-declarations -Wno-nullability-completeness

include $(THEOS_MAKE_PATH)/application.mk
