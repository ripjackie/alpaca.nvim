local vim = vim
local uv = vim.uv or vim.loop

AlpacaPath = vim.fn.stdpath("data") .. "/site/pack/alpaca"

local Plugins = {
  insert = function(self, plugin)
    table.insert(self, plugin)
  end
}

local git = {}

function git:init(plugin)
  local obj = vim.system({"git", "init", plugin.path}, { text = true }):wait()
  assert(obj.code == 0, "ERROR") -- TODO
  local obj = vim.system({"git", "remote", "add", "origin", "--no-tags" plugin.url}):wait()
  assert(obj.code == 0, "ERROR") -- TODO
end

function git:ls_remote(plugin)
  -- git ls-remote --refs --tags  --quiet --sort=-v:refname origin
  -- git ls-remote --refs --heads --quiet origin
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

local M = {}

M.tests = {
  setup_once = function()
    M.setup({
      { "sainnhe/everforest" }
    })
  end,
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
      git:clone(plugin)
      git:checkout(plugin)
    end
    Plugins:insert(plugin)
  end
  print(vim.inspect(Plugins))
end

vim.api.nvim_create_user_command("AlpacaUpdate", function()
  for _, plugin in ipairs(Plugins) do
    git:fetch(plugin)
    git:checkout(plugin)
  end
end, {})

vim.api.nvim_create_user_command("AlpacaClean", function()
  print("not implemented")
end, {})

return M
