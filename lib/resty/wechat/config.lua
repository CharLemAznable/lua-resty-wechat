local modname = "wechat_config"
local _M = { _VERSION = '0.0.2' }
_G[modname] = _M

_M.appid = "" -- 公众平台AppID
_M.appsecret = "" -- 公众平台AppSecret

_M.token = "" -- 公众平台接口配置Token

_M.autoreply = { -- 简单的自动回复设置
  -- text     = {
  --   { cond = { content = "用户发出的文字消息全文匹配的正则表达式" },
  --     resp = { msgtype = "text或其他消息类型", 以及对应消息所需的字段和内容 }
  --   },
  -- },
  -- image    = { },
  -- voice    = { },
  -- video    = { },
  -- location = { },
  -- link     = { },
  -- event    = {
  --   { cond = { event = "CLICK或其他事件类型", 以及事件标识的全文匹配正则表达式 },
  --     resp = { msgtype = "text或其他消息类型", 以及对应消息所需的字段和内容 }
  --   },
  -- },
}

_M.autoreplyurl = "" -- 转发消息到指定URL, 对应服务可返回消息内容的JSON, 或直接返回success

return _M
