TARGET = iphone:latest:9.0
PACKAGE_VERSION = 0.0.2.3

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = PencilPro

PencilPro_FILES = Tweak.xm

include $(THEOS_MAKE_PATH)/tweak.mk
