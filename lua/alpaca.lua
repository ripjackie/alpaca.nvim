local vim = vim
local uv = vim.uv or vim.loop

AlpacaPath = vim.fn.stdpath("data") .. "/site/pack/alpaca"

local function to_array(inp)
  if type(inp) == "string" then
    return { inp }
  else
    return inp
  end
end

---@class Git
Git = {}

---@param args string[]
---@param cwd string?
---@param callback fun(err: string?, ok: boolean, stdout: string?, stderr: string?): nil
function Git:spawn(args, cwd, callback)
  local stdout = uv.new_pipe(false)
  local stderr = uv.new_pipe(false)
  ---@param pipe userdata
  ---@param callback fun(err: string?, data: string?): nil
  local function read_pipe(pipe, callback)
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
  local handle = uv.spawn("git", {
    args = args, cwd = cwd, stdio = { nil, stdout, stderr }
  }, function(code)
    local ok = code == 0
    read_pipe(stdout, function(err, data_out)
      if err then callback(err, ok, nil, nil) end
      read_pipe(stderr, function(err, data_err)
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

---@param plugin Plugin
---@param callback fun(err: string?): nil
function Git:fetch(plugin, callback)
  self:spawn({
    "fetch", "--tags"
  }, plugin.path, function(err, ok, stdout, stderr)
    if err then callback(err) end

  end)
end

function Git:checkout(plugin, callback)
end

---@class PluginSpec
---@field [1] string
---@field alias string?
---@field config function?
---@field branch string?
---@field tag string?
---@field event (string | string[])?
---@field cmd (string | string[])?
---@field ft (string | string[])?

---@class Plugin
---@field name string
---@field url string
---@field path string
---@field config function?
---@field branch string?
---@field tag string?
---@field event string[]?
---@field cmd string[]?
---@field ft  string[]?

Plugin = {}
---@param spec string | PluginSpec
---@return Plugin
function Plugin:new(spec)
  spec = to_array(spec)

  local plugin = setmetatable({}, self)
  self.__index = self

  plugin.name = spec.alias and spec.alias or vim.split(spec[1], "/")[2]
  plugin.url = "https://github.com/" .. spec[1]
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
function Plugin:installed()
  return uv.fs_stat(self.path) and true or false
end

---@return boolean
function Plugin:updated()
  Git:fetch(self, function(ok)
    if ok then

    end
  end)
  return false
end

Alpaca = {
  plugins = {},
  to_install = {},
  to_update = {},
  to_remove = {}
}

function Alpaca:install()
  print("Install!")
end

function Alpaca:update()
  print("Update!")
end

function Alpaca:remove()
  print("Remove!")
end

function Alpaca:load()
  print("Load!")
end

---@param specs (string | PluginSpec)[]
function Alpaca:setup(specs)
  vim.iter(specs):map(function(spec)
    return Plugin:new(spec)
  end):each(function(plugin)
    if not plugin:installed() then
      table.insert(self.to_install, plugin)
    elseif not plugin:updated() then
      table.insert(self.to_update, plugin)
    end
    table.insert(self.plugins, plugin)
  end)
  vim.iter(vim.fs.dir(AlpacaPath, { depth = 2 })):map(function(name, type)
    if name ~= "opt" and name ~= "start" and type == "directory" then
      local split = vim.split(name, "/")
      return { opt = split[1] == "opt" and true or false, name = split[2] }
    end
  end):each(function(installed)
    local loaded = vim.iter(self.plugins):map(function(plugin)
      return { name = plugin.name, opt = (plugin.event or plugin.cmd or plugin.ft) and true or false }
    end):find(function(plugin)
      return vim.deep_equal(plugin, installed)
    end)
    if not loaded then
      table.insert(self.to_remove, installed)
    end
  end)

  self:install()
  self:update()
  self:remove()
  self:load()
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
