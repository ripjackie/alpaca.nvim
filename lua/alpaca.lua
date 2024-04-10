local uv = vim.uv or vim.loop
local AlpacaPath = vim.fn.stdpath("data") .. "/site/pack/alpaca"

local function cmd(cmd, opts)
    cmd = vim.split(cmd, ' ')
    for _, opt in ipairs(opts) do
        table.insert(cmd, opt)
    end
    return vim.system(cmd, { text = true, cwd = opts.cwd }):wait()
end

local function to_array(input)
    if type(input) ~= "table" then
        return {input}
    else
        return input
    end
end

local Plugin = {}

function Plugin:new(spec)
    spec = to_array(spec)
    local plugin = setmetatable({}, self)
    self.__index = self

    plugin.name = spec.as or spec[1]:match("%w+/(%w+)")
    plugin.url = ("https://github.com/%s.git"):format(spec[1])
    plugin.path = AlpacaPath .. "/opt/" .. plugin.name

    plugin.build = spec.build
    plugin.config = spec.config

    plugin.branch = spec.branch
    plugin.tag = spec.tag

    plugin.event = spec.event and to_array(spec.event)
    plugin.cmd = spec.cmd and to_array(spec.cmd)
    plugin.ft = spec.ft and to_array(spec.ft)

    if uv.fs_stat(plugin.path) then
        plugin.commit = self.get_head_commit(plugin)
    end

    vim.print(vim.json.encode({
        [spec[1]] = { name = plugin.name, branch = plugin.branch, tag = plugin.tag, commit = plugin.commit }
    }))

    return plugin
end

function Plugin:get_head_commit()
    return cmd("git rev-parse HEAD", { cwd = self.path }).stdout:gsub('\n', '')
end

function Plugin:is_installed()
    return (uv.fs_stat(self.path) and uv.fs_stat(self.path .. "/.git")) and true or false
end

function Plugin:check_needs_update()
    if self.tag then
        local obj = cmd("git ls-remote --quiet --refs --tags origin", { cwd = self.path })
    elseif self.branch then
        local obj = cmd("git ls-remote --quiet --refs --heads origin", { self.branch, cwd = self.path })
        local commit, branch = obj.stdout:match("(%C+)\trefs/heads/(%C+)\n")
        vim.print(obj)
        print(self.name, self.branch, branch, commit)
    else
        local obj = cmd("git ls-remote --quiet --refs --heads origin master main", { cwd = self.path })
        local commit, branch = obj.stdout:match("(%C+)\trefs/heads/(%C+)\n")
        print(self.name, branch, commit)
    end
end

function Plugin:install(callback)
    vim.system({
        "git", "clone",
        "--depth=1", "--recurse-submodules", "--shallow-submodules",
        self.url, self.path
    }, {}, function(obj)
        if obj.code ~= 0 then
            callback(err)
        else
            callback()
        end
    end)
end

function Plugin:load()
    if self.event then
        print("event")
        vim.cmd.packadd(self.name)
        if self.config then
            self.config()
        end
    elseif self.cmd then
        print("cmd")
        vim.cmd.packadd(self.name)
        if self.config then
            self.config()
        end
    elseif self.ft then
        print("ft")
        vim.cmd.packadd(self.name)
        if self.config then
            self.config()
        end
    else
        vim.cmd.packadd(self.name)
        if self.config then
            self.config()
        end
    end
end

function Plugin:do_build()
    if self.build then
        print("Build!")
    end
end

local M = {}
function M.setup(specs)
    vim.validate({
        specs = { specs, "table" }
    })
    for _, spec in ipairs(specs) do
        local plugin = Plugin:new(spec)

        if not plugin:is_installed() then
            -- Install
            vim.notify(("Installing: %s"):format(plugin.name))
            plugin:install(vim.schedule_wrap(function(err)
                if not err then
                    vim.notify(("Successfully Installed: %s"):format(plugin.name))
                    plugin:do_build()
                    plugin:load()
                else
                    vim.notify(("Failed to Install: %s, %s"):format(plugin.name, err))
                end
            end))
        else
            -- Update
            plugin:check_needs_update()
            plugin:load()
        end
    end
end
return M
