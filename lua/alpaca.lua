local vim = vim

AlpacaPath = vim.fn.stdpath("data") .. "/site/pack/alpaca"

---@class Alpaca
---@field public setup function
---@field public install function
---@field public update function
---@field public clean function
---@field package clone function
---@field package pull function
---@field package git function
---@field private plugins Plugin[]

---@class PluginSpec
---@field [1] string
---@field version string?
---@field event (string | string[])?
---@field ft (string | string[])?
---@field cmd (string | string[])?
---@field config function?

---@class Plugin
---@field spec PluginSpec
---@field name string
---@field url string
---@field opt boolean
---@field path string
Plugin = {}

---@param spec string | PluginSpec
function Plugin:new(o, spec)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  if type(spec) == "string" then
    self.spec = { spec }
  else
    self.spec = spec
  end

  self.name = vim.split(self.spec[1], "/")[2]
  self.url = string.format("https://github.com/%s.git", self.spec[1])
  self.opt = (self.spec.event or self.spec.cmd or self.spec.ft) and true or false
  self.path = AlpacaPath .. (self.opt and "/opt/" or "/start/") .. self.name
end

---@return boolean
function Plugin:is_installed()
  return vim.uv.fs_stat(self.path) and true or false
end

---@param path string
---@return string[]
local function parse_installed(path)
  local installed = {}
  for _, sub in pairs({ "/opt", "/start" }) do
    for k, v in vim.fs.dir(path .. sub) do
      if v == "directory" then
        table.insert(installed, k)
      end
    end
  end
  return installed
end

---@param plugin Plugin
local function lazy_load(plugin)
  local group = vim.api.nvim_create_augroup("AlpacaLazy", {})
  if plugin.event or plugin.ft then
    local event = plugin.ft and "FileType" or plugin.event
    vim.api.nvim_create_autocmd(event, {
      group = group,
      callback = function()
        vim.cmd.packadd(plugin.name)
        if plugin.config then plugin.config() end
      end
    })
  elseif plugin.cmd then
    local cmds = type(plugin.cmd) == "string" and { plugin.cmd } or plugin.cmd
    ---@cast cmds string[]
    for _, cmd in pairs(cmds) do
      vim.api.nvim_create_user_command(cmd, function(opts)
        vim.cmd.packadd(plugin.name)
        if plugin.config then plugin.config() end
        vim.cmd({ cmd = cmd, args = opts.fargs, bang = opts.bang })
      end, {})
    end
  else
    vim.cmd.packadd(plugin.name)
  end
end

---@param args string[]
---@param cwd string?
---@param callback function
local function spawn_git(args, cwd, callback)
  local stderr = vim.uv.new_pipe(false)
  local spawn_args = { args = args, cwd = cwd, stdio = { nil, nil, stderr } }

  local handle, _ = vim.uv.spawn("git", spawn_args, function(code)
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
          callback(string.gsub(buffer, "\n", ""))
        end
      end)
    end
  end)

  if not handle then
    vim.notify("Failed to spawn git")
  end
end


---@type Alpaca
Alpaca = {
  plugins = {},

  clone = function()
  end,
  pull = function()
  end,
  git = function()
  end,

  setup = function()
  end,
  install = function()
  end,
  update = function()
  end,
  clean = function()
  end,
}




local M = {
  default_opts = {
    path = vim.fn.stdpath("data") .. "/site/pack/alpaca",
  },
  opts = {},
  plugins = {},
  installed = {},
}

---@param plugin Plugin
function M.is_installed(plugin)
  if vim.list_contains(M.installed, plugin.name) then
    return true
  else
    return false
  end
end

function M.install_all()
  vim.notify("[Alpaca.nvim] Checking for Installs")
  local counter = 0

  local to_install = {}
  for _, plugin in pairs(M.plugins) do
    if not M.is_installed(plugin) then
      table.insert(to_install, plugin)
    end
  end
  local total = #to_install

  if total == 0 then
    vim.notify("[Alpaca.nvim] Nothing to Install")
  end

  for _, plugin in pairs(to_install) do
    local args = { "clone", plugin.url, plugin.path, "--depth=1", "--recurse-submodules", "--shallow-submodules" }
    if plugin.version then
      vim.list_expand(args, { "--branch", plugin.version })
    end

    spawn_git(args, nil, vim.schedule_wrap(function(err)
      counter = counter + 1
      if not err then
        vim.notify(string.format("[Alpaca.nvim][%d/%d] %s Installed Successfully", counter, total, plugin.name))
      else
        vim.notify(string.format("[Alpaca.nvim][%d/%d] %s Failed to Install: %s", counter, total, plugin.name, err))
      end
      if counter == total then
        vim.notify("[Alpaca.nvim] Finished Installing Plugins")
      end
    end))
  end
end

function M.update_all()
  vim.notify("[Alpaca.nvim] Checking for Updates")
  local counter = 0

  local to_update = {}
  for _, plugin in pairs(M.plugins) do
    table.insert(to_update, plugin)
  end
  local total = #to_update

  if total == 0 then
    vim.notify("[Alpaca.nvim] Nothing to Update")
  end

  for _, plugin in pairs(to_update) do
    local args = { "pull", "--recurse-submodules", "--update-shallow" }

    spawn_git(args, plugin.path, vim.schedule_wrap(function(err)
      counter = counter + 1
      if not err then
        vim.notify(string.format("[Alpaca.nvim][%d/%d] %s Updated Successfully", counter, total, plugin.name))
      else
        vim.notify(string.format("[Alpaca.nvim][%d/%d] %s Update Failed: %s", counter, total, plugin.name, err))
      end
      if counter == total then
        vim.notify("[Alpaca.nvim] Finished Updating Plugins")
      end
    end))
  end
end

function M.remove_all()
end

---@param configs (string | Plugin)[]
---@param opts table?
function M.setup_v1(configs, opts)
  M.opts = opts and vim.tbl_deep_extend("force", M.default_opts, opts) or M.default_opts
  M.installed = parse_installed(M.opts.path)

  vim.api.nvim_create_augroup("AlpacaLazy", { clear = true })

  for _, config in pairs(configs) do
    local plugin = type(config) == "string" and { config } or config
    ---@cast plugin Plugin

    plugin.name = vim.split(plugin[1], "/")[2]
    plugin.url = string.format("https://github.com/%s.git", plugin[1])
    plugin.opt = (plugin.event or plugin.cmd or plugin.ft) and true or false
    plugin.path = M.opts.path .. (plugin.opt and "/opt/" or "/start/") .. plugin.name

    if M.is_installed(plugin) then
      if plugin.opt then
        lazy_load(plugin)
      elseif plugin.config then
        plugin.config()
      end
    end

    table.insert(M.plugins, plugin)
  end
end

---@param configs (string | Plugin)[]
---@param opts table?
function M.setup(configs, opts)
  M.opts = opts and vim.tbl_deep_extend("force", M.default_opts, opts) or M.default_opts
  M.installed = parse_installed(M.opts.path)

  vim.api.nvim_create_augroup("AlpacaLazy", { clear = true })

  for _, config in pairs(configs) do
    config = type(config) == "string" and { config } or config
  end
end

vim.api.nvim_create_user_command("AlpacaInstall", function()
  M.install_all()
end, {})
vim.api.nvim_create_user_command("AlpacaUpdate", function()
  M.update_all()
end, {})
vim.api.nvim_create_user_command("AlpacaClean", function()
  M.remove_all()
end, {})
vim.api.nvim_create_user_command("AlpacaSync", function()
  M.remove_all()
  M.update_all()
  M.install_all()
end, {})


return M
