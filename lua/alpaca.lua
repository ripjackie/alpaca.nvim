local vim = vim
local uv = vim.uv

local Plugin = {}
function Plugin:new(spec)
end

local alpaca = {}

local alpaca.dir = vim.fs.joinpath(vim.fn.stdpath("data") .. "site/pack/alpaca")
local alpaca.path = vim.fs.joinpath(alpaca.dir, "start/alpaca.nvim")
local alpaca.plugin_file = vim.fs.joinpath(alpaca.dir, "plugins.json")

function alpaca.install()
end

function alpaca.update()
end

function alpaca.load_installed(callback)
  return uv.fs_open(alpaca.plugin_file, function(err, fd)
    if err then return callback(err) end
    return uv.fs_stat(fd, function(err, stat)
      if err then
        return uv.fs_close(function(c_err)
          if c_err then
            return callback(c_err + "..." + err)
          else
            return callback(err)
          end
        end)
      end
      return uv.fs_read(fd, stat.size, 0, function(err, data)
        if err then
          return uv.fs_close(function(c_err)
            if c_err then
              return callback(c_err + "..." + err)
            else
              return callback(err)
            end
          end)
        end
        return callback(vim.json.decode(data))
      end)
    end)
  end)
end

function alpaca.store_installed()
end


local M = {}

function M.setup(specs)
  vim.validate{
    specs={specs, "table"}
  }

  for _, spec in ipairs(specs) do
    spec = type(spec) ~= "table" and {spec} or spec --[[@as PluginSpec]]
    local plugin = Plugin:new(spec)
  end
end

return M
