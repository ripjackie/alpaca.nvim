local vim = vim
local uv = vim.uv or vim.loop

local function spawn(args, cwd)
  print("Hello Git Spawn!")
  local thread = coroutine.running()
  local stdout = uv.new_pipe(false)
  local handle = uv.spawn("git", {
    args = args,
    cwd = cwd,
    stdio = { nil, stdout, nil }
  }, function(code, signal)
    local buffer = ""
    stdout:read_start(vim.schedule_wrap(function(err, data)
      if err then
        coroutine.resume(thread, err, nil, code, signal)
      elseif data then
        buffer = buffer .. data
      else
        print(buffer)
        coroutine.resume(thread, nil, buffer, code, signal)
      end
    end))
  end)
  assert(handle, "Failed to spawn git")
  return coroutine.yield()
end

local Git = {
  spawn = coroutine.wrap(function(self, args, cwd)
    local function _spawn()
      print("Hello Git Spawn!")
      local thread = coroutine.running()
      local stdout = uv.new_pipe(false)
      local handle = uv.spawn("git", {
        args = args,
        cwd = cwd,
        stdio = { nil, stdout, nil }
      }, function(code, signal)
        local buffer = ""
        stdout:read_start(vim.schedule_wrap(function(err, data)
          if err then
            coroutine.resume(thread, err, nil, code, signal)
          elseif data then
            buffer = buffer .. data
          else
            print(buffer)
            coroutine.resume(thread, nil, buffer, code, signal)
          end
        end))
      end)
      assert(handle, "Failed to spawn git")
      return coroutine.yield()
    end
    return _spawn()
  end)
}

local co = coroutine.wrap(function()
  local err, data, code, signal = spawn({"describe", "--tags"}, "/home/ripjackie/alpaca.nvim")
  print(err)
  print(data)
  print(code)
  print(signal)
end)

local err, data, code, signal = Git:spawn({"describe", "--tags"}, "/home/ripjackie/alpaca.nvim")
print(err)
print(data)
print(code)
print(signal)
