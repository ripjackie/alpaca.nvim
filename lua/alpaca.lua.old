local uv = vim.uv or vim.loop

local git = {}

---@param plugin Plugin
---@param callback fun(err: string?): nil
function git:clone(plugin, callback)
  local args = { "git", "clone", "--depth=1", "--recurse-submodules", "--shallow-submodules", plugin.url, plugin.path }
	local opts = { text = true }

  vim.system(args, opts, function(obj)
		callback(obj.code == 0 and nil or obj.stderr)
  end)
end

---@param plugin Plugin
---@param callback fun(err: string?): nil
function git:fetch(plugin, callback)
  local args = { "git", "fetch", "origin" }
	local opts = { cwd = plugin.path, text = true }
  if plugin.branch then
    table.insert(args, plugin.branch)
  elseif plugin.tag then
    table.insert(args, "--tags")
  end
  vim.system(args, opts, function(obj)
		callback(obj.code == 0 and nil or obj.stderr)
  end)
end

---@param plugin Plugin
---@param callback fun(err: string?, tags: string[]?): nil
function git:list_tags(plugin, callback)
	local args = { "git", "for-each-ref", "refs/tags", "--format=%(refname:short)", "--contains=HEAD", "--sort=-v:refname" }
	local opts = { cwd = plugin.path, text = true }

  local obj = vim.system(args, opts, function(obj)
		if obj.code == 0 then
			callback(nil, vim.split(vim.trim(obj.stdout), '\n'))
		else
			callback(obj.stderr, nil)
		end
	end)
end

---@param plugin Plugin
---@param callback fun(err: string?): nil
---@param args string[]?
function git:checkout(plugin, callback, args)
	if args then
		args = vim.list_extend({ "git", "checkout" }, args)
		local opts = { cwd = plugin.path, text = true }

		vim.system(args, opts, function(obj)
			callback(obj.code == 0 and nil or obj.stderr)
		end)	

	elseif plugin.tag then
		self:list_tags(plugin, vim.schedule_wrap(function(err, tags)
			if err then
				callback(err)
			end
			local range = vim.version.range(plugin.tag)
			local tag = vim.iter(tags):find(function(tag)
				if tag == '' then return false end
				return range:has(tag)
			end)
			if tag then
				self:checkout(plugin, callback, { tag }) 
			else
				callback("[Alpaca.nvim] (debug) Failure to find a new tag")
			end
		end))

	elseif plugin.branch then
		self:checkout(plugin, callback, { plugin.branch })

	else
		self:checkout(plugin, callback, {})

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
---@field path string
---@field branch string?
---@field tag string?
---@field config function?
---@field opt boolean
---@field event string[]?
---@field cmd string[]?
---@field ft string[]?
local Plugin = {}

---@param spec string | PluginSpec
---@return Plugin
function Plugin:new(spec)
  local to_array = function(inp) return type(inp) == "string" and {inp} or inp end
  spec = to_array(spec) --[[@as PluginSpec]]

  local plugin = setmetatable({}, self)
  self.__index = self

  plugin.branch = spec.branch
  plugin.tag = spec.tag

  plugin.config = spec.config

  plugin.opt = (spec.event or spec.cmd or spec.ft) and true or false
  plugin.event = spec.event and to_array(spec.event)
  plugin.cmd = spec.cmd and to_array(spec.cmd)
  plugin.ft = spec.ft and to_array(spec.ft)

  plugin.name = spec.as or vim.split(spec[1], "/")[2]
  plugin.url = "http://github.com/" .. spec[1] .. ".git"
  plugin.path = vim.fn.stdpath("data") .. "/site/pack/alpaca" .. (plugin.opt and "/opt/" or "/start/") .. plugin.name

  return plugin
end

---@param dir string -- dir is of shape '{opt,start}/name'
---@return Plugin
function Plugin:from_installed(dir)
  local plugin = setmetatable({}, self)
  self.__index = self

  local split_val = vim.split(dir, '/')
  assert(#split_val == 2, "[Alpaca.nvim] (debug) Invalid installed spec provided: " .. dir)

  plugin.opt = split_val[1] == "opt" and true or split_val[1] == "start" and false
  plugin.name = split_val[2]
  plugin.url = ""
  plugin.path = vim.fn.stdpath("data") .. "/site/pack/alpaca" .. (plugin.opt and "/opt/" or "/start/") .. plugin.name

  return plugin
end

---@param callback fun(err: string?): nil
function Plugin:install(callback)
  git:clone(self, vim.schedule_wrap(function(err)
    if err then callback(err) end
    git:checkout(self, vim.schedule_wrap(callback))
  end))
end

---@param callback fun(err: string?): nil
function Plugin:update(callback)
  git:fetch(self, vim.schedule_wrap(function(err)
    if err then callback(err) end
    git:checkout(self, vim.schedule_wrap(callback))
  end))
end

function Plugin:clean()
  local function recurse_rm(path)
    assert(string.find(path, vim.fn.stdpath("data") .. "/site/pack/alpaca"), "[Alpaca.nvim] (debug) File path not in Alpaca's Heirarchy!")
    vim.iter(vim.fs.dir(path)):each(function(name, type)
      if type == "file" then
        uv.fs_unlink(vim.fs.joinpath(path, name))
      elseif type == "directory" then
        recurse_rm(vim.fs.joinpath(path, name))
      end
    end)
    uv.fs_rmdir(path)
  end
  if self:installed() then
    recurse_rm(self.path)
  end
end

function Plugin:load()
  if self:installed() then
    if self.event then
      vim.api.nvim_create_autocmd(self.event, {
        callback = function()
          vim.cmd.packadd(self.name)
          if vim.is_callable(self.config) then
              self.config()
          end
        end
      })
    elseif self.cmd then
      vim.print("[Alpaca.nvim] (debug) ["..self.name.."] Lazy loading via cmd not yet implemented! ( sorry! ), loading plugin")
      vim.cmd.packadd(self.name)
      if vim.is_callable(self.config) then
        self.config()
      end
    elseif self.ft then
      vim.api.nvim_create_autocmd("FileType", {
        pattern = self.ft,
        callback = function()
          vim.cmd.packadd(self.name)
          if vim.is_callable(self.config) then
            self.config()
          end
        end
      })
    elseif self.config then
      if vim.is_callable(self.config) then
        self.config()
      end
    end
  end
end

---@return boolean
function Plugin:installed()
  return uv.fs_stat(self.path) ~= nil
end

local Alpaca = {
  plugins = {},
  to_install = {}
}

---@param total integer
---@param operation string
function Alpaca:msg(total, operation)
	local fmt = "[Alpaca.nvim] (%s) [%d/%d] (%s) [%s] %s"
  local fin = "[Alpaca.nvim] (%s) [done]"
  local counter = 0
  ---@param name string
  ---@param err string?
  return function(name, err)
    counter = counter + 1
    if err then
      vim.print(string.format(fmt, operation, counter, total, name, "failure", err))
    else
      vim.print(string.format(fmt, operation, counter, total, name, "success", ""))
    end
    if counter == total then
      vim.print(string.format(fin, operation))
    end
  end
end

function Alpaca:install_all()
	vim.print("[Alpaca.nvim] (install) [start]")
  local msg = self:msg(#self.to_install, "install")
  vim.iter(self.to_install):each(function(plugin)
    ---@cast plugin Plugin
    plugin:install(vim.schedule_wrap(function(err)
      msg(plugin.name, err)
      if not err then
        plugin:load()
      end
    end))
  end)
end

function Alpaca:update_all()
	vim.print("[Alpaca.nvim] (update) [start]")
  local msg = self:msg(#self.plugins, "update")
  vim.iter(self.plugins):each(function(plugin)
    ---@cast plugin Plugin
    plugin:update(vim.schedule_wrap(function(err)
      msg(plugin.name, err)
    end))
  end)
end

function Alpaca:clean_all()
	vim.print("[Alpaca.nvim] (clean) [start]")
  local path = vim.fn.stdpath("data") .. "/site/pack/alpaca"
  vim.iter(vim.fs.dir(path, { depth = 2 })):map(function(name, type)
    return type == "directory" and string.find(name, '/') and Plugin:from_installed(name)
  end):each(function(installed_plugin)
    local loaded = vim.iter(self.plugins):find(function(plugin)
      return installed_plugin.name == plugin.name and installed_plugin.opt == plugin.opt
    end)
    if not loaded then
      print("[Alpaca.nvim] (debug) cleaning: ", installed_plugin.path)
      installed_plugin:clean()
    end
  end)
	vim.schedule(function()vim.print("[Alpaca.nvim] (clean) [done]")end)
end

function Alpaca:create_autocmds()
  vim.api.nvim_create_user_command("AlpacaUpdate", function()
    Alpaca:update_all()
  end, {})
  vim.api.nvim_create_user_command("AlpacaClean", function()
    Alpaca:clean_all()
  end, {})
end


local M = {}

---@param specs (string | PluginSpec)[]
function M.setup(specs)
  Alpaca:create_autocmds()
  vim.iter(ipairs(specs)):each(function(_, spec)
    local plugin = Plugin:new(spec)
    if not plugin:installed() then
      table.insert(Alpaca.to_install, plugin)
    else
      plugin:load()
    end
    table.insert(Alpaca.plugins, plugin)
  end)
  if #Alpaca.to_install > 0 then
    Alpaca:install_all()
  end
end

return M
