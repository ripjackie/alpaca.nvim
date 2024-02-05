local vim = vim
local uv = vim.uv or vim.loop

local Git = require("git")

local Alpaca = {
  to_install = {},
  to_update = {},
  to_remove = {}
}

function Alpaca:install() vim.iter(ipairs(self.to_install)):map(function(_, plugin) return co.create(function()
      Git:init(plugin)
      Git:add_remote(plugin)
      Git:fetch(plugin)
      Git:checkout(plugin)
    end)
  end):each(function(coro)
    co.resume(coro)
  end)
end

---@param specs (string | PluginSpec)[]
function Alpaca:setup(specs)
  assert(specs and not vim.tbl_isempty(specs), "No Specs Supplied")
  vim.iter(specs):map(function(spec)
    return Plugin:new(spec)
  end):each(function(plugin)
    if not plugin.installed then
      table.insert(self.to_install, plugin)
    end
  end)

  self:install()
end

local M = {
  setup = coroutine.wrap(Alpaca.setup)
}

M.setup = coroutine.wrap(function(specs)
  Alpaca:setup(specs)
end)

M.setup({
  {
    "lukas-reineke/indent-blankline.nvim",
    tag = "v3.5.x"
  },
  {
    "altermo/ultimate-autopair.nvim",
    branch = "v0.6"
  }
})
