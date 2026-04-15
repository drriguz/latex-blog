对于C++这种需要精细管理对象的语言来说有时候真是比较复杂，一个看似简单的问题一直在困惑着我：到底可不可以在方法中返回局部变量呢？


# 可以返回临时变量

答案是肯定的，如果我们在一个方法中返回了临时变量，这个临时变量实际上是在栈里面的，当执行完方法后栈就销毁了，那么为什么我们还可以这样做呢？来看一个例子：

```c++
#include <iostream>
using namespace std;

class Value {
    public:
        Value(int _m):m(_m) { std::cout << "test constructor" << m << std::endl; }
        Value(const Value& t) { 
            std::cout << "test copy constructor" << m << std::endl; 
            this->m = t.m;
        }
        ~Value() { std::cout << "test destructor" << m << std::endl; }
        void print() { std::cout << "m:" << m << std::endl; }
    private:
        int m;
};

class Producer {
public:
    Value produce(int i) {
        Value t(i);
        return t;
    }
};

int main(int argc, char* argv[]) {
    std::cout << "Hello world!" << std::endl;
    Producer p;
    Value t = p.produce(100);
    t.print();
    return 1;
}

```
执行的结果是：

```
Hello world!
test constructor100
m:100
test destructor100
```
结果证明这样做其实是可以取到我们定义的值的，这么做可行的原因是，实际上，编译器会帮我们把临时变量拷贝一份出来，所以即便栈销毁了，我们也能够拿到新的值。

# 不要返回临时变量的引用

那么，如果我们返回临时变量的引用呢？
```c++
class Producer {
public:
    Value* produce(int i){
        Value t(i);
        return &t;
    }
};
```
这样做得到的结果是不对的：
```
test.cpp:21:17: warning: address of stack memory associated with local variable 't' returned [-Wreturn-stack-address]
        return &t;
                ^
1 warning generated.
Hello world!
test constructor100
test destructor100
m:-327065280
```
编译器会有一个警告，尽管我们仍旧可以运行我们的代码，但是实际上我们得到的值是不对的。

# NRVO机制
那么，既然我们返回临时对象的值，实际上会得到一个拷贝的对象，那么如果我们有拷贝构造函数，是不是应该被调用呢？

然而在前面的例子中，拷贝构造函数并没有被调用到，这又是为什么呢？答案就是因为NRVO(Return Value Optimization)。这是c++11中的特性。我们首先可以尝试禁用掉这个特性，看看会发生什么。

```
hfli@CNhfli ~ $ g++ -fno-elide-constructors test.cpp
hfli@CNhfli ~ $ ./a.out
Hello world!
test constructor100
test copy constructor0
test destructor100
test copy constructor0
test destructor100
m:100
test destructor100
```
可以看出，拷贝构造函数调用了两次，第一次是在produce函数中返回的时候，第二次是我们在给变量赋值的时候。