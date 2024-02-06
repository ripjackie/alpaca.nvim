local vim = vim
local uv = vim.uv or vim.loop

local git = {}

---@param plugin Plugin
---@param callback function?
function git:clone(plugin, callback)
  local args = { "git", "clone", "--depth=1", "--recurse-submodules", "--shallow-submodules", plugin.url, plugin.path }
  vim.system(args, { text = true }, function(obj)
    print(vim.inspect(obj))
  end)
end

function git:fetch(plugin, callback)
end

function git:checkout(plugin, callback)
end

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

function Plugin

---@return boolean
function Plugin:installed()
  return uv.fs_stat(self.path) ~= nil
end

---@return boolean
function Plugin:updated()
  vim.system({ "git", "fetch", "origin" }, { cwd = self.path }):wait()
  if self.tag then
    local obj = vim.system({
      "git", "for-each-ref", "refs/tags", "--no-merged=HEAD", "--sort=-v:refname", "--format=%(refname:short)"
    }, { cwd = self.path }):wait()
    assert(obj.stderr == "", obj.stderr)
    local range = vim.version.range(self.tag)
    for _, ref in ipairs(vim.split(obj.stdout, '\n')) do
      if range:has(ref) then
        return false
      end
    end
    return true
  else
    local obj = vim.system({
      "git", "for-each-ref", "refs/heads", "--contains=HEAD", "--format=%(upstream:trackshort)"
    }, { cwd = self.path }):wait()
    assert(obj.stderr == "", obj.stderr)
    if string.find(obj.stdout, '<') then
      return false
    else
      return true
    end
  end
end

local Alpaca = {
  plugins = {},
  to_install = {},
  to_update = {},
  to_remove = {}
}

---@param plugin Plugin
---@param callback fun(err: string?): nil
function Alpaca:install(plugin, callback)
  git:clone(plugin, function(err)
    if err then
      callback(err)
    else
      git:checkout(plugin, callback)
    end
  end)
end

---@param plugin Plugin
---@param callback fun(err: string?): nil
function Alpaca:update(plugin, callback)
  git:fetch(plugin, function(err)
    if err then
      callback(err)
    else
      git:checkout(plugin, callback)
    end
  end)
end

function Alpaca:clean()
end

function Alpaca:load()
end

function Alpaca:create_autocmds()
  vim.api.nvim_create_autocmd("AlpacaUpdate", {})
  vim.api.nvim_create_autocmd("AlpacaClean", {})
end


local M = {}

---@param specs (string | PluginSpec)[]
function M.setup(specs)
  local total = 0
  local counter = 0
  vim.iter(ipairs(specs)):each(function(_, spec)
    local plugin = Plugin:new(spec)
    if not plugin:installed() then
      total = total + 1
      Alpaca:install(plugin, function(err)
        counter = counter + 1
        if err then
          print(string.format("[Alpaca.nvim] [%d/%d] [install] [%s] [FAIL] %s", counter, total, plugin.name, err))
        else
          print(string.format("[Alpaca.nvim] [%d/%d] [install] [%s]", counter, total, plugin.name))
          plugin:load()
        end
      end)
    end
  end)
end

return M
