local uv = vim.uv or vim.loop

local PluginPath = vim.fn.stdpath("data") .. "/site/pack/alpaca"
local DefaultOpts = {
  install_on_start = true
}

local util = {}
function util.to_table(value)
  return type(value) ~= "table" and {value} or value
end

function util.log(msg, level)
  vim.schedule(function()
    vim.notify("[Alpaca.nvim] " .. msg, level)
  end)
end


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
  git.run(cmd, path, function(ok, out)
    coroutine.resume(coro, ok, out)
  end)
  return coroutine.yield()
end

function git.clone(spec, callback)
  return git.run({
    "clone", "--depth=1", "--shallow-submodules", "--recurse-submodules",
    branch and "--branch=" .. branch, url, path
  }, nil, callback)
end

function git.ls_remote_tags(spec)
  local range = vim.version.range(spec.tag)
  local ok, out = git.corun({
    "ls-remote", "--tags", "--sort=-v:refname", spec.url, "*" .. tostring(range.from):gsub("0", "*")
  }, nil) 
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
  return git.corun({ "ls-remote", "--get-url" }, path)
end

function git.rev_parse(path)
  return git.corun({ "rev-parse", "HEAD" }, path)
end

function git.describe(path)
  return git.corun({ "describe", "--all" }, path)
end


local function parse_plugins()
  local plugins = {}
  for filename, filetype in vim.fs.dir(PluginPath, { depth = 2 }) do
    if filetype == "directory" and filename:find("/") then
      local opttype, plugname = filename:match("(%C+)/(%C+)")
      local fullpath = ("%s/%s"):format(PluginPath, filename)

      local _, remote = git.get_url(fullpath)
      local _, commit = git.rev_parse(fullpath)
      local _, ref = git.describe(fullpath)

      local repo = remote:match("https://github.com/(%C+/%C+).git")

      if repo then
        plugins[repo] = {
          name = plugname,
          opt = opttype == "opt" and true or false,
          commit = commit:match("(%w+)"),
          tag = ref:match("tags/(%C+)"),
          branch = ref:match("heads/(%C+)"),
        }
      end
    end
  end
  return plugins
end

local function parse_spec(spec)
  spec = util.to_table(spec)
  spec.url = ("https://github.com/%s.git"):format(spec[1])
  spec.name = spec.as or spec[1]:match("%C+/(%C+)")
  spec.opt = spec.opt or (spec.event or spec.cmd or spec.ft) and true or false
  spec.path = ("%s/%s/%s"):format(PluginPath, spec.opt and "opt" or "start", spec.name)
  return spec
end

local function install_spec(spec, callback)
  if spec.tag then
    local ok, out = git.ls_remote_tags(spec)
    if ok then 
      return git.clone(spec.url, spec.path, out, callback)
    else
      return callback(ok, out)
    end
  else
    return git.clone(spec.url, spec.path, spec.branch, callback)
  end
end

local function load_spec(spec)
  local do_config = function()
    if spec.config and type(spec.config) == "function" then
      vim.schedule(spec.config)
    end
  end

  if spec.event or spec.cmd or spec.ft then
    local alpaca_group = vim.api.nvim_create_augroup("AlpacaOptLoad")
    if spec.event then
      spec.event = util.to_table(spec.event)
      vim.api.nvim_create_autocmd(spec.event, {
        group = alpaca_group,
        callback = function ()
          vim.cmd.packadd(spec.name)
          do_config()
        end
      })
    elseif spec.cmd then
      print("TODO")
      vim.cmd.packadd(spec.name)
      do_config()
    elseif spec.ft then
      spec.ft = util.to_table(spec.ft)
      vim.api.nvim_create_autocmd("FileType", {
        group = alpaca_group,
        pattern = table.concat(spec.ft, ','),
        callback = function ()
          vim.cmd.packadd(spec.name)
          do_config()
        end
      })
    end
  else
    do_config()
  end
  print("load " .. spec[1])
end

function setup(specs, opts)
  opts = opts and vim.tbl_deep_extend("force", DefaultOpts, opts) or DefaultOpts

  local plugins = parse_plugins()
  local to_install = {}

  print(vim.inspect(plugins))

  for _, spec in ipairs(specs) do
    print(vim.inspect(spec))
    spec = parse_spec(spec)
    local plugin = plugins[spec[1]]
    if plugin then
      load_spec(spec)
    else
      table.insert(to_install, spec)
    end
  end

  if #to_install > 0 then
    local total = #to_install
    local curr = 0
    util.log(("[%d/%d] Installing Packages"):format(curr, total))
    for _, spec in ipairs(to_install) do
      install_spec(spec, function(ok, out)
        curr = curr + 1
        if ok then
          util.log(("[%d/%d] Install Success: %s"):format(curr, total, spec.name))
          load_spec(spec)
        else
          util.log(("[%d/%d] Install Failure: %s"):format(curr, total, spec.name))
        end
      end)
    end
  end
end

local M = {}

function M.setup(specs, opts)
  coroutine.wrap(setup)(specs, opts)
end

return M
