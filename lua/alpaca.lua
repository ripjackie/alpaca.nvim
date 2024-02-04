local vim = vim
local uv = vim.uv or vim.loop
local co = coroutine

---@alias Path string

AlpacaPath = vim.fn.stdpath("data") .. "/site/pack/alpaca"

---@generic T
---@param input T | T[]
---@return T[]
local function to_array(input)
  if type(input) == "string" then
    return {input}
  else
    return input
  end
end

local Git = {}

---@param args string[]
---@param cwd string?
function Git:spawn(args, cwd)
  local main_thread = co.running()
  local stdio = { nil, uv.new_pipe(false), uv.new_pipe(false) }

  local function on_exit(code)
    local cb_thread = co.running()
    local function read_pipe(pipe)
      local buffer = ""
      pipe:read_start(function(err, data)
        if data then
          buffer = buffer .. data
        else
          co.resume(cb_thread, err, buffer)
        end
      end)
      return co.yield()
    end

    local stdout_err, stdout = read_pipe(stdio[2])
    assert(not stdout_err, stdout_err)
    local stderr_err, stderr = read_pipe(stdio[3])
    assert(not stderr_err, stderr_err)
    co.resume(main_thread, code, stdout, stderr)
  end

  local handle = uv.spawn("git", {
    args = args,
    cwd = cwd,
    stdio = stdio
  }, co.wrap(on_exit))
  if handle then
    return co.yield()
  end
end

---@param plugin Plugin
function Git:init(plugin)
  print("init " .. plugin.name)
  local code = Git:spawn({ "init", plugin.path }, nil)
  assert(code == 0, "Failed to init repo @ " .. plugin.path)

  print("add remote " .. plugin.name)
  local code = Git:spawn({ "remote", "add", "origin", plugin.url }, plugin.path)
  assert(code == 0, "Failed to add remote " .. plugin.url)

  print("fetch " .. plugin.name)
  local args = { "fetch", "origin" }
  if plugin.branch then
    table.insert(args, plugin.branch)
  end
  local code = Git:spawn(args, plugin.path)
  assert(code == 0, "Failed to fetch " .. plugin.name)

  print("checkout " .. plugin.name)
  local args = { "checkout" }
  if plugin.tag then
    local range = vim.version.range(plugin.tag)
    local code, stdout = Git:spawn({ "tag", "--sort=-refname"}, plugin.path)
    assert(code == 0, "Failed to run Tag")
    local tag = vim.iter(ipairs(vim.split(stdout, '\n'))):map(function(_, spec)
      return spec
    end):find(function(spec)
      return range:has(spec)
    end)
    table.insert(args, tag)
  elseif plugin.branch then
    print("branch!")
    table.insert(args, plugin.branch)
  end

  print(vim.inspect(args))
  local code = Git:spawn(args, plugin.path)
  assert(code == 0, "Failed to Run Checkout")
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
---@field path Path
---@field branch string?
---@field tag string?
---@field config function?
---@field opt boolean
---@field event string[]?
---@field cmd string[]?
---@field ft string[]?
---@field installed boolean
---@field updated boolean
local Plugin = {}

---@param spec string | PluginSpec
function Plugin:new(spec)
  spec = to_array(spec) --[[@as PluginSpec]]
  local plugin = setmetatable({}, self)
  self.__index = self

  plugin.branch = spec.branch
  plugin.tag = spec.tag
  plugin.config = spec.config
  plugin.event = spec.event and to_array(spec.event)
  plugin.cmd = spec.cmd and to_array(spec.cmd)
  plugin.ft = spec.ft and to_array(spec.cmd)

  plugin.name = spec.as or vim.split(spec[1], "/")[2]
  plugin.url = "http://github.com/" .. spec[1]
  plugin.opt = (plugin.event or plugin.cmd or plugin.ft) and true or false
  plugin.path = AlpacaPath .. (plugin.opt and "/opt/" or "/start/") .. plugin.name

  plugin.installed = vim.uv.fs_stat(plugin.path) and true or false
  plugin.updated = self:check_updates()
  return plugin
end

---@return boolean
function Plugin:check_updates()
  if not self.installed then
    return false
  elseif self.branch then
    -- 
  elseif self.tag then
    --
  else
    --
  end
end


local Alpaca = {
  to_install = {},
  to_update = {},
  to_remove = {}
}

function Alpaca:install()
  vim.iter(ipairs(self.to_install)):map(function(_, plugin)
    return co.create(function()
      Git:init(plugin)
      Git:add_remote(plugin)
      Git:fetch(plugin)
      Git:checkout(plugin)
    end)
  end):each(function(coro)
    co.resume(coro)
  end)
end

---@param specs (string | PluginSpec)[]
function Alpaca:setup(specs)
  assert(specs and not vim.tbl_isempty(specs), "No Specs Supplied")
  vim.iter(specs):map(function(spec)
    return Plugin:new(spec)
  end):each(function(plugin)
    if not plugin.installed then
      table.insert(self.to_install, plugin)
    end
  end)

  self:install()
end

local M = {
  setup = coroutine.wrap(Alpaca.setup)
}

M.setup = coroutine.wrap(function(specs)
  Alpaca:setup(specs)
end)

M.setup({
  {
    "lukas-reineke/indent-blankline.nvim",
    tag = "v3.5.x"
  },
  {
    "altermo/ultimate-autopair.nvim",
    branch = "v0.6"
  }
})
