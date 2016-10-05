local modname = "wechat_proxy_access_token"
local _M = { _VERSION = '0.0.1' }
_G[modname] = _M

local os_time       = os.time
local ngx_log       = ngx.log
local ngx_timer_at  = ngx.timer.at

local cjson = require("cjson")

local updateurl = "https://api.weixin.qq.com/cgi-bin/token?grant_type=client_credential&appid=" .. wechat_config.appid .. "&secret=" .. wechat_config.appsecret
local updateTime = wechat_config.accessTokenUpdateTime or 6000
local accessTokenKey = wechat_config.accessTokenKey or wechat_config.appid

function _M.process()
  local updateAccessToken
  updateAccessToken = function()
    require("resty.wechat.redis"):connect(wechat_config.redis):lockProcess(
      "accessTokenLocker",
      function(weredis)
        if os_time() < tonumber(weredis.redis:ttl(accessTokenKey) or 0) then
          return
        end

        local res, err = require("resty.wechat.http").new():request_uri(updateurl)
        if not res or err or tostring(res.status) ~= "200" then
          ngx_log(ngx.ERR, "failed to update access token: ", err or tostring(res.status))
          return
        end
        local resbody = cjson.decode(res.body)
        if not resbody.access_token then
          ngx_log(ngx.ERR, "failed to update access token: ", res.body)
          return
        end

        local ok, err = weredis.redis:setex(accessTokenKey, os_time() + updateTime - 1, resbody.access_token)
        if not ok then
          ngx_log(ngx.ERR, "failed to set access token: ", err)
          return
        end

        ngx_log(ngx.NOTICE, "succeed to set access token: ", res.body)
      end
    )

    local ok, err = ngx_timer_at(updateTime, updateAccessToken)
    if not ok then
      ngx_log(ngx.ERR, "failed to create the Access Token Updater: ", err)
      return
    end
  end

  local ok, err = ngx_timer_at(5, updateAccessToken)
  if not ok then
    ngx_log(ngx.ERR, "failed to create the Access Token Updater: ", err)
    return
  end
end

return _M
