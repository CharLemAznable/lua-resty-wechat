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

local modname = "wechat_xml2lib"
local _M = { _VERSION = '0.0.2' }
_G[modname] = _M

local ffi = require "ffi"
local xml2lib = ffi.load("xml2")
local mt = { __index = xml2lib }

ffi.cdef[[
typedef unsigned char xmlChar;
typedef enum {
  XML_ELEMENT_NODE       = 1,
  XML_TEXT_NODE          = 3,
  XML_CDATA_SECTION_NODE = 4,
} xmlElementType;
struct _xmlNode {
  void *_private;
  xmlElementType type;
  const xmlChar *name;
  struct _xmlNode *children;
  struct _xmlNode *last;
  struct _xmlNode *parent;
  struct _xmlNode *next;
  struct _xmlNode *prev;
  struct _xmlDoc *doc;
  struct _xmlNs *ns;
  xmlChar *content;
  struct _xmlAttr *properties;
  struct _xmlNs *nsDef;
  void *psvi;
  unsigned short line;
  unsigned short extra;
};
struct _xmlDoc {
  void *_private;
  xmlElementType type;
  char *name;
  struct _xmlNode *children;
  struct _xmlNode *last;
  struct _xmlNode *parent;
  struct _xmlNode *next;
  struct _xmlNode *prev;
  struct _xmlDoc *doc;
  int compression;
  int standalone;
  struct _xmlDtd *intSubset;
  struct _xmlDtd *extSubset;
  struct _xmlNs *oldNs;
  const xmlChar *version;
  const xmlChar *encoding;
  void *ids;
  void *refs;
  const xmlChar *URL;
  int charset;
  struct _xmlDict *dict;
  void *psvi;
  int parseFlags;
  int properties;
};

struct _xmlDoc * xmlReadMemory(const char * buffe, int size, const char * URL, const char * encoding, int options);
void xmlFreeDoc(struct _xmlDoc * cur);
void xmlCleanupParser(void);
]]

function _M.newXmlDoc()
  return ffi.new("struct _xmlDoc *")
end

function _M.newXmlNode()
  return ffi.new("struct _xmlNode *")
end

return setmetatable(_M, mt)
