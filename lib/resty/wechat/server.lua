--
-- This module is licensed under the BSD license.
--
-- Copyright (C) 2013-2014, by aCayF (潘力策) <plc1989@gmail.com>.
--
-- All rights reserved.
--
-- Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
--
-- * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
--
-- * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--

local modname = "wechat_server"
local _M = { _VERSION = '0.0.3' }
_G[modname] = _M

--------------------------------------------------pre defines

local ffi = require "ffi"
local ffi_str = ffi.string

local hex = require "resty.wechat.utils.hex"
local xml2lib = require "resty.wechat.utils.xml2lib"

local rcvmsgfmt = {
  common  = { "tousername", "fromusername", "createtime", "msgtype" },
  msgtype = {
    text     = { "content", "msgid" },
    image    = { "picurl", "msgid", "mediaid" },
    voice    = { "mediaid", "format", "msgid", { "recognition" } },
    video    = { "mediaid", "thumbmediaid", "msgid" },
    location = { "location_x", "location_y", "scale", "label", "msgid" },
    link     = { "title", "description", "url", "msgid" },
    event    = { "event" }
  },
  event   = {
    subscribe   = { { "eventkey" }, { "ticket" } },
    scan        = { "eventkey", "ticket" },
    unsubscribe = { { "eventkey" } },
    location    = { "latitude", "longitude", "precision" },
    click       = { "eventkey" },
    view        = { "eventkey", "menuid" }
  }
}

local elementnode = "e"
local textnode    = "t"
local cdatanode   = "c"

local sndmsgfmt = {
  common = {
    { "ToUserName", cdatanode },
    { "FromUserName", cdatanode },
    { "CreateTime", textnode },
    { "MsgType", cdatanode }
  },
  text   = {
    { "Content", cdatanode }
  },
  image  = {
    { "Image", elementnode, { { "MediaId", cdatanode } } }
  },
  voice  = {
    { "Voice", elementnode, { { "MediaId", cdatanode } } }
  },
  video  = {
    { "Video", elementnode, {
      { "MediaId", cdatanode },
      { "Title", cdatanode, optional = true },
      { "Description", cdatanode, optional = true } }
    }
  },
  music  = {
    { "Music", elementnode, {
      { "Title", cdatanode, optional = true },
      { "Description", cdatanode, optional = true },
      { "MusicUrl", cdatanode, optional = true },
      { "HQMusicUrl", cdatanode, optional = true },
      { "ThumbMediaId", cdatanode, optional = true } }
    }
  },
  news   = {
    { "ArticleCount", textnode },
    { "Articles", elementnode, {
      { "item", elementnode, {
        { "Title", cdatanode, optional = true },
        { "Description", cdatanode, optional = true },
        { "PicUrl", cdatanode, optional = true },
        { "Url", cdatanode, optional = true } }
      } }
    }
  },
}

local table_sort      = table.sort
local table_concat    = table.concat
local string_lower    = string.lower
local string_match    = string.match
local string_format   = string.format
local string_gsub     = string.gsub
local ngx_re_gsub     = ngx.re.gsub
local ngx_req         = ngx.req
local ngx_log         = ngx.log
local ngx_print       = ngx.print
local ngx_exit        = ngx.exit

local cjson = require("cjson")

--------------------------------------------------private methods

local function _check_signature(params)
  local signature = params.signature
  local timestamp = params.timestamp
  local nonce = params.nonce
  local token = params.token
  local tmptab = {token, timestamp, nonce}
  table_sort(tmptab)

  local tmpstr = table_concat(tmptab)
  tmpstr = ngx.sha1_bin(tmpstr)
  tmpstr = hex(tmpstr)

  if tmpstr ~= signature then
    return nil, "signature mismatch"
  end

  return true
end

local function _verify_request_params(params)
  if params.method == "GET" and not params.echostr then
    return nil, "missing echostr"
  end
  return _check_signature(params)
end

--------------------------------------------------

local function _parse_key(nodePtr, key, rcvmsg)
  local node = nodePtr.node
  local name = ffi_str(node[0].name)
  local optional = (type(key) == "table")
  local k = optional and key[1] or key

  if string_lower(name) ~= k then -- case insensitive
    if not optional then
      return nil, "invalid node name -- " .. name
    else
      return true
    end
  end

  if node[0].type ~= xml2lib.XML_ELEMENT_NODE then
    return nil, "invalid node type"
  end

  node = node[0].children
  if node == nil then
    return nil, "invalid subnode"
  end

  if node[0].type ~= xml2lib.XML_TEXT_NODE and node[0].type ~= xml2lib.XML_CDATA_SECTION_NODE then
    return nil, "invalid subnode type"
  end

  rcvmsg[k] = ffi_str(node[0].content)

  node = node[0].parent
  if node[0].next ~= nil then
    node = node[0].next
  end
  nodePtr.node = node

  return rcvmsg[k]
end

local function _parse_keytable(nodePtr, keytable, rcvmsg)
  for i = 1, #keytable do
    local key = keytable[i]

    local value, err = _parse_key(nodePtr, key, rcvmsg)
    if err then
      return nil, err
    end
  end

  return true
end

local function _retrieve_keytable(nodePtr, key, rcvmsg)
  local root = rcvmsgfmt.msgtype

  while true do
    if not root[key] then
      return nil, "invalid key -- " .. key
    end

    -- indicates that no subkeys present
    if not rcvmsgfmt[key] then
      break
    end

    local value, err = _parse_key(nodePtr, key, rcvmsg)
    if err then
      return nil, err
    end

    root = rcvmsgfmt[key]
    key = string_lower(value) -- case insensitive
  end

  return root[key]
end

local function _parse_xml(node, rcvmsg)
  local keytable, ok, err

  -- element node named xml is expected
  if node[0].type ~= xml2lib.XML_ELEMENT_NODE or ffi_str(node[0].name) ~= "xml" then
    return nil, "invalid xml title when parsing xml"
  end

  if node[0].children == nil then
    return nil, "invalid xml content when parsing xml"
  end

  -- parse common components
  local nodePtr = { node = node[0].children }
  keytable = rcvmsgfmt.common

  ok, err = _parse_keytable(nodePtr, keytable, rcvmsg)
  if not ok then
    return nil,  err .. " when parsing common part"
  end

  -- retrieve msgtype-specific keytable
  keytable, err = _retrieve_keytable(nodePtr, rcvmsg.msgtype, rcvmsg)
  if err then
    return nil, err .. " when retrieving keytable"
  end

  -- parse msgtype-specific components
  ok, err = _parse_keytable(nodePtr, keytable, rcvmsg)
  if not ok then
    return nil, err .. " when parsing msgtype-specific part"
  end

  return true
end

local function _parse_request_body(params)
  if not params.body then
    return nil, "invalid request body"
  end

  local doc = xml2lib.newXmlDoc()
  local node = xml2lib.newXmlNode()
  local body = params.body
  local rcvmsg = params.rcvmsg

  doc = xml2lib.xmlReadMemory(body, #body, nil, nil, 0)
  if doc == nil then
    return nil, "invalid xml data"
  end

  -- root node
  node = doc[0].children
  local ok, err = _parse_xml(node, rcvmsg)

  -- cleanup used memory anyway
  xml2lib.xmlFreeDoc(doc)
  xml2lib.xmlCleanupParser()

  if not ok then
    return nil, err
  end

  return rcvmsg
end

--------------------------------------------------

local function _match_auto_reply(rcvmsg)
  local autoreply = wechat_config.autoreply or {}

  local replies = autoreply[rcvmsg.msgtype]
  if not replies or #replies == 0 then
    return nil
  end

  for i = 1, #replies do
    local reply = replies[i]
    if reply.cond and reply.resp then
      local match = true
      for k, v in pairs(reply.cond) do
        if string_match(rcvmsg[k], v) ~= rcvmsg[k] then -- case sensitive
          match = false
          break
        end
      end

      if match then
        return reply.resp, reply.continue
      end
    end
  end

  return nil
end

--------------------------------------------------

local function _insert_items(n)
  local newsfmts = sndmsgfmt["news"]
  local node = newsfmts[2]
  local tb = node[3]

  for i = 1, n - 1 do
    local item = { "item", elementnode, {
      { "Title" .. i, cdatanode, optional = true },
      { "Description" .. i, cdatanode, optional = true },
      { "PicUrl" .. i, cdatanode, optional = true },
      { "Url" .. i, cdatanode, optional = true } }
    }
    -- push
    tb[#tb + 1] = item
  end
end

local function _cleanup_items(n)
  local newsfmts = sndmsgfmt["news"]
  local node = newsfmts[2]
  local tb = node[3]

  for i = 1, n - 1 do
    tb[#tb] = nil
  end
end

local function _normalize_items(str)
  str = ngx_re_gsub(str, "Title[1-9]>", "Title>")
  str = ngx_re_gsub(str, "Description[1-9]>", "Description>")
  str = ngx_re_gsub(str, "PicUrl[1-9]>", "PicUrl>")
  str = ngx_re_gsub(str, "Url[1-9]>", "Url>")
  return str
end

local function _retrieve_content(sndmsg, fmt)
  local name = string_lower(fmt[1])
  local content = sndmsg[name] or ""
  local optional = fmt.optional

  if not optional and content == "" then
    return nil, "missing required argment -- " .. name
  end
  return content
end

local function _build_xml_table(sndmsg, fmts, resultable)
  local count = #resultable
  for i = 1, #fmts do
    local fmt = fmts[i]
    local name = fmt[1]
    local nodetype = fmt[2]
    local subfmts = fmt[3]
    local content, err

    if nodetype == elementnode then
      content = {}
      err = _build_xml_table(sndmsg, subfmts, content)
      if err then
        return err
      end

      if #content ~= 0 then
        count = count + 1
        resultable[count] = string_format("<%s>", name)

        for i, v in ipairs(content) do
          count = count + 1
          resultable[count] = v
        end

        count = count + 1
        resultable[count] = string_format("</%s>", name)
      end

    elseif nodetype == textnode then
      content, err = _retrieve_content(sndmsg, fmt)
      if err then
        return err
      end

      if content ~= "" then
        resultable[count + 1] = string_format("<%s>", name)
        resultable[count + 2] = content
        resultable[count + 3] = string_format("</%s>", name)
        count = count + 3
      end

    elseif nodetype == cdatanode then
      content, err = _retrieve_content(sndmsg, fmt)
      if err then
        return err
      end

      if content ~= "" then
        resultable[count + 1] = string_format("<%s>", name)
        resultable[count + 2] = string_format("<![CDATA[%s]]>", content)
        resultable[count + 3] = string_format("</%s>", name)
        count = count + 3
      end
    end
  end

  return nil
end

local function _build_response_body(rcvmsg, sndmsg)
  local msgtype = sndmsg.msgtype
  local fmts = sndmsgfmt[msgtype]
  local n = tonumber(sndmsg.articlecount or 0)
  local xmltable, stream, err

  n = n > 10 and 10 or n

  if not fmts then
    return nil, "invalid msgtype"
  end

  if not rcvmsg.fromusername or not rcvmsg.tousername then
    return nil, "invalid recieve message"
  end

  sndmsg.tousername = rcvmsg.fromusername
  sndmsg.fromusername = rcvmsg.tousername
  sndmsg.createtime = tostring(os.time())

  if n > 1 then
    _insert_items(n)
  end

  xmltable = { "<xml>" }
  err = _build_xml_table(sndmsg, sndmsgfmt.common, xmltable)
  if err then
    return nil, err
  end
  err = _build_xml_table(sndmsg, fmts, xmltable)
  if err then
    return nil, err
  end
  xmltable[#xmltable + 1] = "</xml>"
  stream = table_concat(xmltable)

  if n > 1 then
    stream = _normalize_items(stream)
    _cleanup_items(n)
  end

  -- parametric by rcvmsg
  stream = string_gsub(stream, "%${([^}]+)}", rcvmsg)

  return stream
end

--------------------------------------------------public methods

local mt = {
  __call = function(_)
    -- request arguments
    local args = ngx_req.get_uri_args()
    -- request method
    local method = ngx_req.get_method()
    -- request body
    ngx_req.read_body()
    local body = ngx_req.get_body_data()
    if body then
      body = ngx_re_gsub(body, "[\r\n]*", "", "i")
    end

    local params = {
      signature = args.signature,
      timestamp = args.timestamp,
      nonce = args.nonce,
      echostr = args.echostr,
      token = wechat_config.token,
      method = method,
      body = body,
      rcvmsg = {}
    }

    local ok, err, rcvmsg, reply, sndmsg, res
    ok, err = _verify_request_params(params)
    if not ok then
      ngx_log(ngx.ERR, "failed to verify server: ", err)
      return ngx_exit(ngx.HTTP_BAD_REQUEST)
    end

    if params.method == "GET" then -- just verify
      ngx_print(params.echostr)
      return ngx_exit(ngx.HTTP_OK)
    end

    rcvmsg, err = _parse_request_body(params)
    if err then
      ngx_log(ngx.ERR, "failed to parse message: ", err)
      return ngx_exit(ngx.HTTP_BAD_REQUEST)
    end

    reply, continue = _match_auto_reply(rcvmsg)
    if reply then
      sndmsg, err = _build_response_body(rcvmsg, reply)
      if err then
        ngx_log(ngx.ERR, "failed to build message: ", err)
        return ngx_exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
      end
      ngx_print(sndmsg)
      if not continue then return ngx_exit(ngx.HTTP_OK) end
    end

    if wechat_config.autoreplyurl and wechat_config.autoreplyurl ~= "" then
      res, err = require("resty.wechat.utils.http").new():request_uri(wechat_config.autoreplyurl, {
        method = "POST", body = cjson.encode(rcvmsg),
        headers = { ["Content-Type"] = "application/json" },
      })
      if not res or err or tostring(res.status) ~= "200" then
        ngx.log(ngx.ERR, "failed to request auto reply URL ", wechat_config.autoreplyurl, ": ", err or tostring(res.status))
        return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
      end

      if not reply and res.body and res.body ~= "" and string_lower(res.body) ~= "success" then
        sndmsg, err = _build_response_body(rcvmsg, cjson.decode(res.body))
        if err then
          ngx.log(ngx.ERR, "failed to build message: ", err)
          return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
        end
        ngx_print(sndmsg)
        return ngx.exit(res.status)
      end
    end

    if not reply then ngx_print("success") end
    return ngx_exit(ngx.HTTP_OK)
  end,
}

return setmetatable(_M, mt)
