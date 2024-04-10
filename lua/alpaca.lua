local uv = vim.uv or vim.loop
local AlpacaPath = vim.fn.stdpath("data") .. "/site/pack/alpaca"
local function to_array(input)
    if type(input) ~= "table" then
        return {input}
    else
        return input
    end
end

local Plugin = {}
function Plugin:from_spec(spec)
    spec = to_array(spec)
    local plugin = setmetatable({}, self)
    self.__index = self

    plugin.name = spec.as or spec[1]:match("%w+/(%w+)")
    plugin.url = ("https://github.com/%s.git"):format(spec[1])
    plugin.path = AlpacaPath .. "/opt/" .. plugin.name
    plugin.build = spec.build
    plugin.config = spec.config
    plugin.event = spec.event and to_array(spec.event)
    plugin.cmd = spec.cmd and to_array(spec.cmd)
    plugin.ft = spec.ft and to_array(spec.ft)

    return plugin
end

function Plugin:is_installed()
    if uv.fs_stat(self.path) and uv.fs_stat(self.path .. "/.git") then
        return true
    else
        return false
    end
end

function Plugin:install()
    local obj = vim.system({
        "git", "clone",
        "--depth=1", "--recurse-submodules", "--shallow-submodules",
        self.url, self.path
    }, { text = true }):wait()
    if obj.code != 0 then
        return obj.stderr
    else
        return
    end
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
    print("Build!")
end

local M = {}
function M.setup(specs)
    vim.validate({
        specs = { specs, "table" }
    })
    for _, spec in ipairs(specs) do
        local plugin = Plugin:from_spec(spec)
        if not plugin:is_installed() then
            local err = plugin:install()
            if not err then
                vim.notify(("Successfully Installed: %s"):format(plugin.name))
                plugin:do_build()
                plugin:load()
            else
                vim.notify(("Failed to Install: %s, %s"):format(plugin.name, err))
            end
        else
            plugin:load()
        end
    end
end
return M
