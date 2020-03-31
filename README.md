# lua-resty-wechat

[![GitHub license](https://img.shields.io/github/license/CharLemAznable/lua-resty-wechat.svg)](https://github.com/CharLemAznable/lua-resty-wechat/blob/master/LICENSE)

[![GitHub watchers](https://img.shields.io/github/watchers/CharLemAznable/lua-resty-wechat.svg?style=social&label=Watch&maxAge=86400)](https://GitHub.com/CharLemAznable/lua-resty-wechat/watchers/)
[![GitHub stars](https://img.shields.io/github/stars/CharLemAznable/lua-resty-wechat.svg?style=social&label=Star&maxAge=86400)](https://GitHub.com/CharLemAznable/lua-resty-wechat/stargazers/)
[![GitHub forks](https://img.shields.io/github/forks/CharLemAznable/lua-resty-wechat.svg?style=social&label=Fork&maxAge=86400)](https://GitHub.com/CharLemAznable/lua-resty-wechat/network/)

使用Lua编写的nginx服务器微信公众平台代理.

目标:
* 在前置的nginx内做微信代理, 降低内部应用层和微信服务的耦合.
* 配置微信公众号的自动回复, 在nginx内处理部分用户消息, 减小应用层压力.
* 统一管理微信公众号API中使用的```access_token```, 作为中控服务器隔离业务层和API实现, 降低```access_token```冲突率, 增加服务稳定性.
* 部署微信JS-SDK授权回调页面, 减小应用层压力.

## 子模块说明

### 全局配置

  [config](https://github.com/CharLemAznable/lua-resty-wechat/blob/master/lib/resty/wechat/config.lua)

  公众号全局配置数据, 包括接口Token, 自动回复设置.

### 作为服务端由微信请求并响应

  [server](https://github.com/CharLemAznable/lua-resty-wechat/blob/master/lib/resty/wechat/server.lua)

  接收微信发出的普通消息和事件推送等请求, 并按配置做出响应, 未做对应配置则按微信要求返回```success```.

  此部分核心代码由[aCayF/lua-resty-wechat](https://github.com/aCayF/lua-resty-wechat)做重构修改而来.

  使用```config.autoreplyurl```, 配置后台处理服务地址, 转发处理并响应复杂的微信消息. (依赖[pintsized/lua-resty-http](https://github.com/pintsized/lua-resty-http))

### 作为客户端代理调用微信公众号API

  [proxy_access_token](https://github.com/CharLemAznable/lua-resty-wechat/blob/master/lib/resty/wechat/proxy_access_token.lua)

  使用Redis缓存```access_token```和```jsapi_ticket```, 定时自动调用微信服务更新, 支持分布式更新.

  [proxy](https://github.com/CharLemAznable/lua-resty-wechat/blob/master/lib/resty/wechat/proxy.lua)

  代理调用微信公众平台API接口, 自动添加```access_token```参数.

  [proxy_access_filter](https://github.com/CharLemAznable/lua-resty-wechat/blob/master/lib/resty/wechat/proxy_access_filter.lua)

  过滤客户端IP, 限制请求来源.

### 代理网页授权获取用户基本信息

  [oauth](https://github.com/CharLemAznable/lua-resty-wechat/blob/master/lib/resty/wechat/oauth.lua)

### JS-SDK权限签名

  [jssdk_config](https://github.com/CharLemAznable/lua-resty-wechat/blob/master/lib/resty/wechat/jssdk_config.lua)

## 示例

  nginx配置:

``` nginx
http {
  lua_package_path 'path to lua files';
  resolver 114.114.114.114;

  lua_shared_dict wechat 1M; # 利用共享内存保持单例定时器
  init_by_lua '
    ngx.shared.wechat:delete("updater") -- 清除定时器标识
    require("resty.wechat.config")
  ';
  init_worker_by_lua '
    local ok, err = ngx.shared.wechat:add("updater", "1") -- 单进程启动定时器
    if not ok or err then return end
    require("resty.wechat.proxy_access_token")()
  ';
  server {
    location /wechat-server {
      content_by_lua '
        require("resty.wechat.server")()
      ';
    }
    location /wechat-proxy/ {
      rewrite_by_lua '
        require("resty.wechat.proxy")("wechat-proxy") -- 参数为location路径
      ';
      access_by_lua '
        require("resty.wechat.proxy_access_filter")()
      ';
      proxy_pass https://api.weixin.qq.com/;
    }
    location /wechat-baseoauth { # param: goto
      rewrite_by_lua '
        require("resty.wechat.oauth").base_oauth("path to /wechat-redirect")
      ';
    }
    location /wechat-useroauth { # param: goto
      rewrite_by_lua '
        require("resty.wechat.oauth").userinfo_oauth("path to /wechat-redirect")
      ';
    }
    location /wechat-redirect {
      rewrite_by_lua '
        require("resty.wechat.oauth").redirect()
      ';
    }
    location /wechat-jssdk-config { # GET/POST, param: url, [api]
      add_header Access-Control-Allow-Origin "if need cross-domain call";
      content_by_lua '
        require("resty.wechat.jssdk_config")()
      ';
    }
  }
}
```

  网页注入JS-SDK权限:

``` javascript
$.ajax({
  url: "url path to /wechat-jssdk-config",
  data: {
    url: window.location.href,
    api: "onMenuShareTimeline|onMenuShareAppMessage|onMenuShareQQ|onMenuShareWeibo|onMenuShareQZone"
  },
  success: function(response) {
    wx.config(response);
  }
});

$.ajax({
  url: "url path to /wechat-jssdk-config",
  data: {
    url: window.location.href
  },
  success: function(response) {
    wx.config({
      appId: response.appId,
      timestamp: response.timestamp,
      nonceStr: response.nonceStr,
      signature: response.signature,
      jsApiList: [
          'onMenuShareTimeline',
          'onMenuShareAppMessage',
          'onMenuShareQQ',
          'onMenuShareWeibo',
          'onMenuShareQZone'
      ]
    });
  }
});
```

  使用Java解析代理网页授权获得的cookie

``` java
Map authInfo = JSON.parseObject(decryptAES(unBase64("cookie value"), getKey("AES key")));

// 默认AES key: "vFrItmxI9ct8JbAg"
// 配置于config.lua -> cookie_aes_key

// 依赖方法

import com.alibaba.fastjson.JSON;
import com.google.common.base.Charsets;
import javax.crypto.Cipher;
import javax.crypto.spec.SecretKeySpec;
import java.security.Key;

public StringBuilder padding(String s, char letter, int repeats) {
    StringBuilder sb = new StringBuilder(s);
    while (repeats-- > 0) {
        sb.append(letter);
    }
    return sb;
}

public String padding(String s) {
    return padding(s, '=', s.length() % 4).toString();
}

public byte[] unBase64(String value) {
    return org.apache.commons.codec.binary.Base64.decodeBase64(padding(value));
}

public String string(byte[] bytes) {
    return new String(bytes, Charsets.UTF_8);
}

public String decryptAES(byte[] value, Key key) {
    try {
        Cipher cipher = Cipher.getInstance("AES/ECB/PKCS5Padding");
        cipher.init(Cipher.DECRYPT_MODE, key);
        byte[] decrypted = cipher.doFinal(value);
        return string(decrypted);
    } catch (Exception e) {
        throw new RuntimeException(e);
    }
}

public byte[] bytes(String str) {
    return str == null ? null : str.getBytes(Charsets.UTF_8);
}

public Key keyFromString(String keyString) {
    return new SecretKeySpec(bytes(keyString), "AES");
}

public Key getKey(String key) {
    if (key.length() >= 16) {
        return keyFromString(key.substring(0, 16));
    }
    StringBuilder sb = new StringBuilder(key);
    while (sb.length() < 16) {
        sb.append(key);
    }
    return keyFromString(sb.toString().substring(0, 16));
}
```
