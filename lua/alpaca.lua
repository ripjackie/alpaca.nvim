local vim = vim
local uv = vim.uv or vim.loop

AlpacaPath = vim.fn.stdpath("data") .. "/site/pack/alpaca"
require("plugin")

local git = {}

---@param plugin Plugin
---@param callback fun(err: string?): nil
function git:clone(plugin, callback)
  local args = { "git", "clone", "--depth=1", "--recurse-submodules", "--shallow-submodules", "--no-checkout", plugin.url, plugin.path }
  
end

---@param plugin Plugin
---@param callback fun(err: string?): nil
function git:checkout_tag(plugin, callback)
end

---@param plugin Plugin
---@param callback fun(err: string?): nil
function git:checkout_branch(plugin, callback)
end

local Alpaca = {
  loaded = {},
  installed = {}
}

function Alpaca:install()
  print("Alpaca Install!")
  for _, plugin in ipairs(self.loaded) do
    ---@cast plugin Plugin
    if not plugin.installed then
      git:clone(plugin, function(err)
        assert(not err, err)
        if plugin.tag then
          git:checkout_tag(plugin, function(err)
          end)
        else
          git:checkout_branch(plugin, function(err)
          end)
        end
      end)
  end
end

function Alpaca:update()
  print("Alpaca Update!")
end

function Alpaca:load()
  print("Alpaca Load!")
end

function Alpaca:clean()
  print("Alpaca Clean!")
end

local M = {}

M.tests = {
  setup = function()
    M.setup({
      { "sainnhe/everforest" }
    })
  end,
  setup_many = function()
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
    table.insert(Alpaca.loaded, Plugin:new(spec))
  end
end

vim.api.nvim_create_user_command("AlpacaUpdate", function()
  print("not implemented")
end, {})

vim.api.nvim_create_user_command("AlpacaClean", function()
  print("not implemented")
end, {})

return M
