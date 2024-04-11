local uv = vim.uv or vim.loop
local git = require("git")
local Plugin = require("plugin")

AlpacaPath = vim.fn.stdpath("data") .. "/site/pack/alpaca"

local installed = Plugin.list_installed()

function to_array(input)
    if type(input) ~= "table" then
        return {input}
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

    inject_alpaca(specs)

    vim.iter(specs):map(function(spec)
        return Plugin:from_spec(spec)
    end):each(function(plugin)
        local local_plugin = installed[plugin.repo]
        print(plugin.name)
        if not local_plugin then
            plugin:install()
        else
            if local_plugin.name ~= plugin.name then
                -- rename local plugin dir
                vim.notify(("[Alpaca.nvim] Renaming %s -> %s"):format(local_plugin.name, plugin.name))
                uv.fs_rename(local_plugin.path, plugin.path)
                local_plugin.name = plugin.name
            end
            if local_plugin.opt ~= plugin.opt then
                -- move start <-> opt
                vim.notify(("[Alpaca.nvim] %s lazy-load for %s"):format(plugin.opt and "enabling" or "disabling", plugin.name))
                uv.fs_rename(local_plugin.path, plugin.path)
                local_plugin.opt = plugin.opt
            end
            plugin:get_updates(local_plugin.version)
            plugin:load()
        end
    end)
end

return M
