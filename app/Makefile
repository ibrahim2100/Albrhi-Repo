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
# The screen itself is the same panel, loaded from the published page over https. That is
# deliberate: it is one file, it is already used every day, and a second implementation of the
# same six tables would be two things to keep in step -- which is exactly the failure this
# project keeps writing down about maps and lists that duplicate each other.
#
# https, not a copy bundled in the app: `crypto.subtle` exists only in a secure context, so a page
# loaded from file:// silently loses the signing path -- and "silently" is the word that matters.
#
TARGET := iphone:clang:16.2:15.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = AlbrhiLicences

AlbrhiLicences_FILES = $(shell find src -type f -iname \*.m)
AlbrhiLicences_FRAMEWORKS = UIKit Foundation WebKit LocalAuthentication Security
AlbrhiLicences_CFLAGS = -fobjc-arc -I$(THEOS_PROJECT_DIR)/src \
	-Wno-deprecated-declarations -Wno-nullability-completeness

include $(THEOS_MAKE_PATH)/application.mk
