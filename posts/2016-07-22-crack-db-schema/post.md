我始终认为数据库设计在系统设计中是一个很重要的工作，然而一直没有比较好的ER建模工具。使用过MySQL Workbench和Power Designer两种工具，但都存在很多不喜欢的地方，直到遇到DbSchema后眼前一亮，这才是一个Nice的工具嘛。
很可惜对于我们这种屌丝来说，是不舍得花钱去购买一个license的，试用期15天到了怎么办呢？当时也没发现有可用的破解版，因为它是基于Java的，这对破解来说减小了难度，于是趁着辞职后在家没事的空档来研究了一下破解。其实也就上午花了一会时间就搞定了。记录下破解的过程。

首先是找到dbschema.jar，这是程序的主要jar包，其他是一些第三方的jar包和jdbc驱动等，于是它就是破解的关键。利用jd-gui反编译这个jar包，首先把源码都保存下来。

顺藤摸瓜，首先打开dbschema的注册窗口，根据里面的关键字搜索，比如Registration，然后一个个去找，这时，发现一个对话框：

```java
public class RegistrationDialog
...
JButton localJButton1 = new JButton(getAction("register"));
```

这不就是注册的按钮么？然后就看它的action:
```java
/*     */   public void register() {
/*  96 */     String str1 = this.b.getText();
/*     */     
/*  98 */     if ((str1 == null) || (str1.length() == 0)) {
/*  99 */       JOptionPane.showMessageDialog(this, d.a(11), "Error", 0);
/* 100 */       return;
/*     */     }
/* 102 */     String str2 = this.c.getText();
/* 103 */     if (str2 == null) {
/* 104 */       JOptionPane.showMessageDialog(this, d.a(19), "Error", 0);
/* 105 */       return;
/*     */     }
/* 107 */     str1 = str1.trim();
/* 108 */     str2 = str2.trim();
/* 109 */     e.b(d.a(31), str1);
/* 110 */     e.b(d.a(21), str2);
/*     */     
/* 112 */     int i = g.b();
/* 113 */     if (i == Integer.MAX_VALUE) {
/* 114 */       dispose();
/* 115 */       JOptionPane.showMessageDialog(this.a.c(), d.a(23), "Info", 1, null);
/* 116 */       this.a.c().c();
/* 117 */     } else if ((i > 0) && (str1.toLowerCase().startsWith("extend"))) {
/* 118 */       dispose();
/* 119 */       JOptionPane.showMessageDialog(this.a.c(), d.a(24).replaceAll("\\{days\\}", "" + i), "Info", 1, null);
/* 120 */     } else if (i == -2) {
/* 121 */       String str3 = d.a(77).replace("{0}", new SimpleDateFormat("dd.MMMMM.yyyy").format(new Date(g.c())));
/* 122 */       JOptionPane.showMessageDialog(this.a.c(), str3, "Error", 0);
/*     */     } else {
/* 124 */       JOptionPane.showMessageDialog(this.a.c(), d.a(8), "Error", 0);
/*     */     }
/*     */   }
```
112行开始有点意思，其实大概能猜到是干什么，反正是算剩余天数的，那么这个int i = g.b();就是最核心的东西了：
```java
public static int b()
  {
    String str1 = e.d(d.a(31), null);
    String str2 = e.d(d.a(21), null);
    int m = -1;
    if ((str1 != null) && (str2 != null) && (str2.length() > 3))
    {
      if ((str1.toLowerCase().startsWith("extend")) && (c(str1, str2)))
      {
        m = Math.max(15 - f("mmax"), -1);
      }
      else if (str2.length() > 15)
      {
        String str3 = str2.substring(4, 9);
        String str4 = str2.substring(0, 4) + str2.substring(9);
        if (c("ax5" + str1 + "b52w" + str3 + "vb3", str4))
        {
          try
          {
            k = Integer.parseInt(str3) * 86400000L + 1356994800000L;
          }
          catch (NumberFormatException localNumberFormatException)
          {
            c.b(localNumberFormatException);
          }
          m = Integer.MAX_VALUE;
        }
      }
    }
    else {
      m = Math.max(15 - f("mma"), -1);
    }
    return m;
  }
```
看到这，我们其实已经拿到了计算key的方法，只不过这是一个验证的函数，如果我们要计算出key，需要反向推倒出来，这里就不具体解释了，最终反向出来的代码其实很简单，我做了一个C++版本的：
```java
inline const string generateKey(string name)
{
    string salt = getSalt();
    cout << "salt:" << salt << endl;
    string encryptSource = "ax5" + name + "b52w" + salt + "vb3";
    cout << "encrypt:" << encryptSource << endl;
    string hash = MD5(encryptSource).toStr();
    cout << "md5:" << hash << endl;
    return hash.substr(0, 4) + salt + hash.substr(4);
}
```
于是我们就有了一个key生成器了，完整的key生成器源码在Github。