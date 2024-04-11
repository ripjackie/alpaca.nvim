local uv = vim.uv or vim.loop
local git = require("git")

local M = {}

function M:from_spec(spec)
    spec = to_array(spec)
    local plugin = setmetatable({}, self)
    self.__index = self

    plugin.repo = spec[1]
    plugin.name = spec.as or plugin.repo:match("%C+/(%C+)")
    plugin.url = ("https://github.com/%s.git"):format(plugin.repo)
    plugin.opt = (spec.event or spec.cmd or spec.ft) and true or false
    plugin.path = vim.fs.joinpath(AlpacaPath, plugin.opt and "opt" or "start", plugin.name)

    plugin.build = spec.build
    plugin.config = spec.config

    plugin.branch = spec.branch
    plugin.tag = spec.tag

    plugin.event = spec.event and to_array(spec.event)
    plugin.cmd = spec.cmd and to_array(spec.cmd)
    plugin.ft = spec.ft and to_array(spec.ft)

    return plugin
end

function M:do_config()
    if self.config then
        self:config()
    end
end

function M:do_build()
    if self.build then
        print("TODO BUILD")
    end
end

function M:install()
    vim.notify(("[Alpaca.nvim] Installing %s"):format(self.name))
    local err = git.clone_basic(self.url, self.path)
    if not err then
        vim.notify(("[Alpaca.nvim] Installed %s"):format(self.name))
        self:do_build()
        self:load()
    else
        vim.notify(("[Alpaca.nvim] Failed to Install %s: %s"):format(self.name, err))
    end
end

function M:get_updates(local_version)
    print("getting updates")
    vim.print(local_version)
    local remote_version = self.get_remote_version(local_version)
end

function M:load()
    if self.event then
        vim.notify("TODO event")
        vim.cmd.packadd(self.name)
        self:do_config()
    elseif self.cmd then
        vim.notify("TODO cmd")
        vim.cmd.packadd(self.name)
        self:do_config()
    elseif self.ft then
        vim.notify("TODO ft")
        vim.cmd.packadd(self.name)
        self:do_config()
    else
        vim.cmd.packadd(self.name)
        self:do_config()
    end
end

function M:get_remote_version(local_version)
    if self.tag then
        local range = vim.version.range(self.tag)

    elseif self.branch then
    else
    end
end

function M.describe_installed_plugin(relative_path)
    local path = vim.fs.joinpath(AlpacaPath, relative_path)
    local subdir, name = relative_path:match("(.+)/(.+)")
    local ref = git.get_head_ref(path)
    local repo = git.get_remote_repo(path)
    return repo, {
        version = {
            branch = ref.branch,
            commit = ref.commit,
            tag = ref.tag
        },
        name = name,
        path = path,
        opt = subdir == "opt" and true or false,
    }
end

function M.list_installed()
    return vim.iter(vim.fs.dir(AlpacaPath, { depth = 2 })):filter(function(path)
        return path:match("%C+/%C+")
    end):map(M.describe_installed_plugin):fold({}, function(acc, repo, data)
        acc[repo] = data
        return acc
    end)
end


return M
