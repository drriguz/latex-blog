最近有非计算机专业的同学想学PyQT，但是又不知道怎么搞，所以我做了一个简单的例子。这个例子是一个简单的图片显示器。这是一篇写给新人的入门文章，希望有所帮助。



# Qt程序的基本结构
跟其他程序一样，所有的程序都会有一个主入口，然后一行一行的调用代码，而GUI程序跟其他程序有一个区别就是，只有你显示的关闭界面，程序才会退出。所以整个GUI的程序大致会是这样一个原理（下面是伪代码，不是实际的程序）：

```java
void main() {
    while(true) {
        command = fetch_user_input_event()
        if(command == quit):
            exit();
        else
            keep_rendering_ui
    }
}
```
然而实际上不需要我们去操心这个，Qt框架会帮我们处理这个逻辑，一个Qt应用就是这样：

```python
def main():
    app = QApplication(sys.argv)
    window = MainWindow()
    window.show()         # 必须显示的调用，显示一个界面
    app.exec_()           # 等待程序退出，否则界面一闪而过

if __name__ == '__main__':
    main()
```

# UI绘制
UI绘制十分简单，我们的程序最终的样子是这样：

![Image viewer](images/PyQt_image_viewer.png)

一个比较典型的桌面程序，一个主界面包含菜单栏、工具栏、主界面，状态栏没有。这些都好理解，而另一个比较重要的概念是布局，就是控件在UI上怎么摆放（尤其是UI可能会缩放），通常不会是写死的位置，而是由布局管理器来管理。简而言之，就是定义规则，你的控件怎么放，窗口缩放的时候，怎么处理。

## 主窗口
所以首先我们定义出主窗口。

```python
class MainWindow(QMainWindow):
    def __init__(self, *args, **kwargs):
        super(MainWindow, self).__init__(*args, **kwargs)
        self.setWindowTitle('Simple image editor')
        self.setFixedSize(640, 480) # 固定大小的窗口，禁止缩放
```

实际上你可以直接显示一个其他控件例如QWidget, QLabel等，它们只是控件级别，而主窗口包含菜单、状态栏等，更适合制作程序UI。然后我们主界面的控件只有一个，那就是显示图片。图片可以使用QLabel显示，虽然它更多用来显示文字：

```python
# 在Qt里面，每一个控件都可以指定父控件，更多的是因为C++中需要自动管理内存
# 当父控件销毁时，子控件跟着销毁，所以把self（主窗口）传给主窗口上的控件
self.imageContainer = QLabel(self)
self.imageContainer.setAlignment(Qt.AlignCenter)

# qt可以写css来设置样式
self.imageContainer.setStyleSheet('background-image:url(background.jpg);')

# 将图片设置为中心控件
self.setCentralWidget(self.imageContainer)
```
## 创建菜单和工具栏
菜单通过`self.menuBar`得到。

```python
menu = self.menuBar()
# 是否使用系统菜单，如果是mac，不设置的话菜单会在屏幕顶上
menu.setNativeMenuBar(False)
aboutMenu = menu.addMenu('&关于')
aboutMenu.addAction(aboutAction) 
```

工具栏跟菜单很类似，工具栏上的按钮都是一个Action，如果希望放进去别的控件可以用`addWidget`实现

```python
# 创建一个新的工具栏，可以创建多个
self.toolbar = self.addToolBar('Operations')

# 图标按钮
zoomInAction = QAction(QIcon('zengjia.svg'), '放大', self)
self.toolbar.addAction(zoomInAction)

# 非按钮控件
slider = QSlider(Qt.Horizontal)
slider.setFixedWidth(200)
self.toolbar.addWidget(slider)
```

# 事件响应
Qt是信号（Signal）/槽（Slot）机制，简单来说就是用户对界面的更改会产生事件，而事件由槽来处理，两者之间需要关联（connect）上才能正确处理。比如菜单的处理：

```python
aboutAction = QAction('&版本', self)
aboutAction.setShortcut('Ctrl+A')
# triggered事件 关联到槽，槽就是一个函数
aboutAction.triggered.connect(self.onAbout)
```

有时候事件是会有参数的，比如滑块变化的时候，值是可以得到的：

```python
slider = QSlider(Qt.Horizontal)
slider.setFixedWidth(200)
slider.setValue(100)
slider.valueChanged.connect(self.onChangeBrightness)

# 槽
def onChangeBrightness(self, value):
    # 这个value就是变化后的值（默认0-100）
    pass
```

# 图片处理

## 放大缩小

方法和缩小通过QPixmap.scaled来实现，我们通过将图片缩放到一个期望的大小（保持宽高比），来显示到界面上：

```python
 scaledImage = rotatedImage.scaled(self.imageSize.width(), self.imageSize.height(), Qt.KeepAspectRatio, Qt.SmoothTransformation)
self.imageContainer.setPixmap(scaledImage)
```
而缩放的时候，实际上就是在控制这个大小：

```python
# 一开始给定一个默认的大小
self.imageSize = QSize(300, 200)

def onZoomOut(self):
    # 缩小按0.5计算，扩大按照乘以1.5计算
    self.imageSize *= 0.5
    self.refreshImage()
```

## 旋转
旋转需要记录一个旋转角度，然后通过Qtransform来实现：

```python
transform = QTransform()
transform.rotate(self.rotateAngle)
rotatedImage = self.image.transformed(transform)
```
这样可以得到一个新的QPixmap，就是旋转后的图片。

## 调节亮度
亮度调节就比较麻烦了，图片的亮度调节需要在HSL的颜色空间下处理（我们比较熟悉的一帮是RGB三色表示）。

```python
# 将QPixmap转为QImage，以便可以直接操作像素
image = self.rawImage.toImage()
for i in range(0, image.width()):
    for j in range(0, image.height()):
        # 取到(i, j)位置的像素点
        color = QColor(image.pixelColor(i, j))

        # 取到HSL空间下的像素值
        (h, s, l, a) = color.getHsl()

        # 计算调整后的亮度值并更新，更新的时候转成了rgb
        newBrightless = l * (value/100.0)
        color.setHsl(h, s, newBrightless, a)
        image.setPixel(i, j, color.rgb())
self.image = QPixmap.fromImage(image)

```

以上就是一个简单的例子，完整的程序[下载](/images/ImageEditor.zip)：