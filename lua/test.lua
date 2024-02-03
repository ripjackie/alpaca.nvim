local obj = vim.system({
  "git", "for-each-ref", "refs/tags", "--sort=-version:refname","--no-merged=HEAD", "--format=%(refname:short)"
}, { cwd = vim.fn.expand("~") .. "/indent-blankline.nvim" }):wait()
vim.print(obj)

local obj = vim.system({
  "git", "for-each-ref", "refs/tags", "--sort=-version:refname","--no-merged=HEAD", "--format=%(refname:short)"
}, {}):wait()
vim.print(obj)

local obj = vim.system({
  "git", "for-each-ref", "refs/heads", "--contains=HEAD", "--format=%(upstream:trackshort)"
}, { cwd = vim.fn.expand("~") .. "/indent-blankline.nvim" }):wait()
vim.print(obj)

local obj = vim.system({
  "git", "for-each-ref", "refs/heads", "--contains=HEAD", "--format=%(upstream:trackshort)"
}, {}):wait()
vim.print(obj)

