LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

ifeq ($(TARGET_ARCH),arm)
LOCAL_CFLAGS += -DANDROID_ARM
LOCAL_ARM_MODE := arm
endif

ifeq ($(TARGET_ARCH),x86)
LOCAL_CFLAGS +=  -DANDROID_X86
endif

ifeq ($(TARGET_ARCH),mips)
LOCAL_CFLAGS += -DANDROID_MIPS
endif

LOCAL_STATIC_LIBRARIES += libstlport

LIBRETRO_DIR  := ..
CORE_DIR      := $(LIBRETRO_DIR)/..

include $(LIBRETRO_DIR)/Makefile.common

LOCAL_MODULE    := libretro
LOCAL_SRC_FILES = $(SOURCES_CXX)
LOCAL_CXXFLAGS = -DINLINE=inline -DLSB_FIRST -D__LIBRETRO__ -DFRONTEND_SUPPORTS_RGB565 -I$(CORE_DIR)/ameteor/include
LOCAL_C_INCLUDES += external/stlport/stlport bionic $(CORE_DIR)/ameteor/include

# https://code.google.com/p/android-ndk-profiler/
# Example: ndk-build NDK_MODULE_PATH=.../android-ndk-profiler-prebuilt-3.3 APP_ABI=armeabi-v7a PROFILE=1
ifeq ($(PROFILE), 1)
LOCAL_CFLAGS += -pg -DPROFILE -DPROFILE_ANDROID
LOCAL_STATIC_LIBRARIES := android-ndk-profiler
endif

include $(BUILD_SHARED_LIBRARY)

ifeq ($(PROFILE), 1)
$(call import-module,android-ndk-profiler)
endif
