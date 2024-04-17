local vim = vim
local uv = vim.uv or vim.loop
local Plugin = require("plugin")
local git = require("git")

local function to_array(input)
    if type(input) ~= "table" then
        return {input}
    else
        return input
    end
end

Alpaca = {
    path = vim.fn.stdpath("data") .. "/site/pack/alpaca",
    installs = {},
    configs = {},
    parse_installs = function(self)
        for repo_path, filetype in vim.fs.dir(self.path, { depth = 2 }) do
            if filetype == "directory" and repo_path:find('/') then
                local repo, data = self.parse_repo(self.path .. '/' .. repo_path)
                self.installs[repo] = data
            end
        end
    end,
    parse_configs = function(self, specs)
        vim.validate({specs = { specs, "table" }})
        for _, spec in ipairs(specs) do
            spec = to_array(spec)
            local config = Plugin:new(spec)
            local install = self.installs[config.repo]
            if install then
                if install.name ~= config.name then
                    local msg = "[Alpaca.nvim] Renaming %s -> %s"
                    vim.notify(msg:format(install.name, config.name))
                    uv.fs_rename(install.path, config.path)
                    self.installs[config.repo] = self.parse_repo(config.path)
                end
                if install.opt ~= config.opt then
                    local msg = "[Alpaca.nvim] Lazy Load %d for plugin %s"
                    vim.notify(msg:format(config.opt and "enabled" or "disabled", config.name))
                    uv.fs_rename(install.path, config.path)
                    self.installs[config.repo] = self.parse_repo(config.path)
                end

                config:load()
            else
                config:install()
                config:run_build()
                config:load()
            end
        end
    end,
    parse_repo = function(full_path)
        local plugin_name = vim.fs.basename(full_path)
        local plugin_opt = vim.fs.basename(vim.fs.dirname(full_path)) == "opt" and true or false
        local repo_head = git.get_head_refs(full_path)
        local repo_name = git.get_remote_repo(full_path)
        return repo_name, {
            name = plugin_name,
            opt = plugin_opt,
            path = full_path,
            commit = repo_head.commit,
            branch = repo_head.branch,
            tag = repo_head.tag
        }
    end
}

Alpaca:parse_installs()

local M = {}

function M.setup(specs)
    Alpaca:parse_configs(specs)
end

return M
