local vim = vim
local uv = vim.uv or vim.loop

AlpacaPath = vim.fn.stdpath("data") .. "/site/pack/alpaca"

Plugins = {}
Installed = {
  iter = function()
    local it = vim.iter(vim.fs.dir(AlpacaPath, {depth=2}))
    return function()
      local name, type = it:next()
      while name do
        if type == "directory" and name ~= "opt" and name ~= "start" then
          local out = vim.split(name, "/")
          return {out[2], opt = out[1] == "opt" and true or false}
        else
          name, type = it:next()
        end
      end
    end
  end
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

---@package
---@param args string[]
---@param cwd string?
---@param callback function
local function spawn_git(args, cwd, callback)
  local stderr = uv.new_pipe(false)
  local spawn_args = { args = args, cwd = cwd, stdio = { nil, nil, stderr } }

  local handle, _ = uv.spawn("git", spawn_args, function(code)
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
          -- buffer = string.gsub(buffer, "\n", "")
          callback(buffer)
        end
      end)
    end
  end)

  if not handle then
    vim.notify("Failed to spawn git")
  end
end

---@class PluginSpec
---@field [1] string
---@field version string?
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

function Plugin:install()
  spawn_git(self.clone_args, nil, vim.schedule_wrap(function(err)
    local msg = "[Alpaca.nvim] [%s] (%s) %s"
    if err then
      vim.notify(string.format(msg, "Install", self.name, "Failure: " .. err))
    else
      vim.notify(string.format(msg, "Install", self.name, "Success"))
    end
  end))
end

function Plugin:update()
  spawn_git(self.pull_args, self.path, vim.schedule_wrap(function(err)
    local msg = "[Alpaca.nvim] [%s] (%s) %s"
    if err then
      vim.notify(string.format(msg, "Update", self.name, "Failure: " .. err))
    else
      vim.notify(string.format(msg, "Update", self.name, "Success"))
    end
  end))
end

function Plugin:load()
  if self.config then
    if self.opt then
      if self.event or self.ft then
        vim.api.nvim_create_autocmd(self.ft and "FileType" or self.event, {
          group = vim.api.nvim_create_augroup("AlpacaLazy", {}),
          callback = function()
            vim.cmd.packadd(self.name)
            self.config()
          end
        })
      elseif self.cmd then
        vim.tbl_map(function(cmd)
          vim.api.nvim_create_user_command(cmd, function(opts)
            vim.cmd.packadd(self.name)
            self.config()
            vim.cmd({ cmd = cmd, args = opts.fargs, bang = opts.bang })
          end, {})
        end, to_array(self.cmd))
      else
        vim.cmd.packadd(self.name)
        self.config()
      end
    else
      self.config()
    end
  end
end

local M = {}

---@param configs (string | PluginSpec)[]
function M.setup(configs)
  local to_install = {}
  local to_update = {}
  local to_clean = {}
  vim.api.nvim_create_augroup("AlpacaLazy", { clear = true })

  vim.iter(configs):each(function(config)
    local plugin = Plugin:new(config)
    if not plugin:is_installed() then
      table.insert(to_install, plugin)
    elseif plugin:needs_update() then
      table.insert(to_update, plugin)
    end
    table.insert(Plugins, plugin)
  end)

  vim.iter(Installed.iter()):each(function(plugin)
    if vim.list_contains(vim.iter.map(function(config) return {config.name, config.opt} end, Plugins)) then

  end)

end

return M
