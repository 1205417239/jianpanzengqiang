TARGET := iphone:clang:16.5:17.0
ARCHS := arm64e

THEOS_PACKAGE_SCHEME := roothide

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = KeyboardToolsKayoko

KeyboardToolsKayoko_FILES = Tweak.xm KTClipboardManager.m KTClipboardViewController.m
KeyboardToolsKayoko_CFLAGS = -fobjc-arc
KeyboardToolsKayoko_FRAMEWORKS = UIKit Foundation

TOOL_NAME = KeyboardToolsKayokoClipboardDaemon

KeyboardToolsKayokoClipboardDaemon_FILES = Daemon/KTClipboardDaemon.m
KeyboardToolsKayokoClipboardDaemon_CFLAGS = -fobjc-arc
KeyboardToolsKayokoClipboardDaemon_FRAMEWORKS = Foundation CoreFoundation
KeyboardToolsKayokoClipboardDaemon_INSTALL_PATH = /usr/libexec

BUNDLE_NAME = KeyboardToolsKayokoPrefs

KeyboardToolsKayokoPrefs_FILES = KTKPrefsRootListController.m
KeyboardToolsKayokoPrefs_FRAMEWORKS = UIKit Foundation
KeyboardToolsKayokoPrefs_PRIVATE_FRAMEWORKS = Preferences
KeyboardToolsKayokoPrefs_CFLAGS = -fobjc-arc
KeyboardToolsKayokoPrefs_INSTALL_PATH = /Library/PreferenceBundles
KeyboardToolsKayokoPrefs_RESOURCE_DIRS = Resources

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/tool.mk
include $(THEOS_MAKE_PATH)/bundle.mk

# 在 Theos 完成 stage 后，强制修正最终 DEBIAN 维护脚本权限。
before-package::
	@chmod 755 $(THEOS_STAGING_DIR)/DEBIAN/postinst 2>/dev/null || true
	@chmod 755 $(THEOS_STAGING_DIR)/DEBIAN/postrm 2>/dev/null || true
