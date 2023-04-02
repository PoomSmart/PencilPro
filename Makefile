ifeq ($(THEOS_PACKAGE_SCHEME),rootless)
	TARGET = iphone:clang:latest:14.0
	ARCHS = arm64 arm64e
else
	TARGET = iphone:clang:latest:9.0
endif
PACKAGE_VERSION = 1.0.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = PencilPro

PencilPro_FILES = Tweak.xm

include $(THEOS_MAKE_PATH)/tweak.mk
