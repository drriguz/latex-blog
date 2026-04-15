传统的C语言需要开发人员手动管理内存，而像Java、Go这样的语言是通过垃圾回收机制自动进行内存管理。但通常垃圾回收机制本身较为复杂且需要不定期的进行（也就是说实际当内存不在需要的时候并不一定能得到及时的释放）。而rust语言采取的所有权机制（Ownership）是它区别于其他语言的一个重要特征，它被用来进行高效安全的内存管理。



# Ownership概念

在rust中，内存是由一个所有权管理系统进行管理的，它会使用一些由编译器在编译时生成的规则。这个内存管理系统的好处在于，不会像JVM stop-the-world一样暂停应用程序或者使得应用程序在运行的时候变慢。那么到底怎么样去定义ownership呢？有如下的一套规则：

* rust中每一个值都有一个变量作为与其对应的owner
* 一个值在同一时间有且仅有一个owner
* 当owner离开作用域的时候，值所在的空间会被释放(调用对象的`drop`方法)

这和C++的析构函数如出一辙，称之为*Resource Acquisition Is Initialization (RAII)*

```rust

{
    let s = String::from("hello"); // s is valid from this point forward

    // do stuff with s
}                                  // 程序走到这里会调用 drop 方法释放掉内存
```

# 作用域转移(Move)
上面说到，当对象离开作用域的时候，会调用`drop`函数来释放掉占用的内存，那么，如果遇到下面的情况呢？

```rust
let s1 = String::from("hello");
let s2 = s1;

```
字符串在内存中实际上是分为了两部分，

![Rust String copy](images/rust_string_mm.svg)

其中，左边的值存放在栈上，是固定的长度的，另外存了一个内存地址指向实际的内容，而这部分内容也就是右边的部分，是存放在堆上面的。当我们将s2赋值给s1的时候，实际上并没有进行深拷贝，也就是说堆上的数据仍旧是那个，只是将s2的指针指向了这一部分内存。那么现在存在一个问题就是，s1和s2离开作用域的时候，都会去调用`drop`释放这部分内存，这部分内存会被释放两次，显然这是不对的。为了解决这一个问题，rust中当将一个变量赋值给另一个变量的时候，会发生作用域转移，旧的对象不再有效，而释放内存这个操作，会由转移后的对象来承担这个职责。所以，一旦作用域转移后，就不能再使用这个对象了：

```rust
 --> test.rs:5:9
  |
5 |     let s1 = s;
  |         ^^ help: consider prefixing with an underscore: `_s1`
  |
  = note: `#[warn(unused_variables)]` on by default

error[E0382]: borrow of moved value: `s`
 --> test.rs:6:20
  |
4 |     let s = String::from("hello");
  |         - move occurs because `s` has type `std::string::String`, which does not implement the `Copy` trait
5 |     let s1 = s;
  |              - value moved here
6 |     println!("{}", s);
  |                    ^ value borrowed here after move

error: aborting due to previous error
```

## 使用`clone`进行深拷贝
因为默认就是浅拷贝，所以拷贝操作可以认为是很轻量级的，对性能没有什么影响。但如果的确需要深拷贝呢？那么应该使用`clone`方法，这跟其他语言差不多。

```rust
let s = String::from("hello");
let s1 = s.clone();            // 进行深拷贝操作
println!("{}\n{}", s, s1);     // 这样s作用域并没有被转移，仍然可用
```
## 简单对象的深拷贝

对于简单的基本类型而言，实际上拷贝之后，也并没有发生作用域转移，这点值得注意。
```rust
let x = 3.14;
let y = x;                   // 没问题，拷贝之后x即失效
println!("x={} y={}", x, y);

let x = String::from("hello");
let y = x;
println!("x={} y={}", x, y); // 不可以，因为x已经invalid了
```
原因是对于这些对象的拷贝完全发生在栈上，rust认为采取上面的作用域转移的策略对它们没有任何价值，所以这样设计。

## 自定义对象的深拷贝
实质上刚才所说的简单对象复制后没有发生作用域转移的深层原因是因为它们实现了一个特殊的接口`Copy`，rust中有这些对象实现了这个接口：

* 基本类型，包括数值类型、布尔、浮点数、字符类型
* 只包含实现了`Copy`接口的元组

对于我们自己的对象，也可以实现`Copy`接口，从而使得拷贝之后，作用域不会转移。如下：

```rust
#[derive(Debug, Copy, Clone)]
struct Point {
    x: i32,
    y: i32,
}

fn main() {
    let p1 = Point { x: 10, y: 10 };
    let _p2 = p1;
    println!("p1:{:?}", p1); // 没问题，因为Point继承了Copy接口
}

```

## 方法传参和返回值也会发生作用域转移
如同拷贝一样，将变量传递给函数同样会发生作用域转移，例如：

```rust
fn output(str: String) {
    println!("=>{}", str);
}

fn main() {
    let x = String::from("hello");
    output(x);
    println!("x={}", x);     // 不可以，因为x作用域已经转移了
}
```
上述的Copy规则同样适用于通过方法调用发生的作用域转移。同样，如果一个函数有返回值，那么通过返回值会更改Ownership。现在可以注意到，一旦一个变量传给了某个函数调用之后，那么这个变量就被转移了，如果我们希望多次使用这个变量，岂不是很麻烦？唯一的办法就是再将它从返回值返回回来，像这样：

```rust
fn output(str: String) -> String {
    println!("=>{}", str);
    str
}

fn generate() -> String {
    String::from("hello world!")
}

fn main() {
    let x = generate();
    let x = output(x);         // 通过返回值再把x传出来，重新获得所有权
    println!("x={}", x);       // 不可以，因为x作用域已经转移了
}
```
那么如果我们函数本身也有一个返回值怎么办？虽然我们理论上也可以通过元组的方式来实现，但是代码会变得很奇怪，所以并不是真正的解决方法。

# 引用(Reference)
解决上述问题的一个办法就是，变量引用。如果是一个变量引用的话，那么就不会夺取该变量的所有权，如下：

```rust
fn output(str: &String) {
    println!("=>{}", str);
}

fn main() {
    let x = generate();
    output(&x);                // 传递x的引用，这样就不会夺取所有权了
    println!("x={}", x);       // 可以，因为x作用域未发生转移
}
```
是不是很像c++? 😅要创建引用也很简单，加一个`&`就可以了。

```rust
let x = String::from("hello world");
let y: &String = &x;
println!("x={} y={}", x, y);   // 没问题，y是一个引用，并不会夺取所有权
```

# 借用(Borrowing)
引用变量作为函数的参数，称之为借用(borrowing)。所谓有借有还，再借不难，借的东西迟早都是要还回去的。如果你对借用的东西做了改变，怎么办呢？比如这样：

```rust
12 | fn output(str: &String) {
   |                ------- help: consider changing this to be a mutable reference: `&mut std::string::String`
13 |     str.push_str("world!");
   |     ^^^ `str` is a `&` reference, so the data it refers to cannot be borrowed as mutable

```
不用担心，借用的对象默认就是不可变的，所以编译器会检测出来，不允许这样操作。如果的确需要改变怎么办呢？对于这种情况，可以使用`&mut`创建可变的引用，当然前提是这个变量本身也要是可变的才行，否则编译器也会报错。

```rust
fn output(str: &mut String) {
    str.push_str("world!");
    println!("=>{}", str);
}

fn main() {
    let mut x = String::from("hello world");
    output(&mut x);
}
```
可变引用有一个限制就是，在同样的作用域里面至多可以有一个变量的可变引用，这样做的好处是在编译时就避免了数据竞争。rust中有以下的限制：

* 在同一个scope中，最多有一个变量的可变引用
* 可变引用和不可变引用不能同时存在。这里决定是否同时存在的条件是，在可变引用之后的语句是否有不可变引用被使用。

```rust
let mut s = String::from("hello");

let r1 = &s; // no problem
let r2 = &s; // no problem
println!("{} and {}", r1, r2);
// r1 and r2 are no longer used after this point

let r3 = &mut s; // no problem
// 如果在这个地方之后还有使用r1和r2的地方，那么编译会报错
// println!("{} and {}", r1, r2);
println!("{}", r3);
```