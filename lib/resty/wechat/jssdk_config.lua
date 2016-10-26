local modname = "wechat_jssdk_config"
local _M = { _VERSION = '0.0.1' }
_G[modname] = _M

local random = require("resty.wechat.utils.random")
local hex = require("resty.wechat.utils.hex")
local urlcodec = require("resty.wechat.utils.urlcodec")
local cjson = require("cjson")

local table_insert = table.insert
local table_sort = table.sort
local table_concat = table.concat

local jsapiTicketKey = wechat_config.jsapiTicketKey or (wechat_config.appid .. "_ticket")

local function string_split(str, delimiter)
  if str == nil or str == '' or delimiter == nil then
    return nil
  end

  local result = {}
  for match in (str..delimiter):gmatch("(.-)"..delimiter) do
    table_insert(result, match)
  end
  return result
end

local mt = {
  __call = function(_, url_param_name, api_list_param_name)
    local noncestr = random.token(16)
    local jsapi_ticket = require("resty.wechat.utils.redis"):connect(wechat_config.redis).redis:get(jsapiTicketKey)
    local timestamp = os.time()
    local url = urlcodec.decodeURI(ngx.var["arg_" .. (url_param_name or "url")])
    url = string_split(url, "#")[1]

    local tmptab = {}
    table_insert(tmptab, "noncestr=" .. noncestr)
    table_insert(tmptab, "jsapi_ticket=" .. jsapi_ticket)
    table_insert(tmptab, "timestamp=" .. timestamp)
    table_insert(tmptab, "url=" .. url)
    table_sort(tmptab)
    local signature = hex(ngx.sha1_bin(table_concat(tmptab, "&")))

    local result = {
      appId = wechat_config.appid,
      timestamp = timestamp,
      nonceStr = noncestr,
      signature = signature,
    }
    local api_list_param = ngx.var["arg_" .. (api_list_param_name or "api")]
    if api_list_param then
      result["jsApiList"] = string_split(urlcodec.decodeURI(api_list_param), "|")
    end

    ngx.say(cjson.encode(result))
  end,
}

return setmetatable(_M, mt)
