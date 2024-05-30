local vim = vim
local uv = vim.uv or vim.loop
local git = require("git")
local Plugin = require("plugin")

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

util.logger = {
  init = function (self, method)
    self.__index = self
    return setmetatable({
      total = 0,
      index = 0,
      errors = {},
      method = method
    }, self)
  end,
  track = function (self, name, on_success)
    if self.total == 0 then
      print(("[Alpaca] [%s] Begin"):format(self.method))
    end
    self.total = self.total + 1
    return function (ok, out)
      self.index = self.index + 1
      if ok then
        -- [Alpaca] [Install] [1/14] Success: sainnhe/everforest
        -- [Alpaca] [Install] [8/14] Failure: sainnhe/sonokai
        print(("[Alpaca] [%s] [%d/%d] %s %s"):format(self.method, self.index, self.total, "Success", name))
        vim.schedule(on_success)
      else
        print(("[Alpaca] [%s] [%d/%d] %s %s"):format(self.method, self.index, self.total, "Failure", name))
        table.insert(self.errors, { name = name, err = out })
      end
      if self.index == self.total then
        print(("[Alpaca] [%s] Done%s"):format(self.method, #self.errors > 0 and " w/ Errors" or ""))
        if #self.errors > 0 then
          print(vim.inspect(self.errors))
        end
      end
    end
  end
}


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
  local logger = util.logger:init("Install")
  for _, plugin in pairs(self.plugins) do
    if plugin.spec and not plugin.install then
      plugin:do_install(logger:track(plugin.spec.name, function ()
        vim.cmd("let &rtp = &rtp")
        plugin:do_build()
        plugin:do_load()
      end))
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
      plugin:do_update(function (ok, out)
        if ok then
          print("Update Done " .. plugin.spec.name)
          plugin:do_build()
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
      plugin:do_clean(function (ok, out)
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
          coroutine.wrap(Alpaca.install)(Alpaca)
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
