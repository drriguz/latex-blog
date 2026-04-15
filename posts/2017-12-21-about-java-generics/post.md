泛型是Java1.5之后一个比较有用的特性，有点类似于C++的模板。最简单的一个例子：

```java
class Wrapper<T> {
    final T data;

    Wrapper(T data) {
        this.data = data;
    }
}
```
有一些可能不是特别常用的Generics，我们来简单看一下。


# Bounded Generics
## Multiple bound
如果一个类继承了多个接口，是这样的写法：
```java
interface I {}
interface M {}
abstract class C {}

class Foo extends C implements I,M {}
```
假如一个方法的泛型参数包含多个Bound，则要这样写了：
```java
<T extends I & M> void bar(T arg){}
<T extends C> void ooo(T arg){}
<T extends C & I & M> void xxx(T arg){}
```
## Unbounded wildcards

使用 ? 修饰符可以用作类型转换，List<?> 意味着是一个未知类型的List，可能是`List<A>` 也可能是`List<B>`
```java
private final List<String> strList = Arrays.asList("Hello", "World!");
private final List<Integer> intList = Arrays.asList(1, 2, 3);
private final List<Float> floatList = Arrays.asList(1.1f, 2.1f, 3.1f);
private final List<Number> numberList = Arrays.asList(1, 1.0f, 3000L);

public void cast() {
    List<?> unknownList = null;
    unknownList = strList;
    unknownList = intList;
    unknownList = floatList;
    unknownList = numberList;

    for (int i = 0; i < unknownList.size(); i++) {
        // Number item = unknownList.get(i); wrong! 
        Object item = unknownList.get(i);
        System.out.println(item + "(" + item.getClass() + ")");
    }
}
/* output
1(class java.lang.Integer)
1.0(class java.lang.Float)
3000(class java.lang.Long)
*/
```
## Upper bounded wildcards

```java
public static double sumOfList(List<? extends Number> list) {
    double s = 0.0;
    for (Number n : list)
        s += n.doubleValue();
    return s;
}
//...
sumOfList(Arrays.asList(1, 2, 3));
sumOfList(Arrays.asList(1.0f, 2.0f, 3.0f));
```

## Lower bounded wildcards

```java
public static void addNumbers(List<? super Number> list) {
    for (int i = 1; i <= 10; i++) {
        list.add(i);
        list.add(1.0f);
    }
}
addNumbers(new ArrayList<Number>());
```

# Type erase
## Type erase process

Java的泛型是编译时有效的，在运行时，所有泛型参数会被编译器擦除。擦除的规则如下：

* 如果参数是有Bound的，则会替换成这个Bound
* 如果是Unbounded，则会替换成Object

如下所示：

```java
public class Node<T> {                         // public class Node {
    private T data;                            //     private Object data;
    private Node<T> next;                      //     private Node next;
    public Node(T data, Node<T> next) {        //     public Node(Object data, Node next) {
        this data = data;                      //         this data = data;
        this next = next;                      //         this next = next;
    }                                          //     }
                                               // 
    public T getData() { return data; }        //    	public Object getData() { return data; }
}                                              // }

public class Node<T extends Comparable<T>> {   // public class Node {
    private T data;                            //     private Comparable data;
    private Node<T> next;                      //     private Node next;
    public Node(T data, Node<T> next) {        //     public Node(Comparable data, Node next) {
        this.data = data;                      //         this.data = data;
        this.next = next;                      //         this.next = next;
    }                                          //     }
                                               // 
    public T getData() { return data; }        //     public Comparable getData() { return data; }
}                                              // }
```
## Bridge method
按照上面的擦除也会带来问题。考虑下面的例子，如果有一个子类：
```java
public class MyNode extends Node<Integer> {       // public class MyNode extends Node {
    public MyNode(Integer data) { super(data); }  //     public MyNode(Integer data) { super(data); }
                                                  // 
    public void setData(Integer data) {           //     public void setData(Integer data) {
        System.out.println("MyNode.setData");     //         System.out.println("MyNode.setData");
        super.setData(data);                      //         super.setData(data);
    }                                             //     }
}                                                 // }
```
然后，我们考虑如下的代码：
```java
MyNode mn = new MyNode(5);                     // MyNode mn = new MyNode(5);
Node n = mn;                                   // Node n = (MyNode)mn;
n.setData("Hello");                            // n.setData("Hello");
Integer x = mn.data;                           // Integer x = (String)mn.data;
```
这里调用setData则会参数类型不能匹配。为了解决这个问题，Java编译器会生成一个Bridge method:
```java
public void setData(Object data) {
    setData((Integer) data);
}
```

# Q&A

## List\<?\> vs List\<Object\>

>It's important to note that List<Object> and List<?> are not the same. You can insert an Object, or any subtype of >Object, into a List<Object>. But you can only insert null into a List<?>.

## extends vs super

实际上泛型仅仅是为了做一个编译时的检查，从逻辑上确保程序是类型安全的。假设我们有这样的类定义：
Object->Parent->T->Child
我们有这样几种写法：

* ```List<?>``` 代表一种未知类型的List，可能是```List<Object>```，也可能是```List<Child>```，都可以
* ```List<? extends T>``` 代表T或者T的子类的List，可以是```List<T>```，也可以是```List<Child> ```
* ```List<? super T>``` 代表T或者T的父类的List，可以是```List<T>，List<Parent>，List<Object>```

我们有一个事实就是，Child是一定可以转化T或者Parent的，但是一个T不一定能转化成Child，因为可能会是别的子类。
比如我们现在做两个列表的拷贝，
```java
public static <T> void copy(List dest, List src)
```
想实现从一个列表拷贝到另一个列表，比如
```java
List<Parent> parents;
List<T> ts;
List<Child> childs;
```
基于上面说的类的继承的事实，ts/childs显然是可以转化成parents的，但是ts无法确保能转化成childs。因此我们的拷贝方法要这样定义：
```java
public class Collections { 
  public static <T> void copy  
  ( List<? super T> dest, List<? extends T> src) {  // uses bounded wildcards 
      for (int i=0; i<src.size(); i++) 
        dest.set(i,src.get(i)); 
  } 
}
```
因为在desc.set()方法中，需要的是一个能够转化为T的对象的，src中<? extends T> 保证了src中的元素一定是一个T。

See also:

* [Lesson: Generics (Updated)](https://docs.oracle.com/javase/tutorial/java/generics/index.html)