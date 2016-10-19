local modname = "wechat_uri"
local _M = { _VERSION = '0.0.1' }
_G[modname] = _M

local function escape(c)
  return string.format("%%%02X", string.byte(c))
end

local function unescape(h)
  return string.char(tonumber(h, 16))
end

function _M.encodeURI(s)
  local result = string.gsub(s, "([^%w%.%-])", escape)
  return result
end

function _M.decodeURI(s)
  local result = string.gsub(s, "%%(%x%x)", unescape)
  return result
end

return _M
