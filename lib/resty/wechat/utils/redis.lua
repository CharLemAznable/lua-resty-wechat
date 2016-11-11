local modname = "wechat_redis"
local _M = { _VERSION = '0.0.1' }
_G[modname] = _M
local mt = { __index = _M }

local ngx_now   = ngx.now
local ngx_sleep = ngx.sleep

local function defaultReplyValue(originValue, defaultValue)
  if originValue and originValue ~= null and originValue ~= ngx.null then
    return originValue
  end
  return defaultValue
end

function _M.connect(self, opt)
  local conf = {
    host = opt and opt.host or "127.0.0.1",
    port = opt and opt.port or 6379,
    timeout = opt and opt.timeout or 5000,
    maxIdleTimeout = opt and opt.maxIdleTimeout or 10000,
    poolSize = opt and opt.poolSize or 10,
    distributedLockTimeout = opt and opt.distributedLockTimeout or 20,
  }

  local redis = require("resty.redis"):new()
  redis:set_timeout(conf.timeout)
  local ok, err = redis:connect(conf.host, conf.port)
  if not ok then return nil end

  return setmetatable({ redis = redis, conf = conf }, mt)
end

function _M.keepalive(self, maxIdleTimeout, poolSize)
  local redis = self.redis
  local conf = self.conf
  return redis and redis:set_keepalive(maxIdleTimeout or conf.maxIdleTimeout, poolSize or conf.poolSize)
end

function _M.close(self)
  local redis = self.redis
  return redis and redis:close()
end

function _M.lockProcess(self, key, proc)
  -- lock expire time
  local timeout = self.conf.distributedLockTimeout
  -- distributed lock
  local lock = nil
  while not lock do
    lock = self.redis:setnx(key, ngx_now() * 1000 + timeout * 1000 + 1)
    if defaultReplyValue(lock, nil) then break end

    local locktime = self.redis:get(key)
    if ngx_now() * 1000 > tonumber(defaultReplyValue(locktime, nil) or 0) then -- if lock timeout, try to get lock.
      local origin_locktime = self.redis:getset(key, ngx_now() * 1000 + timeout * 1000 + 1) -- set new lock timeout.
      if ngx_now() * 1000 > tonumber(defaultReplyValue(origin_locktime, nil) or 0) then break end -- if origin lock timeout, lock get.
    end
    ngx_sleep(timeout)
  end
  -- locked and do job
  pcall(proc, self)
  -- unlocked if needed
  if ngx_now() * 1000 < tonumber(defaultReplyValue(self.redis:get(key), nil) or 0) then
    self.redis:del(key)
  end
end

return _M
