local vim = vim
local uv = vim.uv or vim.loop
local coro = coroutine

local coGit = {}

function coGit:spawn(args, cwd)
  local main_coro = coro.running()
  assert(main_coro, "Spawn function must be called from within a coroutine!")
  local stdio = { nil, uv.new_pipe(false), uv.new_pipe(false) }

  local function read_pipe(pipe)
    local pipe_coro = coro.running()
    local buffer = ""
    pipe:read_start(function(err, data)
      if err then
        coro.resume(pipe_coro, err, nil)
      elseif data then
        buffer = buffer .. data
      else
        pipe:close()
        coro.resume(pipe_coro, nil, buffer)
      end
    end)
    return coro.yield()
  end

  local function on_exit(code)
    local err, stdout = read_pipe(stdio[2])
    assert(not err, err)
    local err, stderr = read_pipe(stdio[3])
    assert(not err, err)
    coro.resume(main_coro, code == 0, stdout, stderr)
  end

  local handle = uv.spawn("git", {
    args = args, cwd = cwd, stdio = stdio
  }, coro.wrap(on_exit))
  if handle then
    return coro.yield()
  else
    stdio[2]:close()
    stdio[3]:close()
    error("Failed to spawn git")
  end
end

function coGit:init(plugin)
  local init_args = { "init", plugin.path }
  local ra_args = { "remote", "add", "origin", plugin.url }

  local init_ok, _, init_stderr = self:spawn(init_args, nil)
  assert(init_ok, init_stderr)

  local ra_ok, _, ra_stderr = self:spawn(ra_args, plugin.path)
  assert(ra_ok, ra_stderr)

end

function coGit:fetch(plugin)
  local args = { "fetch", "origin" }

  if plugin.branch then
    table.insert(args, plugin.branch)
  end

  local fetch_ok, _, fetch_stderr = self:spawn(args, plugin.path)
  assert(fetch_ok, fetch_stderr)
end

function coGit:checkout(plugin)
  local co_args = { "checkout" }

  if plugin.tag then
    print()
  elseif plugin.branch then
    table.insert(co_args, plugin.branch)
  else
    local 
    print()
  end

  local co_ok, _, co_stderr = self:spawn(co_args, plugin.path)
  assert(co_ok, co_stderr)
end


local cbGit = {}

---@param cmd string
---@param plugin string?
---@param err string
function cbGit:err(cmd, plugin, err)
  return string.format("[Alpaca.nvim][FAILURE]{%s}(%s) %s", cmd, plugin, err)
end

---@param args string[]
---@param cwd string?
---@param callback fun(ok: boolean, stdout: string?, stderr: string?): nil
function cbGit:spawn(args, cwd, callback)
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
function cbGit:init(plugin, callback)
  local args = { "init", plugin.path }
  self:spawn(args, nil, function(ok, stderr)
    assert(ok, self:err("git init", plugin.name, stderr))
    self:remote_add(plugin, callback)
  end)
end

---@param plugin Plugin
---@param callback fun(ok: boolean): nil
function cbGit:remote_add(plugin, callback)
  local args = { "remote", "add", "origin", plugin.url }
  self:spawn(args, plugin.path, function(ok, stderr)
    assert(ok, self:err("git remote add", plugin.name, stderr))
    callback(ok)
  end)
end

---@param plugin Plugin
---@param callback fun(ok: boolean): nil
function cbGit:fetch(plugin, callback)
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
function cbGit:list_tags(plugin, callback)
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
function cbGit:symbolic_ref(plugin, callback)
  local args = { "symbolic-ref", "--short", "-q", "HEAD" }
  self:spawn(args, plugin.path, function(ok, stderr, stdout)
    assert(ok, self:err("git symbolic-ref", plugin.name, stderr))
    callback(stdout)
  end)
end

---@param plugin Plugin
---@param args string[]?
---@param callback fun(ok: boolean): nil
function cbGit:checkout(plugin, args, callback)
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


local git = {}

function git:clone(plugin)
  local args = { "git", "clone", "--depth=1", "--recurse-submodules", "--shallow-submodules", plugin.url, plugin.path }
  local obj = vim.system(args, { text = true })
  vim.print(obj)
end

function git:fetch(plugin)
end

function git:checkout(plugin)
end


