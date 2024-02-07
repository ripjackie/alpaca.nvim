local vim = vim
local uv = vim.uv or vim.loop

AlpacaPath = vim.fn.stdpath("data") .. "/site/pack/alpaca"
AlpacaLog  = vim.fn.stdpath("cache") .. "/alpaca.log"

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
  local file = assert(io.open(AlpacaLog, 'w'))
  file:write(string.format("%s | %s | %s", string.upper(level), message, os.date('%c', os.time())))
  file:close()
end

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
local Plugin = {}

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

function Plugin:check_updates(callback)
  if self.tag then
    -- get current tag ( git describe --tags --exact-match )
    -- get remote tags ( git ls-remote --refs --tags --sort=-v:refname --quiet origin )
    -- if there is a newer remote tag that follows the plugin.tag semver, return true
    print()
  elseif self.branch then
    -- get current head ( git rev-parse [HEAD?] )
    -- get current symbolic-ref (may not be needed) ( git symbolic-ref HEAD )
    -- get current remote head ( git ls-remote --refs --heads --quiet plugin.branch ( symbolic-ref? ) )
    -- if remote head is different, return true
    print()
  else
    -- get current head ( git rev-parse HEAD )
    -- get current head ( git rev-parse [HEAD?] )
    -- get current symbolic-ref (may not be needed) ( git symbolic-ref HEAD )
    -- get current remote head ( git ls-remote --refs --heads --quiet plugin.branch ( symbolic-ref? ) )
    -- if remote head is different, return true
    print()
  end
end

local M = {}

M.tests = {
  setup = function()
    M.setup({
      { "sainnhe/everforest" },
      {
        "catppuccin/nvim",
        as = "catppuccin"
      },
      {
        "lukas-reineke/indent-blankline.nvim",
        event = "BufEnter",
        tag = "v3.5.x",
        config = function()
          require("ibl").setup({})
        end
      },
      {
        "altermo/ultimate-autopair.nvim",
        event = { "InsertEnter", "CmdlineEnter" },
        branch = "v0.6",
        config = function()
          require("ultimate-autopair").setup({})
        end
      },
      {
        "nvim-treesitter/nvim-treesitter",
        build = ":TSUpdate",
        config = function()
          require("nvim-treesitter.configs").setup({
            ensure_installed = { "lua", "vimdoc", "query", "markdown", "markdown_inline" },
            highlight = { enable = true },
            indent = { enable = true }
          })
        end
      },
      {
        "zaldih/themery.nvim",
        cmd = "Themery",
        config = function()
          require("themery").setup({
            themes = require("themes"),
            themeConfigFile = vim.fn.stdpath("config") .. "/lua/theme.lua",
            livePreview = true
          })
        end
      }
    })
  end
}

---@param specs (string | PluginSpec)[]
function M.setup(specs)
  for _, spec in ipairs(specs) do
    spec = type(spec) ~= "table" and {spec} or spec --[[@as PluginSpec]]
    local plugin = Plugin:new(spec)
    vim.print(plugin)
    if not plugin.installed then

    end
  end
end

return M
