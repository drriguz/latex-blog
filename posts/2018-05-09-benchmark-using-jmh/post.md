JMH是一个测试Java程序性能的工具，比如我们现在要测试一下JDK8自带的Base64和[另一个实现](http://www.java2s.com/Code/Java/Development-Class/AfastandmemoryefficientclasstoencodeanddecodetoandfromBASE64infullaccordancewithRFC2045.htm)的性能。

先看看 build.gradle 中怎么写：
```groovy
group 'riguz'
version '1.0-SNAPSHOT'

apply plugin: 'java'

sourceCompatibility = 1.8

sourceSets {
    jmh
}
repositories {
    mavenCentral()
}

dependencies {
    jmhCompile project
    jmhCompile 'org.openjdk.jmh:jmh-core:1.21'
    jmhCompile 'org.openjdk.jmh:jmh-generator-annprocess:1.21'
    jmhCompile group: 'junit', name: 'junit', version: '4.12'
    testCompile group: 'junit', name: 'junit', version: '4.12'
}

task jmh(type: JavaExec, description: 'Executing JMH benchmarks') {
    classpath = sourceSets.jmh.runtimeClasspath
    main = 'org.openjdk.jmh.Main'
}

```
然后写一个类：
```java
@Benchmark
    @Warmup(iterations = 1, time = 5)
    @Measurement(iterations = 1, time = 5)
    public void encodeWithJdk() {
        final byte[] bytes = Dream.text.getBytes();
        byte[] encoded = Base64.getEncoder().encode(bytes);
        byte[] decoded = Base64.getDecoder().decode(encoded);
        assertTrue(Arrays.equals(bytes, decoded));
    }

    @Benchmark
    @Warmup(iterations = 1, time = 5)
    @Measurement(iterations = 1, time = 5)
    public void encodeWithBase64Codec() throws IOException {
        final byte[] bytes = Dream.text.getBytes();
        byte[] encoded = Base64Codec.encodeToByte(bytes, true);
        byte[] decoded = Base64Codec.decodeFast(encoded, encoded.length);
        assertTrue(Arrays.equals(bytes, decoded));
    }
```
其中Dream.text是一个很长的字符串。执行gradle的jmh task之后，可以得到结果
```
Benchmark                               Mode  Cnt   Score   Error  Units
Base64BenchMark.encodeWithBase64Codec  thrpt    5  15.296 ± 2.538  ops/s
Base64BenchMark.encodeWithJdk          thrpt    5  13.029 ± 1.563  ops/s
```
看样子要比JDK的实现强一丢丢，当然只是在上面的这种情况之下。差距并不大。

参考:

* http://tutorials.jenkov.com/java-performance/jmh.html#why-are-java-microbenchmarks-hard
* https://www.jianshu.com/p/192b782c31bc