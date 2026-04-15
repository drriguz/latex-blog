前前后后各种原因耽搁了大半年，终于还是下定决心开始做我的Okapia android应用了，笔者一直从事的是Java后端和Web开发，基本上没有安卓开发的项目经验，正所谓万事开头难，一边学一边做。所以我计划把做的过程中遇到的一些问题都整理记录下来，供读者参考。


# 原型设计
原型设计是一项比较重要的事情，可以帮助我们在开发之前就理清楚要做什么，现在有比较多的工具可以来做这个事情。我用的是别人推荐的MockingBot（墨刀），一个国产软件，还比较好用。

![mockingbot](images/mockingbot_ui.png)

# 图标资源文件夹
使用android studio生成的项目中，有不少文件夹：

![android project resource folder](images/android_project_res.png)

* drawable
* drawable-v24
* mipmap-anydpi-v26
* mipmap-hdpi
* ...

可以看出mipmap-xxxx中其实都是不同分辨率适配的不同大小的图标，唯独mipmap-anydpi-v26中其实是一个xml，将background和forground分开了拼合到了一起。而background和forground实际是一个矢量图，网上资料显示实际是svg的一个简化版本的android实现。这就麻烦了，哪里去做svg矢量图！大概有以下的途径吧：

# 图标生成与编辑
## 图标编辑工具

* 将图片转换为SVG [pngtosvg](https://www.pngtosvg.com/)
* 使用SVG编辑工具绘制（推荐macSvg）
* 将SVG转换为android vector [svg2android](http://inloop.github.io/svg2android/ )

这样需要生成两张图片，一个背景一个图标。注意图标要适当居中一点，边上要留一些边距。这个可以通过控制viewBox和拖动形状来完成，在macSvg中即可处理。

![macsvg](images/macsvg.png)

譬如如上的图片，它的参照系设置是400，这样把图片拖到200的位置，就基本上居中了。如果想让图片缩小一点，可以把参照系设置大一点，比如600，再把形状拖到300的位置，想直接缩小形状貌似是没找到办法。简单的颜色替换什么的，其实直接用文本编辑器就可以了。

## 导入到工程中

通过在res文件夹上右键:New -> Image Set即可自动生成各个分辨率的图标。

![Import image set](images/new_image_set.png)

# 安卓中的图标与名称配置

在AndroidManifest.xml中配置了图标的路径：
```xml
<application
        android:allowBackup="true"
        android:icon="@mipmap/ic_launcher"
        android:label="@string/app_name"
        android:roundIcon="@mipmap/ic_launcher_round"
        android:supportsRtl="true"
        android:theme="@style/AppTheme">
```

可以看出指定了icon、label和roundIcon等。这里我们保持原有的ic_launcher名称即可，导入图标的时候直接替换掉即可。另一个是app的名称，需要注意的是，如果启动的Activity上有label，这时候app的名称会变成这个activity的名称，例如:

```xml
<activity
        android:name=".FullscreenActivity"
        android:configChanges="orientation|keyboardHidden|screenSize"
        android:label="@string/title_activity_fullscreen"
        android:theme="@style/FullscreenTheme"></activity>
```
如果这个activity是启动activity，那么app的名称就是@string/title_activity_fullscreen这个值了，要处理这个也很简单，我们直接删掉这个activity的label属性即可。