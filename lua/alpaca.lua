local vim = vim
local uv = vim.uv or vim.loop

AlpacaPath = vim.fn.stdpath("data") .. "/site/pack/alpaca"
require("plugin")

local git = {}

---@param args string[]
---@param cwd string?
---@param callback fun(stderr: string?, stdout: string?): nil
function git:spawn(args, cwd, callback)
  vim.system(vim.list_extend({"git"}, args), { text = true, cwd = cwd }, function(obj)
    if obj.code == 0 then
      return callback(nil, obj.stdout)
    else
      return callback(obj.stderr, nil)
    end
  end)
end

---@param plugin Plugin
---@param callback fun(err: string?, tag: string?): nil
function git:find_newest_tag(plugin, callback)
  local args = {
    "for-each-ref", "refs/tags", "--sort=-v:refname", "--format=%(refname:short)"
  }
  self:spawn(args, plugin.path, function(stderr, stdout)
    if stderr then
      return callback(stderr, nil)
    else
      for tag in vim.gsplit(stdout, '\n', {trimempty = true}) do
        if plugin.range:has(tag) then
          return callback(nil, tag)
        end
      end
      return callback("No Valid Tag Was Found", nil)
    end
  end)
end

---@param plugin Plugin
---@param callback fun(err: string?, branch: string?): nil
function git:find_head_ref(plugin, callback)
  local args = {
    "symbolic-ref", "HEAD", "--short"
  }
  self:spawn(args, plugin.path, function(stderr, stdout)
    if stderr then
      return callback(stderr, nil)
    else
      return callback(nil, vim.trim(stdout))
    end
  end)
end


---@param plugin Plugin
---@param callback fun(err: string?): nil
function git:clone(plugin, callback)
  local args = {
    "clone", "--recurse-submodules", "--no-checkout", plugin.url, plugin.path
}
  self:spawn(args, nil, function(stderr)
    return callback(stderr)
  end)
end

---@param plugin Plugin
---@param callback fun(err: string?): nil
---@param refspec string?
function git:checkout(plugin, callback, refspec)
  if refspec then
    local args = { "checkout", refspec }
    return self:spawn(args, plugin.path, callback)
  elseif plugin.tag then
    self:find_newest_tag(plugin, function(err, tag)
      if err then
        return callback(err)
      elseif not tag then
        return callback("No Valid Tag Found")
      else
        return self:checkout(plugin, callback, tag)
      end
    end)
  elseif plugin.branch then
    return self:checkout(plugin, callback, plugin.branch)
  else
    self:find_head_ref(plugin, function(err, branch)
      if err then
        return callback(err)
      else
        return self:checkout(plugin, callback, branch)
      end
    end)
  end
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
        git:checkout(plugin, function(err)
          assert(not err, err)
          vim.print("Finished Installing " .. plugin.name)
        end)
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
