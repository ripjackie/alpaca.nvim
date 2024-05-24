local vim = vim
local uv = vim.uv or vim.loop
local git = require("git")

local PluginPath = vim.fn.stdpath("data") .. "/site/pack/alpaca"

local util = {}
function util.to_table(value)
  return type(value) ~= "table" and {value} or value
end

function util.log(msg, level)
  vim.schedule(function()
    vim.notify("[Alpaca.nvim] " .. msg, level)
  end)
end

---@class PluginSpec
---@field [1] string github short url
---@field as string? local filename alias
---@field build (string | function)?
---@field config function?
---@field branch string?
---@field tag string?
---@field event (string | string[])?
---@field cmd (string | string[])?
---@field ft (string | string[])?
---@field name string
---@field url string
---@field opt boolean
---@field path string

---@class PluginInstall
---@field repo string
---@field opt boolean
---@field path string
---@field commit string
---@field branch string?
---@field tag string?

---@class Plugin
---@field repo string
---@field spec PluginSpec?
---@field install PluginInstall?
---@field loaded boolean
---@field lazy boolean
local Plugin = {}

function Plugin:from_spec(spec)
  self.__index = self
  spec.url = ("https://github.com/%s.git"):format(spec[1])
  spec.name = spec.as or spec[1]:match("%C+/(%C+)")
  spec.opt = spec.opt or ( spec.event or spec.cmd or spec.ft ) and true or false
  spec.path = ("%s/%s/%s"):format(PluginPath, spec.opt and "opt" or "start", spec.name)
  return setmetatable({ repo = spec[1], spec = spec, loaded = false, lazy = spec.opt }, self)
end

function Plugin:from_install(install)
  self.__index = self
  return setmetatable({ repo = install.repo, install = install, loaded = false, lazy = install.opt }, self)
end

function Plugin:do_install(callback)
  if self.spec.tag then
    local ok, out = git.ls_remote_tags(self.spec)
    if ok then
      return git.clone(self.spec, out, callback)
    else
      return callback(ok, out)
    end
  else
    return git.clone(self.spec, self.spec.branch, callback)
  end
end

function Plugin:do_update(callback)
  return callback(false, "Not Implemented")
end

function Plugin:do_clean(callback)
  return callback(false, "Not Implemented")
end

function Plugin:do_load()
  if self.lazy then
    if self.spec.event then
      print("event")
    elseif self.spec.cmd then
      print("cmd")
    elseif self.spec.ft then
      print("ft")
    end
  else
    self:do_config()
  end
  self.loaded = true
end

function Plugin:do_build()
end

function Plugin:do_config()
  if self.spec.config and type(self.spec.config) == "function" then
    return vim.schedule(self.spec.config)
  end
end

---@class Alpaca
---@field plugins Plugin[]
---@field opts table
local Alpaca = {
  plugins = {},
  opts = {
    install_on_start = true
  }
}

function Alpaca:install()
  local total = 0
  local index = 0
  for _, plugin in pairs(self.plugins) do
    if plugin.spec and not plugin.install then
      if total == 0 then
        print("Installing new plugins")
      end
      total = total + 1
      Plugin:do_install(function(ok ,out)
        index = index + 1
        if ok then
          print("Install Done " .. plugin.spec.name)
          vim.cmd("let &rtp = &rtp")
          Plugin:do_build()
          Plugin:do_load()
        else
          print("Install Fail " .. out)
        end
        if index == total then
          print("all installs finished")
        end
      end)
    end
  end
end

function Alpaca:update() -- TODO
  local total = 0
  local index = 0
  for _, plugin in pairs(self.plugins) do
    if plugin.spec and plugin.install then
      if total == 0 then
        print("Updating Plugins")
      end
      total = total + 1
      Plugin:do_update(function (ok, out)
        if ok then
          print("Update Done " .. plugin.spec.name)
          Plugin:do_build()
        else
          print("Update Fail " .. out)
        end
        if index == total then
          print("all Updates Complete")
        end
      end)
    end
  end
end

function Alpaca:clean() --TODO
  local total = 0
  local index = 0
  for _, plugin in pairs(self.plugins) do
    if not plugin.spec and plugin.install then
      if total == 0 then
        print("Cleaning Plugins")
      end
      total = total + 1
      Plugin:do_update(function (ok, out)
        if ok then
          print("Clean Done " .. plugin.spec.name)
        else
          print("Clean Fail " .. out)
        end
        if index == total then
          print("all Cleaning Complete")
        end
      end)
    end
  end
end

function Alpaca:setup(specs, opts)
  -- Init Steps
  vim.validate({
    specs = { specs, "table" },
      opts = { opts, { "table", "nil" } }
  })

  if opts then
    vim.tbl_deep_extend("force", self.opts, opts)
  end

  -- Parse Specs
  for _, spec in ipairs(specs) do
    spec = util.to_table(spec)
    local plugin = Plugin:from_spec(spec)
    if plugin then
      self.plugins[plugin.repo] = plugin
    end
  end

  -- Parse Installs
  for filename, filetype in vim.fs.dir(PluginPath, { depth = 2 }) do
    if filetype == "directory" and filename:find("/") then
      local plugin_path = ("%s/%s"):format(PluginPath, filename)
      local _, remote = git.get_url(plugin_path)
      local repo = remote:match("https://github.com/(%C+/%C+).git")
      local _, commit = git.rev_parse(plugin_path)
      local _, ref = git.describe(plugin_path)
      local install = {
        repo = repo,
        opt = filename:match("opt/%C+") and true or false,
        path = plugin_path,
        commit = commit:match("(%w+)"),
        branch = ref:match("heads/(%C+)"),
        tag = ref:match("tags/(%C+)")
      }
      if self.plugins[repo] then
        self.plugins[repo].install = install
      else
        self.plugins[repo] = Plugin:from_install(install)
      end
    end
  end

  if self.opts.install_on_start then
    vim.schedule(function ()
      Alpaca:install()
    end)
  else
    vim.schedule(function ()
      vim.api.nvim_create_user_command("AlpacaInstall", function ()
        vim.schedule(function ()
          Alpaca:install()
        end)
      end, {})
    end)
  end

  vim.schedule(function ()
    vim.api.nvim_create_user_command("AlpacaUpdate", function ()
      vim.schedule(function ()
        Alpaca:update()
      end)
    end, {})
    vim.api.nvim_create_user_command("AlpacaClean", function ()
      vim.schedule(function ()
        Alpaca:clean()
      end)
    end, {})
  end)

  -- load all installed plugins
  for _, plugin in pairs(self.plugins) do
    if plugin.spec and plugin.install then
      plugin:do_load()
    end
  end

  -- Setup Complete
end

local M = {}

function M.setup(specs, opts)
  coroutine.wrap(Alpaca.setup)(Alpaca, specs, opts)
end

return M
