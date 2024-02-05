local vim = vim
local uv = vim.uv or vim.loop
local Git = require("git")

---@class PluginSpec
---@field [1] string
---@field as string?
---@field branch string?
---@field tag string?
---@field config function?
---@field event (string | string[])?
---@field cmd (string | string[])?
---@field ft (string | string[])?

---@class Plugin
---@field name string
---@field url string
---@field path string
---@field branch string?
---@field tag string?
---@field config function?
---@field event string[]?
---@field cmd string[]?
---@field ft string[]?
local Plugin = {}

---@param spec string | PluginSpec
function Plugin:new(spec)
  local to_array = function(inp) return type(inp) == "string" and {inp} or inp end
  spec = to_array(spec) --[[@as PluginSpec]]

  local plugin = setmetatable({}, self)
  self.__index = self

  plugin.branch = spec.branch
  plugin.tag = spec.tag

  plugin.config = spec.config

  plugin.event = spec.event and to_array(spec.event)
  plugin.cmd = spec.cmd and to_array(spec.cmd)
  plugin.ft = spec.ft and to_array(spec.ft)

  plugin.name = spec.as or vim.split(spec[1], "/")[2]
  plugin.url = "http://github.com/" .. spec[1]
  plugin.path = vim.fn.stdpath("data") .. "/site/pack/alpaca" .. ((spec.event or spec.cmd or spec.ft) and "/opt/" or "/start/") .. plugin.name

  return plugin

end

return Plugin
