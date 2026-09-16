TARGET := iphone:clang:16.5:17.0
ARCHS := arm64e

THEOS_PACKAGE_SCHEME := roothide

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = KeyboardToolsKayoko

KeyboardToolsKayoko_FILES = Tweak.xm KTClipboardManager.m KTClipboardViewController.m
KeyboardToolsKayoko_CFLAGS = -fobjc-arc
KeyboardToolsKayoko_FRAMEWORKS = UIKit Foundation
KeyboardToolsKayoko_LIBRARIES = sqlite3

BUNDLE_NAME = KeyboardToolsKayokoPrefs

KeyboardToolsKayokoPrefs_FILES = KTKPrefsRootListController.m
KeyboardToolsKayokoPrefs_FRAMEWORKS = UIKit Foundation
KeyboardToolsKayokoPrefs_PRIVATE_FRAMEWORKS = Preferences
KeyboardToolsKayokoPrefs_CFLAGS = -fobjc-arc
KeyboardToolsKayokoPrefs_INSTALL_PATH = /Library/PreferenceBundles
KeyboardToolsKayokoPrefs_RESOURCE_DIRS = Resources

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/bundle.mk
