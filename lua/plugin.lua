local vim = vim
local uv = vim.uv or vim.loop
local git = require("git")

local PluginPath = vim.fn.stdpath("data") .. "/site/pack/alpaca"

---@class PluginSpec
---@field [1] string github short url
---@field as string? local filename alias
---@field build (string | function)?
---@field config function?
---@field branch string?
---@field tag string?
---@field event (string | string[])?
---@field cmd (string | string[])?
---@field ft (string | string[])?
---@field name string
---@field url string
---@field opt boolean
---@field path string

---@class PluginInstall
---@field repo string
---@field opt boolean
---@field path string
---@field commit string
---@field branch string?
---@field tag string?

---@class Plugin
---@field repo string
---@field spec PluginSpec?
---@field install PluginInstall?
---@field loaded boolean
---@field lazy boolean
local Plugin = {}

function Plugin:from_spec(spec)
  self.__index = self
  spec.url = ("https://github.com/%s.git"):format(spec[1])
  spec.name = spec.as or spec[1]:match("%C+/(%C+)")
  spec.opt = spec.opt or ( spec.event or spec.cmd or spec.ft ) and true or false
  spec.path = ("%s/%s/%s"):format(PluginPath, spec.opt and "opt" or "start", spec.name)
  return setmetatable({ repo = spec[1], spec = spec, loaded = false, lazy = spec.opt }, self)
end

function Plugin:from_install(install)
  self.__index = self
  return setmetatable({ repo = install.repo, install = install, loaded = false, lazy = install.opt }, self)
end

function Plugin:do_install(callback)
  if self.spec.tag then
    local ok, out = git.ls_remote_tags(self.spec)
    if ok then
      return git.clone(self.spec, out, callback)
    else
      return callback(ok, out)
    end
  else
    return git.clone(self.spec, self.spec.branch, callback)
  end
end

function Plugin:do_update(callback)
  return callback(false, "Not Implemented")
end

function Plugin:do_clean(callback)
  return callback(false, "Not Implemented")
end

function Plugin:do_load()
  if self.lazy then
    if self.spec.event then
      print("event")
    elseif self.spec.cmd then
      print("cmd")
    elseif self.spec.ft then
      print("ft")
    end
  else
    self:do_config()
  end
  self.loaded = true
end

function Plugin:do_build()
end

function Plugin:do_config()
  if self.spec.config and type(self.spec.config) == "function" then
    return vim.schedule(self.spec.config)
  end
end

return Plugin
