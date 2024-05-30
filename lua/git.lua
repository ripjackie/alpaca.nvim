local uv = vim.uv or vim.loop

local git = {}
function git.run(cmd, path, callback)
  local handle
  local stdio = { nil, uv.new_pipe(false), uv.new_pipe(false) }
  local bufs = { nil, "", "" }

  local function read_into(index)
    return function (err, out)
      if err then
        return callback(false, err)
      elseif out then
        bufs[index] = bufs[index] .. out
      else
        stdio[index]:read_stop()
        stdio[index]:close()
      end
    end
  end

  handle = uv.spawn("git", { args = cmd, cwd = path, stdio = stdio }, function (code)
    handle:close()
    return callback(code == 0, code == 0 and bufs[2] or bufs[3])
  end)

  stdio[2]:read_start(read_into(2))
  stdio[3]:read_start(read_into(3))
end

function git.corun(cmd, path)
  local coro = coroutine.running()
  print(coro)
  git.run(cmd, path, function(ok, out)
    coroutine.resume(coro, ok, out)
  end)
  return coroutine.yield()
end

function git.clone(spec, branch, callback)
  local args = {
    "clone", "--depth=1", "--shallow-submodules",
    "--recurse-submodules", spec.url, spec.path, branch and "--branch=" .. branch
}
  return git.run(args, nil, callback)
end

function git.ls_remote_tags(spec)
  local range = vim.version.range(spec.tag)
  local args = {
    "ls-remote", "--tags", "--sort=-v:refname", spec.url, "*" .. tostring(range.from):gsub("0", "*")
  }
  local ok, out = git.corun(args, nil)
  if ok then
    for tag in out:gmatch("%w+\trefs/tags/(%C+)\n") do
      if range:has(tag) then
        return ok, tag
      end
    end
    return false, ("failed to find tag for plugin %s in range %s - %s"):format(spec.name, tostring(range.from), tostring(range.to))
  else
    return ok, out
  end
end

function git.get_url(path)
  local args = { "ls-remote", "--get-url" }
  return git.corun(args, path)
end

function git.rev_parse(path)
  local args = { "rev-parse", "HEAD" }
  return git.corun(args, path)
end

function git.describe(path)
  local args = { "describe", "--all" }
  return git.corun(args, path)
end
return git
