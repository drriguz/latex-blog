#import "../../shared/blog.typ": blog-post, sidenote, theorem, definition, lemma, corollary
#show: blog-post.with(
  title: "使用OpenID Connect进行用户认证",
  date: "2020-11-30",
  tags: ("刨根问底", "OAuth", "协议"),
  lang: "zh",
)

OAuth2作为一个广泛使用的授权标准，已经基本上普及了，但是其协议本身是比较复杂的，如果不仔细研究还是会一知半解。一个常见的错误用法就是用OAuth2来进行认证（Authentication）。OAuth2不是为解决认证的问题的协议，也没有定义认证的流程；但是，在OAuth2的基础上，加以扩展得到的OpenID
Connect确是为解决这个问题而生的。

= OAuth2为什么不能用来进行认证
<oauth2为什么不能用来进行认证>
== 认证（Authentication）和 授权（Authorization）的区别
<认证authentication和-授权authorization的区别>
Authentication与Authorization是有区别的。

- Authentication：the process of verifying an identity (who they say
  they are)
- Authorization：the process of verifying what someone is allowed to do
  (permissions)

== OAuth Login的问题
<oauth-login的问题>
在OAuth的使用场景中，一种比较常见的攻击场景是"Threat: Code Substitution
(OAuth Login)"，即使用OAuth得到的code来登陆到应用中，通常在"social
login"中会存在这样的威胁。

#figure(image("images/OAuth_login.png", alt: "OAuth Login"),
  caption: [
    OAuth Login
  ]
)

如上所示，客户端认为可以拿到用户的信息（通过authorization code
flow)，那么操作的主体就是用户本人，于是很简单就实现了"微信登陆"的功能。这里的问题在于，攻击者可以自己申请一个"合法"的client，然后诱导用户请求同样的API的access\_token，在这个例子中，也就是"获取微信用户信息"，然后按照OAuth2的流程，授权服务器会调用一个url来返回给其一个"code"，这个code是绑定到了登陆的用户的。

攻击者这时可以利用这个"code"，然后去调用client的回调接口，模拟从OAuth2的认证服务器回调。这时候client会拿着这个code去换取access\_token，然后获取用户信息，然后就登陆成功了。当然这个其实很好解决：

- code一定要绑定到client\_id上，也就是说一个code只能由申请它的client去换取access\_token，这个检测是由Authorization
  server完成的

那么，既然OAuth2已经解决了这个问题，是不是就用来做认证了呢？答案还是否定的，原因很简单，因为即便你可以解决这些问题，OAuth2中并没有定义一个"标准"的做法来实现认证。

#quote(block: true)[
Clients should use an appropriate protocol, such as OpenID (cf.
\[OPENID\]) or SAML (cf.~\[OASIS.sstc-saml-bindings-1.1\]) to implement
user login. Both support audience restrictions on clients.
]

OAuth2的`access_token`的实质是将用户的一些访问权限（scopes）代理给客户端。通过OAuth2客户端可以获取一个`access_token`，代表一个用户授权进行某些操作的凭证。客户端可以通过OAuth2的introspection
endpoint来获取元数据，例如用户名等。虽然在OAuth2协议中，这个endpoint本身是给resource
server验证token使用的，但实际上并没有限制说只有resource
server可以访问。那么是否可以用OAuth来做认证呢？

但OAuth2设计access\_token的本意是给资源服务器使用的。资源服务器根据其判断是否有权限访问资源，而并不关心client程序是谁。因此实际上access\_token代表的是代理的用户权限，而不是用户本身。另外如果是client
credential的授权流程的话。就根本没有用户存在了。在OpenID
Connect的规范中也提到了：

#quote(block: true)[
They define mechanisms to obtain and use Access Tokens to access
resources but do not define standard methods to provide identity
information. Notably, without profiling OAuth 2.0, it is incapable of
providing information about the authentication of an End-User.
]

== OpenID Connect与OAuth2的区别在哪
<openid-connect与oauth2的区别在哪>
实际上OIDC在OAuth2上的核心区别在于，OpenID flow最终会生成一个"ID
Token"而不是access token，借此来对用户进行认证。

#quote(block: true)[
OpenID Connect implements authentication as an extension to the OAuth
2.0 authorization process. Use of this extension is requested by Clients
by including the openid scope value in the Authorization Request.
Information about the authentication performed is returned in a JSON Web
Token (JWT) \[JWT\] called an ID Token (see Section 2).
]

= OpenID Connect授权流程
<openid-connect授权流程>
OpenID Connect中定义了几种授权流程：

- Authorization Code Flow
- Implicit Flow
- Hybrid Flow

实际上，尽管有多种授权流程可用，但推荐的做法是使用Authorization code
flow（PKCE)，以保证最佳的安全性。

== Authorization Code Flow
<authorization-code-flow>
OpenID Connect的流程跟OAuth2的code流程差别不大，流程为：

- client发起认证请求到授权服务器上
- 授权服务器认证终端用户
- 授权服务器提示用户并得到用户的授权
- 授权服务器重定向到client，并带一个Authorization code
- client通过Authorization code换取token（id\_token和access\_token)
- client验证id\_token，认证完成

首先是客户端生成授权的URL：

```lua
https://authorization-server.com/authorize?
  response_type=code
  &client_id=egHuu4oJxgOLeBzPAQ9sXg4i
  &redirect_uri=https://www.oauth.com/playground/oidc.html
  &scope=openid+profile+email+photos
  &state=sRROJ_iPTam39Dc7
  &nonce=eFRvo_n5ecyYU_Sv
```

这里比OAuth的流程多了一个`nonce`的随机字符串。这是用来防止replay攻击的，相当于对token的一个额外的验证，而state设计师为了防止CSRF的。然后跳转到授权服务器登陆成功后，会redirect并附带一些参数：

```
?state=sRROJ_iPTam39Dc7
  &code=MsxVU0nqVYeg0BdPMV59atYOUSCZKzpbcDbCrBXwVVNt2Xw7
```

然后拿这个code去换取token:

```lua
POST https://authorization-server.com/token

grant_type=authorization_code
&client_id=egHuu4oJxgOLeBzPAQ9sXg4i
&client_secret=p4NlH7i7o2JQJ9xpGdhG95eXWgX1I8teWYZo8pH5-vILSZXv
&redirect_uri=https://www.oauth.com/playground/oidc.html
&code=MsxVU0nqVYeg0BdPMV59atYOUSCZKzpbcDbCrBXwVVNt2Xw7
```

最终可以拿到access\_token以及id\_token:

```json
{
  "token_type": "Bearer",
  "expires_in": 86400,
  "access_token": "B1dETMtgNOPBHD8CfgkcM4PEhZxOt748pUeejk_6gfUVMpfIhObdfhLigQKLQ7MVjNj4zDmb",
  "scope": "openid profile email photo",
  "id_token": "eyJraWQiOiJzMTZ0cVNtODhwREo4VGZCXzdrSEtQUkFQRjg1d1VEVGxteW85SUxUZTdzIiwiYWxnIjoiUlMyNTYifQ.eyJzdWIiOiJjb25jZXJuZWQtY2FyYWNhbEBleGFtcGxlLmNvbSIsIm5hbWUiOiJDb25jZXJuZWQgQ2FyYWNhbCIsImVtYWlsIjoiY29uY2VybmVkLWNhcmFjYWxAZXhhbXBsZS5jb20iLCJpc3MiOiJodHRwczovL3BrLWRlbW8ub2t0YS5jb20vb2F1dGgyL2RlZmF1bHQiLCJhdWQiOiJlZ0h1dTRvSnhnT0xlQnpQQVE5c1hnNGkiLCJpYXQiOjE2MDA2NzQ1MTQsImV4cCI6MTYwMzI2NjUxNCwiYW1yIjpbInB3ZCJdfQ.ZoPvZPaomdOnnz2GFRGbgaW7PPWIMFDqSBp0gbN4An4a9F-Bc-4_T9EBGV8aGetyjZYAON0gjNV0p0NGFiwettePWKuxBzusuGCEd9iXWWUO9-WTF5e2AGr3_jkg34dbxfiFXy3KgH7m0czm809cMaiZ_ofLYgJHVD8lqMQoWifhoNhpjPqa19Svc3nCHzSYHUgTXQWvA56NmQvyVPh_OM7GMpc6zHopmihJqt3eREof8N-bOd7FL39jeam2-k1TFSDogyJE513aC0OssRADr_TWvtL8xoaPkXM_7bXYs9_7erXmzF9la0hvmOuasieetpLhOvFeoiOJWCU9xhxj4Q"
}
```

简而言之，

- id\_token是给client做认证用的，可能包含一些用户敏感的信息
- access\_token是给resource server用的

== Implicit flow
<implicit-flow>
这种授权流程的步骤如下：

- client发起认证请求到授权服务器上
- 授权服务器认证用户
- 授权服务器得到用户的授权
- 授权服务器直接将id\_token以及access\_token(如果请求了的话)到client上
- client校验id token，完成认证

跟code
flow的区别在于，授权服务器认证用户完成之后直接将token发给了client而不是发送一个code。这种流程设计是本身是针对运行在浏览器上的client的，已经不被建议使用。

= 其他
<其他>
== id\_token结构
<id_token结构>
如上生成的token解析出来如下：

```json
{
  "sub": "concerned-caracal@example.com",
  "name": "Concerned Caracal",
  "email": "concerned-caracal@example.com",
  "iss": "https://pk-demo.okta.com/oauth2/default",
  "aud": "egHuu4oJxgOLeBzPAQ9sXg4i",
  "iat": 1600674514,
  "exp": 1603266514,
  "amr": [
    "pwd"
  ]
}
```

id\_token中包含了一些必须的信息：

- iss: 证书的签发者
- sub: 对应的主体（也就是到底认证的是谁了）的标识，通常就是用户名
- aud: 证书的受众，必须包含client\_id。
- exp: 过期时间
- iat: 签发时间

Reference：

- #link("https://tools.ietf.org/html/rfc6819")[RFC6819 - OAuth 2.0 Threat Model and Security Considerations]
