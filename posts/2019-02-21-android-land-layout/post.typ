#import "../../shared/blog.typ": blog-post, sidenote, theorem, definition, lemma, corollary
#show: blog-post.with(
  title: "Android Develop:横屏布局",
  date: "2019-02-21",
  tags: ("Android", "移动端", "闲话编程"),
  lang: "zh",
)

虽然我们可以将UI设计的尽可能的响应式，但是也可以为横屏应用单独进行布局达到更好的效果。横屏布局是通过layout-land文件夹中的同名layout文件实现的。

= 创建landscape布局
<创建landscape布局>
在新版的Android
Studio中，默认生产的工程中是没有layout-land文件夹的，我们也不必手动创建这样的文件夹。在design界面，可以快捷的创建横屏布局：

#figure(image("images/create_land_layout.png", alt: "create land layout"),
  caption: [
    create land layout
  ]
)

= 代码中的实现
<代码中的实现>
值得注意的是，虽然land的布局文件已经加上了，但我发现我的界面在旋转的时候并没有生效（竖屏的时候旋转屏幕），还是显示的竖屏的设计界面，研究了一下发现问题所在：

```xml
<activity
            android:name=".SplashActivity"
            android:configChanges="orientation|keyboardHidden|screenSize"
            android:theme="@style/Theme.AppCompat.NoActionBar">
```

可以看出android:configChanges中有orientation这一个mask，意味着当屏幕旋转时，安卓设备不会自己去处理这个事件，所以也就没有生效。解决方案有两种：

一个是删掉这个android:configChanges中的orientation选项，这样旋转屏幕的时候，android会销毁掉activity并重新创建一个，当然这时候如果有一些数据需要保存的话也就没有了。

另一个是保留这个选项，在代码中处理：

```java
@Override
public void onConfigurationChanged(Configuration newConfig) {
    super.onConfigurationChanged(newConfig);

    setContentView(R.layout.activity_splash);
}
```

这样不会销毁这个activity。

#figure(image("images/land_layout.png", alt: "land layout"),
  caption: [
    land layout
  ]
)

#figure(image("images/portrait_layout.png", alt: "portrait layout"),
  caption: [
    portrait layout
  ]
)
