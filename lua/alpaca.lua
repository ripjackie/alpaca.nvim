local vim = vim
local uv = vim.uv or vim.loop

AlpacaPath = vim.fn.stdpath("data") .. "/site/pack/alpaca"

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
---@field version string?
---@field branch string?
---@field tag string?
---@field event (string | string[])?
---@field ft (string | string[])?
---@field cmd (string | string[])?
---@field config function?

---@class Plugin
---@field name string
---@field url string
---@field opt boolean
---@field path string
---@field config function?
---@field event string[]?
---@field cmd string[]?
---@field ft string[]?
---@field clone_args string[]
---@field pull_args string[]
Plugin = {
  clone_args = { "--depth=1", "--recurse-submodules", "--shallow-submodules" },
  pull_args = { "--recurse-submodules", "--update-shallow" }
}

---@param spec string | PluginSpec
function Plugin:new(spec)
  spec = to_array(spec)
  ---@cast spec PluginSpec
  ---@type Plugin
  local plugin = setmetatable({}, self)
  self.__index = self

  plugin.name = vim.split(spec[1], "/")[2]

  plugin.url = string.format("https://github.com/%s.git", spec[1])
  plugin.opt = (spec.event or spec.cmd or spec.ft) and true or false
  plugin.path = AlpacaPath .. (plugin.opt and "/opt/" or "/start/") .. plugin.name

  plugin.config = spec.config
  plugin.event = spec.event and to_array(spec.event)
  plugin.cmd = spec.cmd and to_array(spec.cmd)
  plugin.ft = spec.ft and to_array(spec.ft)

  plugin.clone_args = vim.list_extend({ "clone", plugin.url, plugin.path }, self.clone_args)
  if spec.branch then
  end
  if spec.tag then
  end
  if spec.version then
    vim.list_extend(plugin.clone_args, { "--branch", spec.version })
  end
  plugin.pull_args = vim.list_extend({ "pull" }, self.pull_args)

  return plugin
end

---@return boolean
function Plugin:is_installed()
  return uv.fs_stat(self.path) and true or false
end

---@return boolean
function Plugin:needs_update()
  -- TODO
  return true
end

function git(args, cwd, callback)
  local stdout = uv.new_pipe(false)
  local stderr = uv.new_pipe(false)

  stderr:read_start(function(read_err, data)
    if read_err then
      callback(read_err)
    elseif data then
      callback(data)
    else
      stderr:read_stop()
      stderr:close()
    end
  end)

  stdout:read_start(function(read_err, data)
    if read_err then
      callback(read_err)
    elseif data then
      callback(data)
    else
      stdout:read_close()
      stdout:close()
    end
  end)

  local handle, pid = uv.spawn("git", {
    args = args, cwd = cwd, stdio = { nil, stdout, stderr }
  }, function(code, signal)

  end)
end

function Plugin:clone()
  spawn("git", {
    "init"
  }, self.path, function(err)
    assert(not err, err)
    spawn("git", {
      "remote", "add", "--no-tags", "origin", self.url
    }, self.path, function(err)
      assert(not err, err)
      local args = { "fetch", "origin" }
      if self.tag then
        vim.list_expand(args, { string.format("refs/tags/%s:refs/tags/%s", self.tag, self.tag) })
      elseif self.branch then
        vim.list_expand(args, { string.format("refs/heads/%s:refs/heads/%s", self.branch, self.branch) })
      end
      spawn("git", args, nil, function(err)
        assert(not err, err)
      end)
    end)
  end)
end

local M = {}

---@param configs (string | PluginSpec)[]
function M.setup(configs)
  vim.api.nvim_create_augroup("AlpacaLazy", { clear = true })

  Plugins:setup(configs)
  Installed:setup()
end

return M
