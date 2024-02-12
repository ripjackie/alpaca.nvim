local uv = vim.uv or vim.loop
---@class PluginSpec
---@field [1] string plugin location (this only allows for git.)
---@field as string? plugin alias
---@field config function? plugin config to run on load
---@field build (function | string)? object to run after install / update
---@field branch string? branch to follow
---@field tag string? tag semver to follow
---@field event (string|string[])? lazy load on event(s)
---@field cmd (string|string[])? lazy load on user cmd(s)
---@field ft (string|string[])? lazy load on filetype(s)


---@class Plugin
---@field name string name / alias for plugin internally
---@field path string path plugin is installed to
---@field installed boolean if plugin is currently installed or not
---@field config function? function to run on plugin load
---@field build (function | string)? command to run after install / update
---@field branch string? branch to follow
---@field tag string? tag semver to follow
---@field event string[]? lazy load on events
---@field cmd string[]? lazy load on user cmds
---@field ft string[]? lazy load on filetypes
Plugin = {}

---@param spec PluginSpec
function Plugin:new(spec)
  ---@class Plugin
  local plugin = {}

  plugin.name = spec.as or vim.split(spec[1], '/')[2]
  plugin.url = "https://github.com/" .. spec[1] .. ".git"
  plugin.path = vim.fs.joinpath(AlpacaPath, ((spec.event or spec.cmd or spec.ft) and "opt" or "start"), plugin.name)
  plugin.installed = uv.fs_stat(plugin.path) and true or false

  plugin.branch = spec.branch
  plugin.tag = spec.tag

  plugin.config = spec.config
  plugin.build = spec.build

  plugin.event = spec.event and type(spec.event) ~= "table" and {spec.event} or spec.event --[=[@as string[]?]=]
  plugin.cmd = spec.cmd and type(spec.cmd) ~= "table" and {spec.cmd} or spec.cmd --[=[@as string[]?]=]
  plugin.ft = spec.ft and type(spec.ft) ~= "table" and {spec.ft} or spec.ft --[=[@as string[]?]=]

  self.__index = self
  return setmetatable(plugin, self)
end
