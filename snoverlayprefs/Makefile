export TARGET = iphone:clang:latest:15.0
export ARCHS = arm64 arm64e
export THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = snoverlayprefs
snoverlayprefs_FILES = SNOWRootListController.m
snoverlayprefs_INSTALL_PATH = /Library/PreferenceBundles
snoverlayprefs_FRAMEWORKS = UIKit
snoverlayprefs_PRIVATE_FRAMEWORKS = Preferences
snoverlayprefs_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk
