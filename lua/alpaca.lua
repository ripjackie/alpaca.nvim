local vim = vim
local uv = vim.uv or vim.loop

AlpacaPath = vim.fn.stdpath("data") .. "/site/pack/alpaca"

local utils = {}

---@param cmd string
---@param args string[]
---@param cwd string?
---@param callback fun(stdout: string?, stderr: string?): nil
function utils.spawn(cmd, args, cwd, callback)
  local stdio = { nil, uv.new_pipe(false), uv.new_pipe(false) }

  ---@param pipe table
  ---@param callback fun(err: string?, data: string?): nil
  local function read_pipe(pipe, callback)
    local buffer = ""
    pipe:read_start(function(err, data)
      if err then
        callback(err, nil)
      elseif data then
        buffer = buffer .. data
      else
        callback(nil, buffer)
      end
    end)
  end

  local function on_exit()
    read_pipe(stdio[2], function(err, stdout)
      if err then callback(nil, err) end
      read_pipe(stdio[3], function(err, stderr)
        if err then callback(nil, err) end
        callback(stdout, stderr)
      end)
    end)
  end

  local handle, pid = uv.spawn(cmd, {
    args = args, cwd = cwd, stdio = stdio
  }, on_exit)
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
