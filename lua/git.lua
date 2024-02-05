local vim = vim
local uv = vim.uv or vim.loop


local Git = {}

---@param cmd string
---@param plugin string?
---@param err string
function Git:err(cmd, plugin, err)
  return string.format("[Alpaca.nvim][FAILURE]{%s}(%s) %s", cmd, plugin, err)
end

---@param args string[]
---@param cwd string?
---@param callback fun(ok: boolean, stdout: string?, stderr: string?): nil
function Git:spawn(args, cwd, callback)
  local stdio = { nil, uv.new_pipe(false), uv.new_pipe(false) }

  local function read_pipe(pipe, pipe_callback)
    local buffer = ""
    pipe:read_start(function(err, data)
      assert(not err, self:err("spawn", "", err))
      if data then
        buffer = buffer .. data
      else
        pipe_callback(buffer)
      end
    end)
  end

  local function on_exit(code)
    read_pipe(stdio[2], function(stdout)
      read_pipe(stdio[3], function(stderr)
        callback(code == 0, stderr, stdout)
      end)
    end)
  end

  local handle = uv.spawn("git", {
    args = args, cwd = cwd, stdio = stdio
  }, on_exit)
  assert(handle, self:err("spawn", "", "Failed to spawn git"))
end

---@param plugin Plugin
---@param callback fun(ok: boolean): nil
function Git:init(plugin, callback)
  local args = { "init", plugin.path }
  self:spawn(args, nil, function(ok, stderr)
    assert(ok, self:err("git init", plugin.name, stderr))
    self:remote_add(plugin, callback)
  end)
end

---@param plugin Plugin
---@param callback fun(ok: boolean): nil
function Git:remote_add(plugin, callback)
  local args = { "remote", "add", "origin", plugin.url }
  self:spawn(args, plugin.path, function(ok, stderr)
    assert(ok, self:err("git remote add", plugin.name, stderr))
    callback(ok)
  end)
end

---@param plugin Plugin
---@param callback fun(ok: boolean): nil
function Git:fetch(plugin, callback)
  local args = { "fetch", "origin" }
  if plugin.branch then
    table.insert(args, plugin.branch)
  end
  self:spawn(args, plugin.path, function(ok, _, stderr)
    assert(ok, self:err("git fetch", plugin.name, stderr))
    callback(ok)
  end)
end

---@param plugin Plugin
---@param callback fun(tags: string[]): nil
function Git:list_tags(plugin, callback)
  local args = {
    "for-each-ref", "refs/tags", "--sort=-v:refname",
    "--format='%(refname:short)'", "--omit-empty", "--no-merged=HEAD"
  }
  self:spawn(args, plugin.path, function(ok, stderr, stdout)
    assert(ok, self:err("git for-each-ref", plugin.name, stderr))
    callback(vim.split(stdout, '\n'))
  end)
end

---@param plugin Plugin
---@param callback fun(stdout: string?): nil
function Git:symbolic_ref(plugin, callback)
  local args = { "symbolic-ref", "--short", "-q", "HEAD" }
  self:spawn(args, plugin.path, function(ok, stderr, stdout)
    assert(ok, self:err("git symbolic-ref", plugin.name, stderr))
    callback(stdout)
  end)
end

---@param plugin Plugin
---@param args string[]?
---@param callback fun(ok: boolean): nil
function Git:checkout(plugin, args, callback)
  if args then
    self:spawn(args, plugin.path, function(ok, stderr)
      assert(ok, self:err("git checkout", plugin.name, stderr))
      callback(ok)
    end)
  elseif plugin.tag then
    self:list_tags(plugin, function(tags)
      local range = vim.version.range(plugin.tag)
      local new_tag = vim.iter(tags):find(function(tag)
        return range:has(tag)
      end)
      if new_tag then
        self:checkout(plugin, { "checkout", new_tag }, callback)
      end
    end)
  elseif plugin.branch then
    self:checkout(plugin, { "checkout", plugin.branch }, callback)
  else
    self:symbolic_ref(plugin, function(stdout)
      self:checkout(plugin, { "checkout", stdout }, callback)
    end)
  end
end

