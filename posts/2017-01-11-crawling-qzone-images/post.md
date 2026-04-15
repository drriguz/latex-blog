最近把博客重新整理了一下，博文设置featured image果然看起来现代不少，但是要去哪找这么多合适的图片呢？当然PS是一个不错的选择，但是费时费力。看到QQ空间的皮肤倒是做的不错，直接拿来用吧，反正不违法。于是想用爬虫抓取。

先调试一下，找几个图片看看：
```
http://i.gtimg.cn/qzone/space_item/orig/3/103603_top.jpg
http://i.gtimg.cn/qzone/space_item/orig/7/101703_top.jpg
http://i.gtimg.cn/qzone/space_item/orig/5/108725_top.jpg
http://i.gtimg.cn/qzone/space_item/orig/15/111327_top.jpg
http://i.gtimg.cn/qzone/space_item/orig/8/106904_top.jpg
http://i.gtimg.cn/qzone/space_item/orig/10/102490_top.jpg
```
可以看到前面的网址都是一样的`orig/%d/%d_top.jpg`，刚开始以为前面的一个数字是主题编号还是什么的，后面自然是图片ID，于是用以下的脚本抓取（Scrapy):
```python
def start_requests(self):
    for i in range(0, 100):
        for j in range(100000, 119999):
            url = 'http://i.gtimg.cn/qzone/space_item/orig/%d/%d_top.jpg' % (i, j)        
            yield scrapy.Request(url=url, callback=self.parse)
```
后来抓取完成后，一共15个文件夹，每个文件夹差不多都是50-80个左右，这就有点意思了，可能腾讯利用了分布式的图片服务器，分散到0-15个不同的服务器上。随便找一个看看：
101195_top.jpg在11下面，通常取余的方式实现，于是来试试：
```
101195% 16 = 11
```
另外再验证几次也都是正确的，证明的我们的猜想。于是我们可以修改一下我们的爬虫了：
```python
for i in range(100000, 200000):
    url = 'http://i.gtimg.cn/qzone/space_item/orig/%d/%d_top.jpg' % (i % 16, i) 
    yield scrapy.Request(url=url, callback=self.parse)
```
这样抓取就快多了，总共抓取了1232个图片。