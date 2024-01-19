WIP very alpha

My own personal package manager.
It's not going to be fancy, it's not going to do a whole lot.
My main goals:
- lazy loading
- configs
- learn lua

to bootstrap:

`init.lua`:

```
local alpacapath = vim.fn.stdpath("data") .. "/site/pack/alpaca/start/alpaca.nvim"
if not vim.uv.fs_stat(alpacapath) then -- vim.loop.fs_stat for before neovim 0.10.0
  vim.fn.system({
    "git", "clone", "--depth=1",
    "https://github.com/ripjackie/alpaca.nvim.git",
    alpacapath
  })
end

require("alpaca").setup({
  "ripjackie/alpaca.nvim", -- can also manage itself ( like paq-nvim )
  ...
})
```
