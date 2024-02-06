local vim = vim
local uv = vim.uv or vim.loop

AlpacaPath = vim.fn.stdpath("data") .. "/site/pack/alpaca"

local utils = {}

---@param cmd string
---@param args string[]
---@param cwd string?
---@param callback fun(ok: boolean, stdout: string?, stderr: string?): nil
function utils.spawn(cmd, args, cwd, callback)
  local stdio = { nil, uv.new_pipe(false), uv.new_pipe(false) }
  local buffers = {"", ""}
  local handle, pid

  handle, pid = uv.spawn(cmd, {
    args = args, cwd = cwd, stdio = stdio
  }, vim.schedule_wrap(function(code)
    handle:close()
    callback(code == 0, buffers[1], buffers[2])
  end))

  stdio[2]:read_start(function(err, data)
    if err then
      callback(false, nil, err)
    elseif data then
      buffers[1] = buffers[1] .. data
    else
      stdio[2]:close()
    end
  end)

  stdio[3]:read_start(function(err, data)
    if err then
      callback(false, nil, err)
    elseif data then
      buffers[2] = buffers[2] .. data
    else
      stdio[3]:close()
    end
  end)
end

---@param plugin Plugin
---@param callback fun(ok: boolean, stdout: string?, stderr: string?): nil
function utils:git_clone(plugin, callback)
  local args = { "clone", "--depth=1", "--recurse-submodules", "--shallow-submodules", plugin.url, plugin.path }
  self.spawn("git", args, nil, callback)
end

function utils.log(level, message)
  -- style is LEVEL | MESSAGE | TIMESTAMP
  -- so ERROR | Failed to spawn Git Spawn with args { init, ... } | 2024-08-02 3:07:45PM
end


---@class PluginSpec
---@field [1] string plugin location (this only allows for git.)
---@field as string? plugin alias
---@field config function? plugin config to run on load
---@field build (function | string)? object to run after install / update
---@field vers {branch: string?, tag: string?}? local repo versioning scheme ( tag allows semver using vim.version )
---@field opt {event: (string|string[])?, cmd: (string|string[])?, ft: (string|string[])?}? lazy loading & mechanisms


---@class Plugin
---@field name string name / alias for plugin internally
---@field path string path plugin is installed to
---@field installed boolean if plugin is currently installed or not
---@field spec PluginSpec spec associated with plugin
local Plugin = {}

---@param spec PluginSpec
function Plugin:new(spec)
  ---@class Plugin
  local plugin = {}

  plugin.name = spec.as or vim.split(spec[1], '/')[2]
  plugin.url = "https://github.com/" .. spec[1] .. ".git"
  plugin.path = vim.fs.joinpath(AlpacaPath, (spec.opt and "opt" or "start"), plugin.name)
  plugin.installed = uv.fs_stat(plugin.path) and true or false

  plugin.spec = spec

  self.__index = self
  return setmetatable(plugin, self)

end

local M = {}

function M.setup(specs)
  for _, spec in ipairs(specs) do
    spec = type(spec) ~= "table" and {spec} or spec
    local plugin = Plugin:new(spec)
    vim.print(plugin)
  end
end

return M
