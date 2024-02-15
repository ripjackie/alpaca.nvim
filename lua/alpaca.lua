local vim = vim
local uv = vim.uv or vim.loop

AlpacaPath = vim.fn.stdpath("data") .. "/site/pack/alpaca"
require("plugin")

local git = {}

---@param plugin Plugin
---@param callback fun(err: string?): nil
function git:clone(plugin, callback)
  local args = { "git", "clone", "--recurse-submodules", "--no-checkout", plugin.url, plugin.path }
  local opts = { text = true }
  vim.system(args, opts, function(obj)
    if obj.code == 0 then
      callback(nil)
    else
      callback(obj.stderr)
    end
  end)
end

---@param plugin Plugin
---@param callback fun(err: string?, tags: string?): nil
function git:list_tags(plugin, callback)
  local args = { "git", "tag", "--sort=-v:refname" }
  local opts = { text = true, cwd = plugin.path }
  vim.system(args, opts, function(obj)
    if obj.code ~= 0 then
      callback(obj.stderr, nil)
    else
      callback(nil, vim.gsplit(obj.stdout, '\n', { trimempty = true }))
    end
  end)
end

---@param plugin Plugin
---@param callback fun(err: string?): nil
function git:checkout_tag(plugin, callback)
  self:list_tags(plugin, function(err, tags)
    if err then callback(err) end

    local range = vim.version.range(plugin.tag)

    local new_tag
    for tag in tags do
      if range:has(tag) then
        new_tag = tag
      end
    end
    assert(new_tag, "ERR MSG") -- TODO

    local args = { "git", "checkout", new_tag }
    local opts = { text = true, cwd = plugin.path }
    vim.system(args, opts, function(obj)
      if obj.code ~= 0 then
        callback(obj.stderr)
      else
        callback(nil)
      end
    end)
  end)
end

---@param plugin Plugin
---@param callback fun(err: string?): nil
function git:checkout_branch(plugin, callback)
  local args = { "git", "checkout", plugin.branch }
  local opts = { text = true, cwd = plugin.path }
  print(vim.inspect(args))
  vim.system(args, opts, function(obj)
    if obj.code ~= 0 then
      vim.print(obj)
      callback(obj.stderr)
    else
      callback(nil)
    end
  end)
end

local Alpaca = {
  loaded = {},
  installed = {}
}

function Alpaca:install()
  for _, plugin in ipairs(self.loaded) do
    if not plugin:is_installed() then
      vim.print("Installing " .. plugin.name)
      git:clone(plugin, function(err)
        assert(not err, err)
        if plugin.tag then
          git:checkout_tag(plugin, function(err)
            assert(not err, err)
            vim.print("Finished Installing " .. plugin.name)
          end)
        else
          git:checkout_branch(plugin, function(err)
            assert(not err, err)
            vim.print("Finished Installing " .. plugin.name)
          end)
        end
      end)
    end
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
      { "sainnhe/everforest" },
      {
        "lukas-reineke/indent-blankline.nvim",
        tag = "v3.5.x"
      },
      {
        "altermo/ultimate-autopair.nvim",
        branch = "v0.6"
      }
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
  Alpaca:install()
end

vim.api.nvim_create_user_command("AlpacaUpdate", function()
  print("not implemented")
end, {})

vim.api.nvim_create_user_command("AlpacaClean", function()
  print("not implemented")
end, {})

return M
