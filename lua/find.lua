local vim = vim
vim.system({"git", "ls-remote", "--symref", "origin", "HEAD"}, { text = true, cwd = "./ultimate-autopair.nvim"}, function(obj)
  -- print(vim.inspect(obj))
  local _, _, branch = obj.stdout:find("^ref: refs/heads/([%w%.]+)\tHEAD\n")
  -- print(branch)
end)

vim.system({ "git", "ls-remote", "--symref", "origin" }, { text = true, cwd = "./ultimate-autopair.nvim"}, function(obj)
  print(vim.inspect(obj))
  local head_ref = obj.stdout:match("ref: (refs/heads/[%w%.]+)")
  for commit, ref in obj.stdout:gmatch("(%w+)\t(refs/heads/[%w%.]+)\n") do
    print(commit, ":", ref)
  end
end)
