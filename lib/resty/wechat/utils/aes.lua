local modname = "wechat_aes"
local _M = { _VERSION = '0.0.1' }
_G[modname] = _M
local mt = { __index = _M }

local resty_aes = require("resty.aes")

function _M.new(key)
  if not key or #key ~= 16 then
    return nil, "bad key length: need be 16"
  end
  return resty_aes:new(key, nil, resty_aes.cipher(128, "ecb"), {iv=key})
end

return _M
