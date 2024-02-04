local vim = vim
local uv = vim.uv or vim.loop

local git = {}

---@param plugin Plugin
---@param callback function?
function git:clone(plugin, callback)
  local args = { "git", "clone", "--depth=1", "--recurse-submodules", "--shallow-submodules", plugin.url, plugin.path }
  vim.system(args, { text = true }, function(obj)
    print(vim.inspect(obj))
  end)
end

function git:fetch(plugin, callback)
  local args = { "git", "fetch", "origin" }
  vim.system(args, { text = true }, function(obj)
    print(vim.inspect(obj))
  end)
end

function git:checkout(plugin, callback)
  local args = { "git", "checkout" }
end

---@class PluginSpec
---@field [1] string
---@field as string?
---@field branch string?
---@field tag string?
---@field config function?
---@field event (string | string[])?
---@field cmd (string | string[])?
---@field ft (string | string[])?

---@class Plugin
---@field name string
---@field url string
---@field path string
---@field branch string?
---@field tag string?
---@field config function?
---@field opt boolean
---@field event string[]?
---@field cmd string[]?
---@field ft string[]?
local Plugin = {}

---@param spec string | PluginSpec
---@return Plugin
function Plugin:new(spec)
  local to_array = function(inp) return type(inp) == "string" and {inp} or inp end
  spec = to_array(spec) --[[@as PluginSpec]]

  local plugin = setmetatable({}, self)
  self.__index = self

  plugin.branch = spec.branch
  plugin.tag = spec.tag

  plugin.config = spec.config

  plugin.opt = (spec.event or spec.cmd or spec.ft) and true or false
  plugin.event = spec.event and to_array(spec.event)
  plugin.cmd = spec.cmd and to_array(spec.cmd)
  plugin.ft = spec.ft and to_array(spec.ft)

  plugin.name = spec.as or vim.split(spec[1], "/")[2]
  plugin.url = "http://github.com/" .. spec[1]
  plugin.path = vim.fn.stdpath("data") .. "/site/pack/alpaca" .. (plugin.opt and "/opt/" or "/start/") .. plugin.name

  return plugin
end

---@param dir string -- dir is of shape '{opt,start}/name'
---@return Plugin
function Plugin:from_installed(dir)
  local plugin = setmetatable({}, self)
  self.__index = self

  local split_val = vim.split(dir, '/')
  assert(#split_val == 2, "[Alpaca.nvim] Invalid installed spec provided: " .. dir)

  plugin.opt = split_val[1] == "opt" and true or split_val[1] == "start" and false
  plugin.name = split_val[2]
  plugin.url = ""
  plugin.path = vim.fn.stdpath("data") .. "/site/pack/alpaca" .. (plugin.opt and "/opt/" or "/start/") .. plugin.name

  return plugin
end

---@param callback fun(err: string?): nil
function Plugin:install(callback)
  git:clone(self, function(err)
    if err then callback(err) end
    git:checkout(self, callback)
  end)
end

---@param callback fun(err: string?): nil
function Plugin:update(callback)
  git:fetch(self, function(err)
    if err then callback(err) end
    git:checkout(self, callback)
  end)
end

function Plugin:clean()
  local function recurse_rm(path)
    assert(string.find(path, vim.fn.stdpath("data") .. "/site/pack/alpaca"), "File path not in Alpaca's Heirarchy!")
    vim.iter(vim.fs.dir(path)):each(function(name, type)
      if type == "file" then
        uv.fs_unlink(vim.fs.joinpath(path, name))
      elseif type == "directory" then
        recurse_rm(vim.fs.joinpath(path, name))
      end
    end)
    uv.fs_rmdir(path)
  end
  if self:installed() then
    recurse_rm(self.path)
  end
end

function Plugin:load()
  if self:installed() then
    if self.event then
      vim.api.nvim_create_autocmd(self.event, {
        callback = function()
          vim.cmd.packadd(self.name)
          if vim.is_callable(self.config) then
              self.config()
          end
        end
      })
    elseif self.cmd then
      vim.print("[Alpaca.nvim] (debug) ["..self.name.."] Lazy loading via cmd not yet implemented! ( sorry! )")
      vim.cmd.packadd(self.name)
      if vim.is_callable(self.config) then
        self.config()
      end
    elseif self.ft then
      vim.api.nvim_create_autocmd("FileType", {
        pattern = self.ft,
        callback = function()
          vim.cmd.packadd(self.name)
          if vim.is_callable(self.config) then
            self.config()
          end
        end
      })
    elseif self.config then
      if vim.is_callable(self.config) then
        self.config()
      end
    end
  end
end

---@return boolean
function Plugin:installed()
  return uv.fs_stat(self.path) ~= nil
end

---@return boolean
function Plugin:updated()
  vim.system({ "git", "fetch", "origin" }, { cwd = self.path }):wait()
  if self.tag then
    local obj = vim.system({
      "git", "for-each-ref", "refs/tags", "--no-merged=HEAD", "--sort=-v:refname", "--format=%(refname:short)"
    }, { cwd = self.path }):wait()
    assert(obj.stderr == "", obj.stderr)
    local range = vim.version.range(self.tag)
    for _, ref in ipairs(vim.split(obj.stdout, '\n')) do
      if range:has(ref) then
        return false
      end
    end
    return true
  else
    local obj = vim.system({
      "git", "for-each-ref", "refs/heads", "--contains=HEAD", "--format=%(upstream:trackshort)"
    }, { cwd = self.path }):wait()
    assert(obj.stderr == "", obj.stderr)
    if string.find(obj.stdout, '<') then
      return false
    else
      return true
    end
  end
end

local Alpaca = {
  plugins = {},
  to_install = {}
}

function Alpaca:install_all()
  local total = #self.to_install
  local counter = 0
  vim.iter(self.to_install):each(function(plugin)
    ---@cast plugin Plugin
    plugin:install(function(err)
      counter = counter + 1
      if err then
        print(string.format("[Alpaca.nvim] (%d/%d) [install] (%s) [failure] %s", counter, total, plugin.name, err))
      else
        print(string.format("[Alpaca.nvim] (%d/%d) [install] (%s) [success]", counter, total, plugin.name))
        plugin:load()
      end
      if counter == total then
        print(string.format("[Alpaca.nvim] (install) [finished]"))
      end
    end)
  end)
end

function Alpaca:update_all()
  local total = #self.plugins
  local counter = 0
  vim.iter(self.plugins):each(function(plugin)
    ---@cast plugin Plugin
    plugin:update(function(err)
      counter = counter + 1
      if err then
        print(string.format("[Alpaca.nvim] (%d/%d) [update] (%s) [failure] %s", counter, total, plugin.name, err))
      else
        print(string.format("[Alpaca.nvim] (%d/%d) [update] (%s) [success]", counter, total, plugin.name))
        plugin:load()
      end
      if counter == total then
        print(string.format("[Alpaca.nvim] (update) [finished]"))
      end
    end)
  end)
end

function Alpaca:clean_all()
  local path = vim.fn.stdpath("data") .. "/site/pack/alpaca"
  vim.iter(vim.fs.dir(path, { depth = 2 })):map(function(name, type)
    return type == "directory" and string.find(name, '/') and Plugin:from_installed(name)
  end):each(function(installed_plugin)
    local loaded = vim.iter(self.plugins):find(function(plugin)
      return installed_plugin.name == plugin.name and installed_plugin.opt == plugin.opt
    end)
    if not loaded then
      installed_plugin:clean()
    end
  end)
end

function Alpaca:create_autocmds()
  vim.api.nvim_create_user_command("AlpacaUpdate", function(event)end, {})
  vim.api.nvim_create_user_command("AlpacaUpdate", function(event)end, {})
  vim.api.nvim_create_user_command("AlpacaClean", function(event)end, {})
end


local M = {}

---@param specs (string | PluginSpec)[]
function M.setup(specs)
  vim.iter(ipairs(specs)):each(function(_, spec)
    local plugin = Plugin:new(spec)
    if not plugin:installed() then
      table.insert(Alpaca.to_install, plugin)
    else
      plugin:load()
    end
    table.insert(Alpaca.plugins, plugin)
  end)
  if #Alpaca.to_install > 0 then
    Alpaca:install_all()
  end
end

return M
