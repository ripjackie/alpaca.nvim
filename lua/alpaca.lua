local uv = vim.uv or vim.loop
local git = require("git")

local PluginPath = vim.fn.stdpath("data") .. "/site/pack/alpaca"
local DefaultOpts = {
  install_on_start = true
}

local Plugins = {}


local util = {}
function util.to_table(value)
  return type(value) ~= "table" and {value} or value
end

function util.log(msg, level)
  vim.schedule(function()
    vim.notify("[Alpaca.nvim] " .. msg, level)
  end)
end


local function load_commands(opts)
  if not opts.install_on_start then
    -- create AlpacaInstall
    vim.api.nvim_create_user_command("AlpacaInstall", function ()
      install_all()
    end)
  end
  -- create AlpacaUpdate
  -- create AlpacaClean
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

local function install_all()
  if #to_install > 0 then
    local total = #to_install
    local curr = 0
    local errors = {}
    util.log(("[%d/%d] Installing Packages"):format(curr, total))
    for _, spec in ipairs(to_install) do
      install_spec(spec, function(ok, out)
        curr = curr + 1
        if ok then
          util.log(("[%d/%d] Install Success: %s"):format(curr, total, spec.name))
          load_spec(spec)
        else
          util.log(("[%d/%d] Install Failure: %s"):format(curr, total, spec.name))
          table.insert(errors, { name = spec.name, err = out })
          print(vim.inspect(errors))
        end
        if curr == total then
          if #errors > 0 then
            util.log("Errors: " .. vim.inspect(errors))
          else
            util.log("Install Success")
          end
        end
      end)
    end
  end
end

local function update_all()
end

local function clean_all()
end

local function install_spec(spec, callback)
  if spec.tag then
    local ok, out = git.ls_remote_tags(spec)
    if ok then 
      return git.clone(spec, out, callback)
    else
      return callback(ok, out)
    end
  else
    return git.clone(spec, spec.branch, callback)
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

-- dev notes
-- i need to establish a method of doing all this, easily.
-- 1. wrap everything around a plugins table. (save this in a file?)
-- 2. go through the specs table to build the plugins[repo].spec tables
-- 3. go through the install directory to build the plugins[repo].install tables
local PluginPath = vim.fn.stdpath("data") .. "/site/pack/alpaca"

local DefaultOpts = {
  install_on_start = true
}


function setup_v2(specs, opts)
  vim.validate({
    specs = { specs, "table" },
    opts = { opts, { "table", "nil" } }
  })

  opts = opts and vim.tbl_deep_extend("force", DefaultsOpts, opts) or DefaultOpts


  -- Create Commands
  if opts.install_on_start then
    vim.api.nvim_create_user_command("AlpacaInstall", function ()
      install_plugins()
    end)
  end
  vim.api.nvim_create_user_command("AlpacaUpdate", function ()
    update_plugins()
  end)
  vim.api.nvim_create_user_command("AlpacaClean", function ()
    clean_plugins()
  end)


  -- Parse Specs Table -> Plugins
  for _, spec in ipairs(specs) do
    spec = util.to_table(spec)
    if spec[1]:match("%C+/%C+") then
      spec.repo = spec[1]
      spec.url = ("https://github.com/%s.git"):format(spec.repo)
      spec.name = spec.as or spec.repo:match("%C+/(%C+)")
      spec.opt = spec.opt or ( spec.event or spec.cmd or spec.ft ) and true or false
      spec.path = ("%s/%s/%s"):format(PluginPath, spec.opt and "opt" or "start", spec.name)
      Plugins[spec.repo] = { spec = spec }
    end
  end


  -- Parse Local Installs -> Plugins
  for filename, filetype in vim.fs.dir(PluginPath, { depth = 2 }) do
    if filetype == "directory" and filename:find("/") then

    end
  end
end

function setup(specs, opts)
  opts = opts and vim.tbl_deep_extend("force", DefaultOpts, opts) or DefaultOpts

  load_commands(opts)

  local plugins = parse_plugins()
  local to_install = {}


  for _, spec in ipairs(specs) do
    spec = parse_spec(spec)
    local plugin = plugins[spec[1]]
    if plugin then
      load_spec(spec)
    else
      table.insert(to_install, spec)
    end
  end

  if opts.install_on_start then
    install_all()
  end
end

local M = {}

function M.setup(specs, opts)
  coroutine.wrap(setup)(specs, opts)
end

return M
