local modname = "wechat_proxy_access_token"
local _M = { _VERSION = '0.0.1' }
_G[modname] = _M

local cjson = require("cjson")
local updateurl = "https://api.weixin.qq.com/cgi-bin/token?grant_type=client_credential&appid=" .. wechat_config.appid .. "&secret=" .. wechat_config.appsecret

function _M.process()
  local updateAccessToken
  updateAccessToken = function()
    _G[modname].redis = _G[modname].redis or require("resty.wechat.redis"):connect(wechat_config.redis)
    _G[modname].httpclient = _G[modname].httpclient or require("resty.wechat.http").new()

    _G[modname].redis:singleLockProcess("accessTokenLocker",
    function()
      local res, err = _G[modname].httpclient:request_uri(updateurl)
      if not res or err or tostring(res.status) ~= "200" then
        ngx.log(ngx.ERR, "failed to update access token: ", err or tostring(res.status))
        return
      end
      local resbody = cjson.decode(res.body)
      if not resbody.access_token then
        ngx.log(ngx.ERR, "failed to update access token: ", res.body)
        return
      end
      local ok, err = _G[modname].redis.redis:set(wechat_config.appid, resbody.access_token)
      if not ok then
        ngx.log(ngx.ERR, "failed to set access token: ", err)
      end
    end)

    local ok, err = ngx.timer.at(wechat_config.accessTokenUpdater or 5400, updateAccessToken) -- 1.5 hours timer
    if not ok then
      ngx.log(ngx.ERR, "failed to create the Access Token Updater: ", err)
      return
    end
  end

  local ok, err = ngx.timer.at(10, updateAccessToken) -- 1.5 hours timer
  if not ok then
    ngx.log(ngx.ERR, "failed to create the Access Token Updater: ", err)
    return
  end
end

return _M
