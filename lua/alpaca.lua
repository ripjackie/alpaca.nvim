local vim = vim
local uv = vim.uv or vim.loop

AlpacaPath = vim.fn.stdpath("data") .. "/site/pack/alpaca"

---@class Git
Git = {}

---@param pipe userdata
---@param callback fun(err: string?, data: string?): nil
function Git:read_pipe(pipe, callback)
  local buffer = ""
  pipe:read_start(function(err, data)
    if err then
      callback(err, nil)
    elseif data then
      buffer = buffer .. data
    else
      callback(nil, buffer)
    end
  end)
end
---@param args string[]
---@param cwd string?
---@param callback fun(err: string?, ok: boolean, stdout: string?, stderr: string?): nil
function Git:spawn_cap(args, cwd, callback)
  local stdout = uv.new_pipe(false)
  local stderr = uv.new_pipe(false)
  local handle = uv.spawn("git", {
    args = args, cwd = cwd, stdio = { nil, stdout, stderr }
  }, function(code)
    local ok = code == 0
    self:read_pipe(stdout, function(err, data_out)
      if err then callback(err, ok, nil, nil) end
      self:read_pipe(stderr, function(err, data_err)
        if err then callback(err, ok, nil, nil) end
        stdout:close()
        stderr:close()
        callback(nil, ok, data_out, data_err)
      end)
    end)
  end)
  if not handle then
    callback(string.format("Failed to spawn git with args ( %s ) at ( %s )", vim.iter(args):join(" "), cwd), false, nil,
      nil)
  end
end

function Git:spawn(args, cwd, callback)
  local handle = uv.spawn("git", {
    args = args, cwd = cwd, stdio = { nil, 1, 2 }
  }, function(code)
    callback(nil, code == 0)
  end)
  if not handle then
    callback(string.format("Failed to spawn git with args ( %s ) at ( %s )", vim.iter(args):join(" "), cwd), false)
  end
---@param plugin Plugin
---@param callback fun(ok: boolean): nil
function Git:clone(plugin, callback)
  self:spawn({ "--depth=1", plugin.url, plugin.path }, nil, function(ok)
    callback(ok)
  end)
end

function Git:fetch(plugin, callback)
end

function Git:checkout(plugin, callback)
end

Plugin = {}
Alpaca = {}

---@package
---@param cmd string
---@param args string[]
---@param cwd string?
---@param callback function
local function spawn(cmd, args, cwd, callback)
  local stderr = uv.new_pipe(false)
  local spawn_args = { args = args, cwd = cwd, stdio = { nil, nil, stderr } }

  local handle, _ = uv.spawn(cmd, spawn_args, function(code)
    local buffer = ""
    if code == 0 then
      callback(nil)
    else
      stderr:read_start(function(err, data)
        assert(not err, err)
        if data then
          buffer = buffer .. data
        else
          stderr:read_stop()
          stderr:close()
          buffer = string.gsub(buffer, "\n", "")
          callback(buffer)
        end
      end)
    end
  end)

  if not handle then
    vim.notify("Failed to spawn git")
  end
end


Plugins = {
  plugins = {},
  to_install = {},
  to_update = {},
  install_any = function(self)
    local total = #self.to_install
    if total > 0 then
      local counter = 0
      vim.iter(self.to_install):each(function(plugin)
        spawn("git", plugin.clone_args, nil, vim.schedule_wrap(function(err)
          counter = counter + 1
          if err then
            vim.notify(string.format("[Alpaca.nvim] [Install] [%d/%d] (%s) %s", counter, total, plugin.name,
              "Failure: " .. err))
          else
            vim.notify(string.format("[Alpaca.nvim] [Install] [%d/%d] (%s) %s", counter, total, plugin.name, "Success"))
          end
          if counter == total then
            vim.notify(string.format("[Alpaca.nvim] [Install] [Complete]"))
          end
        end))
      end)
    end
  end,
  update_any = function(self)
    local total = #self.to_update
    if total > 0 then
      local counter = 0
      vim.iter(self.to_update):each(function(plugin)
        spawn("git", plugin.pull_args, plugin.path, vim.schedule_wrap(function(err)
          counter = counter + 1
          if err then
            vim.notify(string.format("[Alpaca.nvim] [Update] [%d/%d] (%s) %s", counter, total, plugin.name,
              "Failure: " .. err))
          else
            vim.notify(string.format("[Alpaca.nvim] [Update] [%d/%d] (%s) %s", counter, total, plugin.name, "Success"))
          end
          if counter == total then
            vim.notify(string.format("[Alpaca.nvim] [Update] [Complete]"))
          end
        end))
      end)
    end
  end,
  load_all = function(self)
    vim.iter(self.plugins):each(function(plugin)
      if plugin.config then
        if plugin.event or plugin.ft then
          vim.api.nvim_create_autocmd(plugin.ft and "FileType" or plugin.event, {
            group = vim.api.nvim_create_augroup("AlpacaLazy", {}),
            pattern = plugin.ft,
            callback = function()
              vim.cmd.packadd(plugin.name)
              plugin.config()
            end
          })
        elseif plugin.cmd then
          vim.iter(plugin.cmd):each(function(cmd)
            vim.api.nvim_create_user_command(cmd, function(opts)
              vim.cmd.packadd(plugin.name)
              plugin.config()
              vim.cmd({ cmd = cmd, args = opts.fargs, bang = opts.bang })
            end, {})
          end)
        else
          plugin.config()
        end
      end
    end)
  end,
  setup = function(self, configs)
    vim.iter(configs):map(function(config)
      config = type(config) == "string" and { config } or config
      if #vim.split(config[1], "/") == 2 then
        return Plugin:new(config)
      end
    end):each(function(plugin)
      table.insert(self.plugins, plugin)
      if not plugin:is_installed() then
        table.insert(self.to_install, plugin)
      elseif plugin:needs_update() then
        table.insert(self.to_update, plugin)
      end
    end)
    self:install_any()
    self:update_any()
    self:load_all()
  end,
}

Installed = {
  to_clean = {},
  clean_any = function(self)
    local total = #self.to_clean
    if total > 0 then
      local counter = 0
      vim.iter(self.to_clean):each(function(plugin)
        local path = AlpacaPath .. (plugin.opt and "/opt/" or "/start/") .. plugin.name
        spawn("rm", { "-r", path }, nil, vim.schedule_wrap(function(err)
          counter = counter + 1
          if err then
            vim.notify(string.format("[Alpaca.nvim] [Remove] [%d/%d] (%s lazy=%s) %s", counter, total, plugin.name,
              tostring(plugin.opt)
              "Failure: " .. err))
          else
            vim.notify(string.format("[Alpaca.nvim] [Remove] [%d/%d] (%s) %s", counter, total, plugin.name, "Success"))
          end
          if counter == total then
            vim.notify(string.format("[Alpaca.nvim] [Remove] [Complete]"))
          end
        end))
      end)
    end
  end,
  setup = function(self)
    local it = vim.iter(vim.fs.dir(AlpacaPath, { depth = 2 }))
    it:map(function(plugin)
      local split = vim.split(plugin, "/")
      if #split == 2 then
        return {
          name = split[2],
          opt = split[1] == "opt" and true or false
        }
      end
    end):each(function(plugin)
      local lp_it = vim.iter(Plugins.plugins)
      local loaded = lp_it:map(function(loaded_plugin)
        return {
          name = loaded_plugin.name,
          opt = (loaded_plugin.event or loaded_plugin.cmd or loaded_plugin.ft) and true or false
        }
      end):find(function(loaded_plugin)
        return vim.deep_equal(loaded_plugin, plugin)
      end)
      if not loaded then
        table.insert(self.to_clean, plugin)
      end
    end)

    self:clean_any()
  end,
}

---@package
---@param arg string | string[]
---@return string[]
local function to_array(arg)
  if type(arg) == "string" then
    return { arg }
  else
    return arg
  end
end

---@class PluginSpec
---@field [1] string
---@field branch string?
---@field tag string?
---@field event (string | string[])?
---@field cmd (string | string[])?
---@field ft (string | string[])?
---@field config function?

---@class Plugin
---@field name string
---@field url string
---@field path string
---@field config function?
---@field branch string?
---@field tag string?
---@field event string[]?
---@field cmd string[]?
---@field ft string[]?
Plugin = {}

---@param spec string | PluginSpec
function Plugin:new(spec)
  spec = to_array(spec)
  ---@cast spec PluginSpec
  ---@type Plugin
  local plugin = setmetatable({}, self)
  self.__index = self

  plugin.name = vim.split(spec[1], "/")[2]
  plugin.url = string.format("https://github.com/%s.git", spec[1])
  plugin.path = AlpacaPath .. ((spec.event or spec.cmd or spec.ft) and "/opt/" or "/start/") .. plugin.name
  plugin.config = spec.config
  plugin.event = spec.event and to_array(spec.event)
  plugin.cmd = spec.cmd and to_array(spec.cmd)
  plugin.ft = spec.ft and to_array(spec.ft)
  plugin.branch = spec.branch
  plugin.tag = spec.tag

  return plugin
end

---@return boolean
function Plugin:needs_installed()
  if uv.fs_stat(self.path) then
    return false
  else
    return true
  end
end

---@param args string[]
---@param cwd string?
---@param callback fun(stderr: string?, stdout: string?): nil
local function git(args, cwd, callback)
  local stdout = uv.new_pipe(false)
  local stderr = uv.new_pipe(false)
  local handle, _ = uv.spawn("git", {
    args = args, cwd = cwd, stdio = { nil, stdout, stderr }
  }, function(code, signal)
    local buffer = ""
    if code == 0 then
      stdout:read_start(function(err, data)
        if err then
          callback(err, nil)
        elseif data then
          buffer = buffer .. data
        else
          callback(nil, buffer)
        end
      end)
    else
      stderr:read_start(function(err, data)
        if err then
          callback(err, nil)
        elseif data then
          buffer = buffer .. data
        else
          callback(buffer, nil)
        end
      end)
    end
  end)
  if not handle then
    callback("Failed to start git", nil)
  end
end

---@return boolean
function Plugin:needs_update()
  git({ "fetch", "origin", "--tags" }, self.path, function(err, out)
  end)
  return true
end

---@param callback fun(err: string?): nil
function Plugin:install(callback)
  git({ "clone", self.url, self.path, "--depth=1", "--recurse-submodules", "--shallow-submodules" }, nil,
    function(err, out)
      if err then callback(err) end
      if out then print(out) end
      git({ "fetch", "--tags", "origin" }, self.path, function(err, out)
        if err then callback(err) end
        if out then print(out) end
        if self.branch then
          git({ "checkout", self.branch }, self.path, function(err, out)
            if err then callback(err) end
            if out then print(out) end
            callback(nil)
          end)
        elseif self.tag then
          local newest = self:find_newest_tag()
          git({ "checkout", newest }, self.path, function(err, out)
            if err then callback(err) end
            if out then print(out) end
            callback(nil)
          end)
        end
      end)
    end)
end

---@param callback fun(err: string?): nil
function Plugin:update(callback)
end

local M = {}

---@param configs (string | PluginSpec)[]
function M.setup(configs)
  vim.api.nvim_create_augroup("AlpacaLazy", { clear = true })

  vim.iter(configs):map(function(config)
    return Plugin:new(config)
  end):each(function(plugin)
    if plugin:needs_installed() then
      vim.print(plugin)
      plugin:install(function(err)
        if err then
          vim.schedule_wrap(function()
            vim.print(err)
          end)
        end
      end)
    end
  end)

  -- Plugins:setup(configs)
  -- Installed:setup()
end

return M
