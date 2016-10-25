local modname = "wechat_hex"
local _M = { _VERSION = '0.0.1' }
_G[modname] = _M

local ffi = require "ffi"
local str_type = ffi.typeof("uint8_t[?]")
local ffi_str = ffi.string

ffi.cdef[[
typedef unsigned char u_char;
u_char * ngx_hex_dump(u_char *dst, const u_char *src, size_t len);
]]

local mt = {
  __call = function(_, s)
    local len = #s * 2
    local buf = ffi.new(str_type, len)
    ffi.C.ngx_hex_dump(buf, s, #s)
    return ffi_str(buf, len)
  end
}

return setmetatable(_M, mt)
