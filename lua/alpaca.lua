local vim = vim
local uv = vim.uv or vim.loop


local Git = {}
---@param args string[]
---@param cwd string?
---@param callback fun(err: string?, ok: boolean, stdout: string?, stderr: string?): nil
function Git:spawn(args, cwd, callback)
  local stdout = uv.new_pipe(false)
  local stderr = uv.new_pipe(false)

  local function read_pipe(pipe, callback)
    local buffer = ""
    pipe:read_start(function(err, data)
      if err then
        callback(err, nil)
      elseif data then
        buffer = buffer .. data
      else
        pipe:close()
        callback(nil, buffer)
      end
    end)
  end

  local function on_exit(code)
    read_pipe(stdout, function(err, out_data)
      if err then
        callback(err, false, nil, nil)
      else
        stdout:close()
        read_pipe(stderr, function(err, err_data)
          stderr:close()
          callback(err, code == 0, out_data, err_data)
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
---@param callback fun(err: string?, ok: boolean): nil
function Git:fetch(plugin, callback)
  local symbolic_ref_args = {
    "symbolic-ref", "--quiet", "--short", "refs/remotes/origin/HEAD"
  }
  self:spawn(symbolic_ref_args, plugin.path, function(err, ok, stdout)
    if err then
      callback("Err getting remote branch name: " .. err, false)
    elseif ok then
      local branch = plugin.branch or stdout:match("^%s*(.-)%s*$") or "master"
      local fetch_args = { "fetch", "origin", branch, "--tags" }
      self:spawn(fetch_args, plugin.path, function(err, ok)
        if err then
          callback("Error While Fetching: " .. err, false)
        else
          callback(nil, ok)
        end
      end)
    else
      callback(nil, ok)
    end
  end)
end

--

---@param plugin Plugin
---@param callback fun(err: string, ok: boolean): nil
function Git:fetch(plugin, callback)
  -- Get the remote branch name
  local symbolic_ref_args = {"symbolic-ref", "--quiet", "--short", "refs/remotes/origin/HEAD"}
  self:spawn(symbolic_ref_args, plugin.path, function(err_branch, ok_branch, stdout_branch)
    if err_branch then
      callback("Error getting remote branch name: " .. err_branch, false)
      return
    end

    -- Determine the branch to fetch
    local branch = plugin.branch or stdout_branch:match("^%s*(.-)%s*$") or "master"

    -- Fetch the specified branch along with tags
    local fetch_args = {"fetch", "origin", branch, "--tags"}
    self:spawn(fetch_args, plugin.path, function(err_fetch, ok_fetch)
      if err_fetch then
        callback("Error while fetching: " .. err_fetch, false)
      else
        callback(nil, ok_fetch)
      end
    end)
  end)
end


--

local Plugin = {}
function Plugin:new(spec)
end

local Alpaca = {}

local M = {}
function M.setup(specs)
end
return M
