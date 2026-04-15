最近准备实现一个基于JVM的新语言"Jer"，一开始想先实现一个Hello world，然后逐步再朝上面添加新的功能；后来觉得还是需要先把这个语言的语法层面大致设计好再动手才行。本身是出于好玩的一个目的，但是也的确希望这个语言有一些特点，而不是单纯换一个语法而已。在这个期间思考了很多，但一直没有想到自己满意的方法，姑且先按照现在的想法设计一版出来吧。



# 设计目标
我对这个语言有这些期望：

* 基于JVM平台，即最终通过代码编译生成class字节码
* 跟Java能够兼容（可以互相调用）
* 尽量简单，应该基本的数据类型、流程控制等，支持OO，但对于一些高级特性例如泛型、lambda等就不考虑了
* 依然是强类型的语言

## hello world
类似Java这样一个java文件只能对应一个类也许不是也个好的办法，jer源文件中可以申明任意数量的类。对于一个hello world来说，(大概）应该长这样子：

```rust
// 导入其他类或者其中的静态方法
use jer/lang/System

// 没有定义在类中的方法对应到java中的静态方法
main(args: [String) = {
    msg: String = "hello world!"
    println(msg)
}

```

其中，不需要使用分号作为行的分隔符，直接换行就行了。一个Jer源文件即对应到一个Java的类，类的名称即是文件名。



# Jer 语法

```antlr
compilationUint
    : importedType* declaration* EOF
    ;
declaration
    : constantDeclaration
    | methodDeclaration
    | abstractDeclaration
    | typeDeclaration
    ;

```
每一个文件中，可以包含任意：

* 导入申明
* 常量变量申明
* 方法申明（即为静态函数）
* type或者类的申明

## 导入申明

通过导入申明来引入其他包或者文件中定义的类。

```antlr
importedType
    : USE fullPath
    ;
fullPath
    : (IDENTIFIER '/')* TYPE_NAME
    ;
```

```rust
use java/lang/String
use java/util/DateTime
```

这里需要考虑一个场景就是，如果是其他Jer文件中定义了常量或者静态方法，在其他文件中如何使用？

```rust
// com/riguz/jer/Util.jer
sum(a: Integer, b: Integer) -> Integer = {
    // ...
}

// com/riguz/jer/Foo.jer
use com/riguz/jer/Util

main(args: [String) = {
    sum(1, 20)
}
```
## 常量定义
常量定义跟普通的局部变量唯一的区别就是多了一个const的关键字。具体的语法在后面介绍。
```antlr
constantDeclaration
    : CONST variableDeclaration
    ;
```
## 方法

```antlr
methodDeclaration
    : methodSignature methodImplementation?
    ;
methodSignature
    : IDENTIFIER '(' formalParameters? ')' functionReturnType?
    ;
formalParameters
    : formalParameter (',' formalParameter)*
    ;
functionReturnType
    : TO type
    ;
methodImplementation
    : '=' block
    ;
formalParameter
    : IDENTIFIER ':' type
    ;
```

方法分为两种，一种是有返回值的方法，另一种是没有返回值的方法（void），在定义的时候稍微有些区别：

```rust
// 没有返回值的方法依靠方法的副作用
main(args: [String) = {
    msg: String = "hello world!"
    println(msg)
}

// 返回值通过箭头表示
sum(a: Integer, b: Integer) -> Integer = {
    return a + b
}

```
## 抽象类和自定义类型

```antlr
abstractDeclaration
    : ABSTRACT TYPE_NAME '{' propertyDeclaration* methodSignature*'}'
    ;
typeDeclaration
    : TYPE TYPE_NAME typeAbstractions? '{' propertyDeclaration* constructorDeclaration* methodDeclaration*'}'
    ;
typeAbstractions
    : IS TYPE_NAME (',' TYPE_NAME)*
    ;
propertyDeclaration
    : IDENTIFIER ':' type
    ;
constructorDeclaration
    : '(' constructorFormalArguments? ')' methodImplementation
    ;
constructorFormalArguments
    : constructorFormalArgument (',' constructorFormalArgument)*
    ;
constructorFormalArgument
    : IDENTIFIER (':' TYPE_NAME)?
    ;
```
## 数据类型

```antlr
type
    : TYPE_NAME
    | arrayType
    ;
arrayType
    : '[' type
    ;
```
### 基本数据类型
数据类型与Java基本一致，对应到JVM的各个数据类型：

* Bool : JVM boolean
* Byte : JVM byte
* Short: JVM short
* Integer: JVM int
* Long: JVM long
* Float: JVM float
* Double: JVM double
* Char: JVM char
* String: java/lang/String

取消java中的primitive 类型，即所有一切都是引用类型。

### 数组类型

数组类型用`[<Type>`表示，例如`[Integer`即表示一个整数数组。


## 表达式

```antlr
expression
    : primary
    | expression bop='.'
        ( methodCall
        | IDENTIFIER
        )
    | methodCall
    | objectCreation
    ;
primary
    : '(' expression ')'
    | literal
    | IDENTIFIER
    ;
literal
    : DECIMAL_LITERAL
    | FLOAT_LITERAL
    | CHAR_LITERAL
    | STRING_LITERAL
    | BOOL_LITERAL
    | NULL_LITERAL
    ;
methodCall
    : instance=IDENTIFIER? '('methodName=IDENTIFIER methodArguments? ')'
    ;
methodArguments
    : expression (',' expression)*
    ;
objectCreation
    : NEW '(' methodArguments? ')'
    ;
```

## statement

```antlr
block
    : '{' statement* '}'
    ;
statement
    : variableDeclaration
    | embeddedStatement
    ;

embeddedStatement
    : block
    | assignment
    | expressionStatement
    | selectionStatement
    | loopStatement
    | returnStatement
    ;
assignment
    : IDENTIFIER '=' expression
    ;
selectionStatement
    : IF '(' expression ')' statement (ELSE statement)?
    ;
loopStatement
    : WHILE '(' expression ')' statement
    ;
returnStatement
    : RETURN expression
    ;
expressionStatement
    : methodCall
    ;
variableDeclaration
    : IDENTIFIER ':' type ('=' variableInitializer)?
    ;
variableInitializer
    : arrayInitializer
    | expression
    ;
arrayInitializer
    : '{' variableInitializer (',' variableInitializer)* '}'

```

# 代码示例

```rust
use java/lang/String
use java/util/DateTime

const pi: Float = 3.1415926f
const msg: String = "hello world"
const kb: Integer = 1024
const success: Boolean = true
const id: Long = 12345678

main(args: [String) = {
    (println "Hello world")
}

circleArea(radius: Float) -> Float = {
    return pi(multiply 2, radius)
}

abstract Movable {
    x: Integer
    y: Integer
    move(x1: Integer, y1: Integer)
}

abstract Animal {
    name: String
    sayHelloTo(person: Person)
    address() -> String
}

type Dog is Animal, Movable {
    (name) = {
        x = 0
        y = 0
    }

    sayHelloTo(person: Person) = {
        (println "Hello")
    }
}
```