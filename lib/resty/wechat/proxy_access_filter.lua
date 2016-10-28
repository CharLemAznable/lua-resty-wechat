local modname = "wechat_proxy_access_filter"
local _M = { _VERSION = '0.0.1' }
_G[modname] = _M

local permitClientIPs = wechat_config.permitClientIPs or { "127.0.0.1" }

local function tableContainsValue(t, value)
  for k, v in pairs(t) do
    if value == v then return true end
  end
  return false
end

if not tableContainsValue(permitClientIPs, "127.0.0.1") then
  table.insert(permitClientIPs, "127.0.0.1")
end

local mt = {
  __call = function(_)
    local real_ip = ngx.req.get_headers()["X-Real-IP"]
    if not real_ip then real_ip = ngx.req.get_headers()["X-Forwarded-For"] end
    if not real_ip then real_ip = ngx.var.remote_addr end

    if not tableContainsValue(permitClientIPs, real_ip) then
      ngx.exit(ngx.HTTP_FORBIDDEN)
    end
  end,
}

return setmetatable(_M, mt)
