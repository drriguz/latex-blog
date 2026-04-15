如题，本文将记录如何在安卓上调用OpenCV。


# 导入OpenCV动态库
首先当然是下载OpenCV for Android了，然后使用Android Studio创建一个工程并勾选C++ support。

然后，把OpenCV-android-sdk里面的native目录拷贝到工程中，例如app/opencv这个目录，需要修改以下文件：

* app/build.gradle

```groovy
android {
....
sourceSets {
        main {
            jniLibs.srcDirs = ['opencv/libs']
        }
    }
}
```
这样做的目的是为了打包的时候能自动将opencv/libs/{arch}/libopencv_java3.so这个文件打包到我们的apk中。

* app/CMakeList.txt
```
set(opencv "${CMAKE_SOURCE_DIR}/opencv")
include_directories(${opencv}/jni/include)
add_library(libopencv_java3 SHARED IMPORTED )
set_target_properties(libopencv_java3 PROPERTIES
                      IMPORTED_LOCATION "${opencv}/libs/${ANDROID_ABI}/libopencv_java3.so")

target_link_libraries( # Specifies the target library.
                       native-lib
                       libopencv_java3
                       ${log-lib} )
```
这里把opencv作为动态库链接到工程中，并添加了包含目录，否则在编译cpp的时候会找不到opencv的头文件。

# 导入OpenCV Jaba Module

把opencv sdk下面的java目录作为一个module导入到工程中，并设置app依赖此module，这样就可以在工程中使用opencv提供的java接口了。我们来做一个相机：
```java
public class MainActivity extends AppCompatActivity implements CameraBridgeViewBase.CvCameraViewListener2
```
这里首先实现CvCameraViewListener2接口，来实现相机的处理。
```java
    private CameraBridgeViewBase cameraView;

    private BaseLoaderCallback loaderCallback = new BaseLoaderCallback(this) {
        @Override
        public void onManagerConnected(int status) {
            switch (status) {
                case LoaderCallbackInterface.SUCCESS:
                    cameraView.enableView();
                    break;
                default:
                    super.onManagerConnected(status);
                    break;
            }
        }
    };

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        this.requestPermissions();

        this.getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        setContentView(R.layout.activity_main);
        this.cameraView = (CameraBridgeViewBase) this.findViewById(R.id.cameraView);
        this.cameraView.setVisibility(SurfaceView.VISIBLE);
        this.cameraView.setCvCameraViewListener(this);
    }
```
在create的时候，我们申请权限，然后设置相机view的监听为自身。
```java
    @Override
    public void onCameraViewStarted(int width, int height) {
    }

    @Override
    public void onCameraViewStopped() {
    }
```
相机启动停止我们不需要做别的操作。
```java
    @Override
    protected void onResume() {
        super.onResume();
        if (!OpenCVLoader.initDebug())
            OpenCVLoader.initAsync(OpenCVLoader.OPENCV_VERSION_3_0_0, this, this.loaderCallback);
        else
            this.loaderCallback.onManagerConnected(LoaderCallbackInterface.SUCCESS);
    }
```
相机继续的时候，我们重新加载OpenCV库。
```java
    @Override
    public void onPause() {
        super.onPause();
        if (this.cameraView != null)
            this.cameraView.disableView();
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        if (this.cameraView != null)
            this.cameraView.disableView();
    }
```
暂停和销毁的时候，我们把相机禁用掉。
```java
    @Override
    public Mat onCameraFrame(CameraBridgeViewBase.CvCameraViewFrame inputFrame) {
        Mat frame = inputFrame.rgba();
        Core.rotate(frame, frame, Core.ROTATE_90_CLOCKWISE);
        return frame;
    }
```
这是关键的一步，处理相机的一帧。我们队图像进行了旋转，否则图像的坐标和我们的预期的是不一致的。注意在OpenCV3.2的时候，引入了便捷的rotate函数，如果用之前的方法，可能需要flip和reverse来实现了。
```java
private void requestPermissions() {
        int permissionCheck = ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA);
        if (permissionCheck == PackageManager.PERMISSION_GRANTED)
            return;

        ActivityCompat.requestPermissions(this,
                new String[]{Manifest.permission.CAMERA},
                0);

    }
```
最后是权限的动态申请。当然了，在AndroidManifest.xml中也需要进行设置，我们直接贴代码了：
```xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.riguz.okapia">

    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.CAMERA" />

    <uses-feature android:name="android.hardware.camera" />
    <uses-feature android:name="android.hardware.camera.autofocus" />
    <uses-feature android:name="android.hardware.camera.front" />
    <uses-feature android:name="android.hardware.camera.front.autofocus" />

    <application
        android:allowBackup="true"
        android:icon="@mipmap/ic_launcher"
        android:label="@string/app_name"
        android:roundIcon="@mipmap/ic_launcher_round"
        android:supportsRtl="true"
        android:theme="@style/AppTheme">
        <activity android:name=".MainActivity">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />

                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>

</manifest>
```

参考：[Use OpenCV to show camera on android App with correct orientation](http://blog.codeonion.com/2016/04/09/show-camera-on-android-app-using-opencv-for-android/)