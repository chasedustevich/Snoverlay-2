export TARGET = iphone:clang:latest:15.0
export ARCHS = arm64 arm64e
export THEOS_PACKAGE_SCHEME = rootless

# Pass your device on the command line instead of committing it, e.g.:
#   make package install THEOS_DEVICE_IP=192.168.1.50

FINALPACKAGE = 1

include $(THEOS)/makefiles/common.mk

GO_EASY_ON_ME = 1

TWEAK_NAME = Snoverlay
Snoverlay_FILES = Tweak.xm ./FallingSnow/XMASFallingSnowView.m
Snoverlay_FRAMEWORKS = UIKit QuartzCore CoreGraphics
Snoverlay_CFLAGS = -fobjc-arc -DTHEOS_LEAN_AND_MEAN -O3

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"
SUBPROJECTS += snoverlayprefs
include $(THEOS_MAKE_PATH)/aggregate.mk
