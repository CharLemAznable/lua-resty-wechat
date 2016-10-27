local modname = "wechat_jssdk_config"
local _M = { _VERSION = '0.0.1' }
_G[modname] = _M

local random = require("resty.wechat.utils.random")
local hex = require("resty.wechat.utils.hex")
local cjson = require("cjson")

local table_insert = table.insert
local table_sort = table.sort
local table_concat = table.concat
local ngx_req = ngx.req

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

local function get_request_args()
  local request_method = ngx.var.request_method
  if "GET" == request_method then
    return ngx_req.get_uri_args()
  elseif "POST" == request_method then
    ngx_req.read_body()
    return ngx_req.get_post_args()
  end
  return {}
end

local mt = {
  __call = function(_, url_param_name, api_list_param_name)
    local noncestr = random.token(16)
    local jsapi_ticket = require("resty.wechat.utils.redis"):connect(wechat_config.redis).redis:get(jsapiTicketKey)
    local timestamp = os.time()

    local args = get_request_args()
    local url = args[url_param_name or "url"] or ""
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
    local api_list_param = args[api_list_param_name or "api"]
    if api_list_param then
      result["jsApiList"] = string_split(api_list_param, "|")
    end

    ngx.header["Content-Type"] = "application/json"
    ngx.print(cjson.encode(result))
    return ngx.exit(ngx.HTTP_OK)
  end,
}

return setmetatable(_M, mt)
