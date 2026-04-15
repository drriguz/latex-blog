使用rust语言编写hello world再容易不过了：
```rust
fn main() {
    println!("Hello world!");
}
```
然后利用rustc编译器编译即可:
```bash
rustc hell.rs -o hello.out && ./hello.out
```

# 可变(mutable)与不可变(immutable)
rust程序默认的变量是不可变的，类似Scala这种函数式编程的语言，鼓励用户使用immutable的变量。当然如果你非想要使用可变的对象也是支持的：

```rust
let i = 32; // immutable
let mut i = 32;
```
编译器会检查是否对不可变对象重新赋值:

```
  |
4 |     let i = 10;
  |         -
  |         |
  |         first assignment to `i`
  |         help: make this binding mutable: `mut i`
...
7 |     i = 99;
  |     ^^^^^^ cannot assign twice to immutable variable
  ```

那么，对于简单类型直接赋值会有问题，如果是复杂类型，如何呢？比如我们用一个不可变的字符串，然后去调用它的函数改变值，会发生生么情况呢？

```
--> test.rs:5:5
  |
4 |     let s = String::from("hello");
  |         - help: consider changing this to be mutable: `mut s`
5 |     s.push_str(" world!!!");
  |     ^ cannot borrow as mutable

```
结果表明，rust依然保持对象是不可变的。看了一下这个方法的定义，有些蹊跷：
```rust
pub fn push_str(&mut self, string: &str) {
    self.vec.extend_from_slice(string.as_bytes())
}
```
具体怎么做到的，我们后面再来研究。

# 基本类型
rust跟大多数编译型语言一样是静态类型(statically typed)的语言，即所有的变量的类型在程序编译的时候就是已知的。在rust语言中，有着如下的基本类型：

## 标量类型(Scalar types)

类型          长度
------------ -------- ----------------------------------------
bool         1        true/ false
char         4        并不等同于Unicode
i8/u8        8
i16/u16      16
i32/u32      32       i32是默认类型，通常拥有最快的速度
i64/u64      64
i128/u128    128
isize/usize  arch     取决于机器架构，在32位机器上位32位，64位上位64位
f32          32       浮点数使用IEEE-754标准
f64          64

```rust
let f = true;
let sum:i32 = 100;
let heart_eyed_cat = '😻';
```
## 复合类型(Compound types)

复合类型分为元组（Tuple）和数组。元组可以用来将不同类型的解构组合到一起：

```rust
let t: (i32, bool) = (100, false);

let (x, y) = t; // 解构元组
let x = t.0;    // 或者通过序号访问
```

数组的与元组的区别在于数组中包含的都是同一种数据类型的值。

```rust
let a = [1, 2, 3];
let a: [i32; 5] = [1, 2, 3, 4, 5]; // 显示声明一个数组
let b = [10; 5];                   // 声明初始值为10、长度为5的数组
```
值得注意的是，在rust中元组和数组都是固定长度的，一旦声明以后就不可以更改。如果非要可变长度的集合，那么可以考虑使用标准库中的`vector`。并且数组中的元素也是不可以更改的，如果尝试去更改一个不可变的对象编译时会出错：

```
6 |     let b = [100; 5];
  |         - help: consider changing this to be mutable: `mut b`
7 |     b[1] = 1024;
  |     ^^^^^^^^^^^ cannot assign
```
这和一些其他的语言(例如Java中的final)是有区别的。

数组中如果如果声明的长度和和实际值的长度不一样会怎样呢？rust在编译时就会出错：

```
 --> hell.rs:11:23
   |
11 |     let a: [i32; 3] = [1];
   |                       ^^^ expected an array with a fixed size of 3 elements, found one with 1 element
```

另外，rust程序会在运行时对数组的边界进行检查，如果越界访问数组将抛出错误而结束程序，而不是返回一个错误的内存。

# 方法
在rust中定义一个方法使用`fn`关键字定义：

```rust
fn foo(i: i32, j: i32) {
    let sum = i + j
}

// 带有返回值的方法
fn sum(i: i32, j: i32) -> i32 {
    i + j
}
```

在rust中方法是第一类值，意味着你可以这样操作：
```rust
let fn_s  = sum;
let s = fn_s(i, j);
```

另外，方法中包含在大括号中的语句块，被称作是表达式(expression)，可以这样用：

```rust
let a = {
   e + 10
};
println!("{}", a);
```

# 流程控制

## if语句

rust的if语句和其他语言基本类似，稍微有一点区别：

```rust
if e % 2 == 0 {        // if条件后面不用写小括号
    println!("{}", e);
} else if e % 3 == 0 { // 但是后面的语句块必须包含在大括号之中，哪怕只有一行
    println!("{} % 3 ==0", e);
} else {
    println!(":p");
}
```

## 条件赋值

因为if语句本身是一个表达式，所以可以把if和let联合在一起来使用，也就是条件赋值：
```rust
let a = if condition {
    5
} else {
    6
};
```
当然前提是不同的分支下的语句要是一样的类型，否则编译器会检测出错误。

## 循环
rust的`loop`关键字支持创建一个循环:
```rust
let mut i = 0;
loop {
    i += 1;
    println!("->{}", i);
}
```
基本上这就是一个死循环了。不知道为啥要定义这样一个奇葩的关键字。索性我们可以像其他编程语言一样`break`。值得注意的是，跟条件赋值一样，loop语句也是可以和let一起来赋值的，像下面这样：

```rust
let s = loop {
    i += 1;
    println!("->{}", i);
    if(i > 100) {
        break i;
    }
};
println!("s = {}", s); // s = 101
```

除了这个`loop`外，也可以“正常的”像其他语言一样，使用`while`和`for`进行条件循环：

```rust
while i < 1000 {    // 不用写小括号
    i += 1;
}

for e in a.iter() { // 使用for循环遍历数组
    println!("{}", e); 
}

// for i in (1..10).rev()
// 使用rev()反转顺序
for i in (1..10) {
    println!("{}", i);
}

```
# rust语言的一些惯例

## 命名方式

rust中推荐使用蛇形命名(snake case)来作为方法和变量的命名方式，所有的标识符都是小写且使用下划线分隔，例如：

```rust
let foo_bar = 1;

fn print_info() {

}
```