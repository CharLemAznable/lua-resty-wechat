local modname = "wechat_redis"
local _M = { _VERSION = '0.0.1' }
_G[modname] = _M
local mt = { __index = _M }

local ngx_now   = ngx.now
local ngx_sleep = ngx.sleep

function _M.connect(self, opt)
  local conf = {
    host = opt and opt.host or "127.0.0.1",
    port = opt and opt.port or 6379,
    timeout = opt and opt.timeout or 3000, -- 3s
    maxIdleTimeout = opt and opt.maxIdleTimeout or 10000,
    poolSize = opt and opt.poolSize or 10,
  }

  local redis = require("resty.redis"):new()
  redis:set_timeout(conf.timeout) -- 1 second
  local ok, err = redis:connect(conf.host, conf.port)
  if not ok then return nil end

  return setmetatable({ redis = redis, conf = conf }, mt)
end

function _M.close(self)
  local redis = self.redis
  local conf = self.conf
  return redis and redis:set_keepalive(conf.maxIdleTimeout, conf.poolSize)
end

function _M.singleLockProcess(self, key, proc)
  local current = ngx_now() * 1000
  local timeout = wechat_config.lockTimeout or 10
  local lock = self.redis:setnx(key, current + timeout * 1000 + 1)
  while not lock do
    local lockValue = self.redis:get(key)
    if not lockValue then
      return
    elseif ngx_now() * 1000 > tonumber(lockValue) and
           ngx_now() * 1000 > tonumber(self.redis:getset(key, ngx_now() * 1000 + timeout * 1000 + 1)) then
      break
    else ngx_sleep(timeout) end
  end
  proc() -- locked and do job
  if ngx_now() * 1000 < tonumber(self.redis:get(key) or 0) then
    self.redis:del(key)
  end
end

return _M
