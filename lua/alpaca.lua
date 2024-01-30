local vim = vim
local uv = vim.uv or vim.loop

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
---@param callback fun(err: string?, ok: boolean, stdout: string?, stderr: string?): nil
function Git:spawn(args, cwd, callback)
  local stdout = uv.new_pipe(false)
  local stderr = uv.new_pipe(false)

  ---@param pipe userdata
  ---@param pipe_callback fun(err: string?, data: string?): nil
  local function read_pipe(pipe, pipe_callback)
    local buffer = ""
    pipe:read_start(function(err, data)
      if err then
        pipe_callback(err, nil)
      elseif data then
        buffer = buffer .. data
      else
        pipe:close()
        if buffer == "" then
          pipe_callback(nil, nil)
        else
          pipe_callback(nil, buffer)
        end
      end
    end)
  end

  local function on_exit(code)
    read_pipe(stdout, function(stdout_err, out_data)
      if stdout_err then
        callback(stdout_err, false, nil, nil)
      else
        stdout:close()
        read_pipe(stderr, function(stderr_err, err_data)
          if stderr_err then
            callback(stderr_err, false, nil, nil)
          else
            stderr:close()
            callback(stderr_err, code == 0, out_data, err_data)
          end
        end)
      end
    end)
  end

  local handle = uv.spawn("git", {
    args = args,
    cwd = cwd,
    stdio = { nil, stdout, stderr }
  }, on_exit)

  if not handle then
    callback("Could not spawn git", false, nil, nil)
  end
end

---@param plugin Plugin
---@param callback fun(err: string?): nil
function Git:fetch(plugin, callback)
  local symbolic_ref_args = { "symbolic-ref", "--quiet", "--short", "refs/remotes/origin/HEAD" }
  self:spawn(symbolic_ref_args, plugin.path, function(branch_err, branch_ok, branch_stdout, branch_stderr)
    if branch_err or not branch_ok then
      callback("[Alpaca.nvim] Error getting remote branch name: " .. branch_err or branch_stderr)
    else
      local branch = plugin.branch or branch_stdout:match("^%s*(.-)%s*$") or "master"
      local fetch_args = { "fetch", "origin", branch, "--tags" }
      self:spawn(fetch_args, plugin.path, function(fetch_err, fetch_ok, _, fetch_stderr)
        if fetch_err or not fetch_ok then
          callback("[Alpaca.nvim] Error while fetching: " .. fetch_err or fetch_stderr)
        else
          callback(nil)
        end
      end)
    end
  end)
end

---@param plugin Plugin
---@param callback fun(err: string?): nil
function Git:clone(plugin, callback)
  local clone_args = {
    "clone", "--depth=1", "--recurse-submodules", "--shallow-submodules", "--no-checkout",
    plugin.url, plugin.path
  }
  self:spawn(clone_args, nil, function(err, ok, _, stderr)
    if err or not ok then
      callback("[Alpaca.nvim] Error cloning repo: " .. err or stderr)
    else
      callback(nil)
    end
  end)
end

---@param plugin Plugin
---@param callback fun(err: string?): nil
function Git:checkout(plugin, callback)
  local checkout_args = { "checkout" }
  if plugin.tag then
    local tag_spec = vim.version.range(plugin.tag)
    local foreachref_args = { "for-each-ref", "--sort=-refname", "--format='%(refname:short)'", "refs/tags" }
    self:spawn(foreachref_args, plugin.path, function(err, ok, ref_stdout, stderr)
      if err or not ok then
        callback("[Alpaca.nvim] Error during for-each-ref: " .. err or stderr)
      else
        local current_tag_args = { "describe", "--tags", "--exact-match" }
        self:spawn(current_tag_args, plugin.path, function(err, ok, curr_stdout, stderr)
          if err or not ok then
            callback("[Alpaca.nvim] Error during describe: " .. err or stderr)
          else
            local current_tag = vim.version.parse(curr_stdout)
            local it = vim.iter(vim.split(ref_stdout, '\n')):map(function(tag)
              local tag_semver = vim.version.parse(tag)
              if tag_spec:has(tag_semver) and not vim.version.le(tag_semver, current_tag) then
                return tag
              end
            end)
            local new_tag = it:next()
            if new_tag then
              table.insert(checkout_args, new_tag)
              self:spawn(checkout_args, plugin.path, function(err, ok, _, stderr)
                if err or not ok then callback("[Alpaca.nvim](checkout) Error: " .. err or stderr) end
                callback(nil)
              end)
            end
          end
        end)
      end
    end)
  elseif plugin.branch then
    table.insert(checkout_args, plugin.branch)
    self:spawn(checkout_args, plugin.path, function(err, ok, _, stderr)
      if err or not ok then
        callback("[Alpaca.nvim] Error during checkout: " .. err or stderr)
      else
        callback(nil)
      end
    end)
  end
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

  return plugin
end

local Alpaca = {
}

local M = {}
function M.setup(specs)
end
return M
