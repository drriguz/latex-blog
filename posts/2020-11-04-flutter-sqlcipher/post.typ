#import "../../shared/blog.typ": blog-post, sidenote, theorem, definition, lemma, corollary
#show: blog-post.with(
  title: "flutter中使用ffi调用SqlCipher",
  date: "2020-11-04",
  tags: ("Android", "Flutter", "移动端", "闲话编程"),
  lang: "zh",
)

目前在flutter中调用sqlite有成熟的插件例如sqflite，而我需要sqlcipher，并同时加载fts5扩展，现有的插件并不能直接支持。因此需要创建一个插件来做这个事情。在以前平台集成相当麻烦，而现在有了ffi之后，可以直接调用原生代码，虽然还在试验阶段但终究是大势所趋。

= 源码编译
<源码编译>
sqlite源码编译比较简单，但是如果要运行其测试，在mac上还是有些折腾。sqlite3运行测试需要tcl8.6，自带的无法使用（/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/Tcl.framework/）
下载#link("https://www.tcl.tk/software/tcltk/download.html")[Tcl8.6]并编译安装：

```bash
cd tcl8.6.10/unix
./configure
make
sudo make install
```

然后可以跑sqlite的测试`make test`。

而要编译sqlcipher，也有一些选项需要设置，

```bash
cd sqlcipher/build
./configure --enable-tempstore=no \
  --with-crypto-lib=none \
  --enable-fts5 \
  CFLAGS="-DSQLCIPHER_CRYPTO_OPENSSL -DSQLITE_TEMP_STORE=3 -DSQLITE_HAS_CODEC -I/usr/local/opt/openssl/include/" \
  LDFLAGS="/usr/local/opt/openssl/lib/libcrypto.a"
```

= 在flutter中集成
<在flutter中集成>
== 创建插件
<创建插件>
首先需要创建一个插件：

```bash
flutter create \
  --platforms=android,ios \
  --org=com.riguz \
  --template=plugin \
  -i swift \
  -a java \
  native_sqlcipher
```

flutter升级之后，必须指定`--platforms=android,ios`才会生成ios和android的响应工程。

== 平台集成
<平台集成>
=== 生成整合的代码
<生成整合的代码>
最直接的方式是将sqlcipher（其中已经包含了sqlite的代码）整合到一个文件中（称之为"amalgamation"版本，运行速度会更快一些）

```bash
git clone https://github.com/sqlcipher/sqlcipher.git
cd sqlcipher
mkdir build
../configure --with-crypto-lib=none --enable-fts5
make sqlite3.c
```

生成完之后，会得到一个sqlite3.c和sqlite3.h。如果希望在mac上也编译出来，可以

```bash
./configure --enable-tempstore=no \
  --with-crypto-lib=none \
  --enable-fts5 \
  CFLAGS="-DSQLCIPHER_CRYPTO_OPENSSL -DSQLITE_TEMP_STORE=3 -DSQLITE_HAS_CODEC -I/usr/local/opt/openssl/include/" \
  LDFLAGS="/usr/local/opt/openssl/lib/libcrypto.a"
```

=== ios集成
<ios集成>
将sqlite3.c和sqlite3.h代码拷贝到插件的ios/Classes目录中，然后需要修改插件的podspec文件（单纯在xcode里面修改无法保存，每次pod
install之后就会丢失），需要将一些参数加进去：

```ruby
Pod::Spec.new do |s|
  s.name             = 'native_sqlcipher'
  # ...

  # 尽管之前configure的时候已经指定了SQLITE_ENABLE_FTS5，但是这里还需要再设置一次才能将fts5扩展编译进去
  s.frameworks = 'Security'
  s.xcconfig = { 'OTHER_CFLAGS' => '-DSQLITE_ENABLE_FTS5 -DSQLITE_HAS_CODEC -DSQLITE_TEMP_STORE=3 -DSQLCIPHER_CRYPTO_CC -DNDEBUG' }
  # ...
end
```

== 安卓集成
<安卓集成>
=== 编译OpenSSL
<编译openssl>
下载openssl，当前最新为1.1.1h。其编译说明可以参照NOTES.ANDROID文档。

```bash
export ANDROID_NDK_HOME=/Users/hfli/Library/Android/sdk/ndk/21.3.6528147
    PATH=$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/darwin-x86_64/bin:$ANDROID_NDK_HOME/toolchains/arm-linux-androideabi-4.9/prebuilt/darwin-x86_64/bin:$PATH
  ./Configure android-arm64 -D__ANDROID_API__=29
    make
```

对于其他平台需要重新configure然后编译：

```bash
#./Configure android-arm -D__ANDROID_API__=29
#./Configure android-arm64 -D__ANDROID_API__=29
#./Configure android-x86 -D__ANDROID_API__=29
./Configure android-x86_64 -D__ANDROID_API__=29
make clean
make
```

默认生成的so是带有后缀的，（类似\*.so.1.1)，因为安卓打包的时候不支持，解决办法是在make的时候覆盖掉参数：

```bash
make SHLIB_VERSION_NUMBER= SHLIB_EXT=.so
```

=== 集成sqlcipher
<集成sqlcipher>
== 调用
<调用>
参见#link("https://flutter.dev/docs/development/platform-integration/c-interop")[Binding to native code using dart:ffi]。

= 兼容性
<兼容性>
SqlCipher依赖一个非标准的选项，但是这个选项#link("https://discuss.zetetic.net/t/removal-of-sqlite-has-codec-compile-time-option-from-public-sqlite-code/4262")[最近已经被移除]了，SqlCipher目前包含的sqlite的版本为3.31.0，而sqlite最新为3.33.0。目前尚不知道后续的支持计划。

参考：

- #link("https://github.com/petasis/tkdnd/issues/16")[configure: error: Can't find Tcl configuration definitions MacOS]
- #link("https://www.zetetic.net/sqlcipher/ios-tutorial/")[Adding SQLCipher to Xcode Projects]
- #link("https://github.com/dart-lang/sdk/blob/master/samples/ffi/sqlite/")[Dart ffi sqlite example]
- #link("https://github.com/sqlcipher/sqlcipher/issues/132#issuecomment-122912569")[error: Library crypto not found. Install openssl!]
- #link("https://github.com/openssl/openssl/issues/3902")[shared library without version suffix for android (feature request)]
