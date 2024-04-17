local vim = vim
local uv = vim.uv or vim.loop
local git = require("git")

---@class AlpacaPluginSpec
---@field [1] string Plugin Repo
---@field as string? Plugin Alias
---@field build (string | string[] | fun():nil)? Plugin build to run on install / update
---@field config (fun():nil)? Plugin config to run after load
---@field branch string? Plugin branch to follow
---@field tag string? Plugin tag semver to follow
---@field event (string | string[])?
---@field cmd (string | string[])?
---@field ft (string | string[])?

---@class AlpacaPlugin
---@field repo string
---@field name string
---@field url string
---@field opt boolean
---@field path string
---@field build (fun():nil)?
---@field config (fun():nil)?
---@field branch string?
---@field tag string?
---@field event string[]?
---@field cmd string[]?
---@field ft string[]?
local M = {}

local function to_array(input)
    if type(input) ~= "table" then
        return {input}
    else
        return input
    end
end

function M:new(spec)
    vim.validate({
        spec = { spec, "table" }
    })

    local plugin = setmetatable({}, self)
    self.__index = self

    plugin.repo = spec[1]
    plugin.name = spec.as or plugin.repo:match("%C+/(%C+)")
    plugin.url = ("https://github.com/%s.git"):format(plugin.repo)
    plugin.opt = (spec.event or spec.cmd or spec.ft) and true or false
    plugin.path = Alpaca.path .. (plugin.opt and "/opt/" or "/start/") .. plugin.name

    plugin.build = spec.build and self.parse_build(spec.build)
    plugin.config = spec.config

    plugin.branch = spec.branch
    plugin.tag = spec.tag

    plugin.event = spec.event and to_array(spec.event)
    plugin.cmd = spec.cmd and to_array(spec.cmd)
    plugin.ft = spec.ft and to_array(spec.ft)

  return plugin
end

function M:load_config()
    if self.config then
        self:config()
    end
end

function M:run_build()
    if self.build then
        print("TODO BUILD")
    end
end

function M.parse_build(build_spec)
    print("BUILD")
end

function M:install()
    vim.notify(("[Alpaca.nvim] Installing %s"):format(self.name))
    local err = git.clone_basic(self.url, self.path)
    if not err then
        vim.notify(("[Alpaca.nvim] Installed %s"):format(self.name))
        self:run_build()
        self:load()
    else
        self:load()
    end
end

function M:load()
  if self.event then
    vim.notify("TODO event")
    vim.cmd.packadd(self.name)
    self:load_config()
  elseif self.cmd then
    vim.notify("TODO cmd")
    vim.cmd.packadd(self.name)
    self:load_config()
  elseif self.ft then
    vim.notify("TODO ft")
    vim.cmd.packadd(self.name)
    self:load_config()
  else
    vim.cmd.packadd(self.name)
    self:load_config()
  end
end

return M
