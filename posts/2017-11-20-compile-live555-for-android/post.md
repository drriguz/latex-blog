编译 live555的库在 android 上使用。

首先下载liveMedia库。解压完成可以先在linux环境下编译一遍试试，例如：
```bash
./genMakefiles macosx
make
```
然后，可以利用ndk-build将它交叉编译成动态库。这时候，需要新建一个Android.mk和Application.mk文件：
* Application.mk
```makefile
APP_BUILD_SCRIPT := Android.mk
APP_STL := gnustl_shared
APP_ABI := armeabi-v7a
```

* Android.mk
```makefile
LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

LOCAL_MODULE := liblive555
LOCAL_CPPFLAGS += -fexceptions -DXLOCALE_NOT_USED=1 -DNULL=0 -DNO_SSTREAM=1 -UIP_ADD_SOURCE_MEMBERSHIP -DSOCKLEN_T=socklen_t

LOCAL_C_INCLUDES := \
	$(LOCAL_PATH) \
	$(LOCAL_PATH)/BasicUsageEnvironment/include \
	$(LOCAL_PATH)/UsageEnvironment/include \
	$(LOCAL_PATH)/groupsock/include \
	$(LOCAL_PATH)/liveMedia/include \

LOCAL_SRC_FILES := \
	BasicUsageEnvironment/BasicHashTable.cpp         \
        ...(这里把其他cpp、c文件都列到这里）

include $(BUILD_SHARED_LIBRARY)
```
然后执行ndk-build进行编译：
```bash
ndk-build NDK_PROJECT_PATH=. NDK_APPLICATION_MK=Application.mk
```
编译完成就可以得到libgnustl_shared.so liblive555.so了。