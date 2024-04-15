local uv = vim.uv or vim.loop
local git = require("git")
local Plugin = require("plugin")

AlpacaPath = vim.fn.stdpath("data") .. "/site/pack/alpaca"
AlpacaPlugins = {}

local installed = Plugin.list_installed()

local function to_array(input)
  if type(input) ~= "table" then
    return { input }
  else
    return input
  end
end

local function inject_alpaca(specs)
  if not vim.iter(specs):any(function(spec)
        return to_array(spec)[1] == "ripjackie/alpaca.nvim"
      end) then
    table.insert(specs, 1, "ripjackie/alpaca.nvim")
  end
end

local M = {}

function M.setup(specs)
  vim.validate({
    specs = { specs, "table" }
  })

  for _, spec in ipairs(specs) do
    if type(spec) == "string" then
      spec = { spec }
    end
    local plugin = Plugin:from_spec(spec)
    local local_plugin = installed[plugin.repo]

    if local_plugin == nil then
        plugin:install()
    elseif local_plugin.name ~= plugin.name or local_plugin.opt ~= plugin.opt then
        local local_opt_name = local_plugin.opt and "opt" or "start"
        local config_opt_name = plugin.opt and "opt" or "start"
        vim.notify(("[Alpaca.nvim] Moving %s/%s -> %s/%s"):format(local_opt_name, local_plugin.name, config_opt_name, plugin.name))
        uv.fs_rename(local_plugin.path, plugin.path)
    else
        plugin:check_for_updates()
    end

    if plugin.opt then
        plugin:lazy_load()
    else
        plugin:do_config()
    end
  end
end

return M
