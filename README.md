# lua-resty-wechat

使用Lua编写的nginx服务器微信公众平台代理.

目标:
* 在前置的nginx内做微信代理, 降低内部应用层和微信服务的耦合.
* 配置微信公众号的自动回复, 在nginx内处理部分用户消息, 减小应用层压力.
* 统一管理微信公众号API中使用的ACCESS_TOKEN, 作为中控服务器隔离业务层和API实现, 降低ACCESS_TOKEN冲突率, 增加服务稳定性.
* 部署微信JS-SDK授权回调页面, 减小应用层压力.

## 子模块说明

### 全局配置

  [config](https://github.com/CharLemAznable/lua-resty-wechat/blob/master/lib/resty/wechat/config.lua)

  公众号全局配置数据, 包括接口Token, 自动回复设置.

### 作为服务端由微信请求并响应

  [server](https://github.com/CharLemAznable/lua-resty-wechat/blob/master/lib/resty/wechat/server.lua)

  接收微信发出的普通消息和事件推送等请求, 并按配置做出响应, 未做对应配置则按微信要求返回success.

  此部分核心代码由[aCayF/lua-resty-wechat](https://github.com/aCayF/lua-resty-wechat)做重构修改而来.

  使用config.autoreplyurl, 配置后台处理服务地址, 转发处理并响应复杂的微信消息. (依赖[pintsized/lua-resty-http](https://github.com/pintsized/lua-resty-http))

### 作为客户端代理调用微信公众号API

  [proxy_access_token](https://github.com/CharLemAznable/lua-resty-wechat/blob/master/lib/resty/wechat/proxy_access_token.lua)

  使用Redis缓存AccessToken, 定时自动调用微信服务更新, 支持分布式.

  [proxy](https://github.com/CharLemAznable/lua-resty-wechat/blob/master/lib/resty/wechat/proxy.lua)

  代理调用微信公众平台API接口, 自动添加access_token参数.

  [proxy_access_filter](https://github.com/CharLemAznable/lua-resty-wechat/blob/master/lib/resty/wechat/proxy_access_filter.lua)

  过滤客户端IP, 限制请求来源.

## 示例

  nginx配置:

    http {
      init_by_lua '
        require("resty.wechat.config")
      ';
      init_worker_by_lua '
        require("resty.wechat.proxy_access_token").process()
      ';
      server {
        location /wechat-server {
          content_by_lua '
            require("resty.wechat.server").process()
          ';
        }
        location /wechat-proxy/ {
          rewrite_by_lua '
            require("resty.wechat.proxy").rewrite("wechat-proxy") #参数为location路径
          ';
          access_by_lua '
            require("resty.wechat.proxy_access_filter").filter()
          ';
          proxy_pass https://api.weixin.qq.com/;
        }
      }
    }
