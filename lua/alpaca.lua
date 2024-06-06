local vim = vim
local uv = vim.uv or vim.loop
local alpacapath = vim.fn.stdpath("data") .. "/site/pack/alpaca"


local git = {}

git.spawn = function (args, cwd, callback)
  local stdout = uv.new_pipe(false)
  local stderr = uv.new_pipe(false)
  local buffers = { stdout = "", stderr = "" }

  local on_pipe = function (buffer)
    return function (err, data)
      if err then
        return callback(false, err)
      elseif data then
        buffers[buffer] = buffers[buffer] .. data
      end
    end
  end
  local on_exit = function (code)
    local ok = code == 0
    return callback(ok, ok and buffers.stdout or buffers.stderr)
  end

  local handle = uv.spawn("git", {
    args = args, stdio = { nil, stdout, stderr }, cwd = cwd, verbatim = true
  }, on_exit)

  assert(handle, "Failed to spawn git with args: " .. vim.inspect(args))

  stdout:read_start(on_pipe("stdout"))
  stderr:read_start(on_pipe("stderr"))
end

git.cospawn = function (args, cwd)
  local coro = coroutine.running()
  assert(coro, "Failed to find Coroutine")
  git.spawn(args, cwd, function (ok, out)
    return coroutine.resume(coro, ok, out)
  end)
  return coroutine.yield()
end

git.rev_parse = function (path)
  return git.cospawn({ "rev-parse", "HEAD" }, path)
end

git.get_remote_url = function (path)
  return git.cospawn({ "ls-remote", "--get-url" }, path)
end

git.describe = function (path)
  return git.cospawn({ "describe", "--all", "--exact-match" }, path)
end


local util = {}

util.to_table = function (input)
  if type(input) ~= "table" then
    return {input}
  else
    return input
  end
end


local plugins = {}

plugins.find = function (self, remote)
  for index, plugin in ipairs(self) do
    if plugin.remote == remote then
      return index
    end
  end
end

plugins.insert = function (self, plugin)
  local remote = plugin.spec and plugin.spec.url or plugin.install and plugin.install.remote
  assert(remote, "[Alpaca] Failed to find remote in plugin " .. vim.inspect(plugin))
  local index = self:find(remote)
  if not index then
    plugin.remote = remote
    table.insert(self, plugin)
  elseif plugin.install and not plugin.spec then
    self[index].install = plugin.install
  end
end


local M = {}

M._setup = function (specs)

  for _, spec in ipairs(specs) do
    spec = util.to_table(spec)
    spec.url = spec.url or spec[1] and ("https://github.com/%s.git"):format(spec[1]:match("(%C+/%C+)"))
    assert(spec.url, "[Alpaca] Failed to find remote url in spec for " .. vim.inspect(spec))
    spec.name = spec.as or spec.url:match("https://%C+/%C+/(%C+)"):gsub(".git", "")
    spec.opt = (spec.event or spec.cmd or spec.ft) ~= nil
    spec.path = alpacapath .. (spec.opt and "/opt/" or "/start/") .. spec.name
    plugins:insert({ spec = spec })
  end

  for filename, filetype in vim.fs.dir(alpacapath, { depth = 2 }) do
    if filetype == "directory" and filename:find("/") then
      local fullpath = alpacapath .. "/" .. filename
      local ok, commit = git.rev_parse(fullpath)
      local ok, remote = git.get_remote_url(fullpath)
      local ok, ref = git.describe(fullpath)
      print(vim.inspect({
        fullpath = fullpath,
        commit = commit,
        remote = remote,
        ref = ref
      }))
    end
  end

  print(vim.inspect(plugins))
end

M.setup = function (specs)
  coroutine.wrap(M._setup)(specs)
end

return M
