TARGET = iphone:clang:latest:9.0
PACKAGE_VERSION = 1.0.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = PencilPro

PencilPro_FILES = Tweak.xm

include $(THEOS_MAKE_PATH)/tweak.mk
