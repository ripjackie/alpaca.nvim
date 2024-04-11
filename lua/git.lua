local uv = vim.uv or vim.loop

local M = {}

function M.get_remote_tags(path)
end

function M.get_remote_branch(path)
end

function M.get_remote_repo(path)
    local obj = vim.system(
        { "git", "ls-remote", "--get-url" },
        { text = true, cwd = path }
    ):wait()
    assert(obj.code == 0, obj.stderr)
    return obj.stdout:match("https://github.com/(.+/.+).git\n")
end

function M.get_head_ref(path)
    local obj = vim.system(
        { "git", "describe", "--all", "--exact-match" },
        { text = true, cwd = path }
    ):wait()
    assert(obj.code == 0, obj.stderr)
    local reftype, refname = obj.stdout:match("(%w+)/(.+)\n")

    obj = vim.system(
        { "git", "rev-parse", "HEAD" },
        { text = true, cwd = path }
    ):wait()
    assert(obj.code == 0, obj.stderr)
    local commit = obj.stdout:gsub('\n', '')

    return {
        tag = reftype == "tags" and refname or nil,
        branch = reftype == "heads" and refname or nil,
        commit = commit
    }
end

function M.clone_basic(url, path)
    local obj = vim.system(
        { "git", "clone", "--depth=1", "--recurse-submodules",
          "--shallow-submodules", url, path },
        { text = true }
    ):wait()
    return obj.code == 0 and nil or obj.stderr
end

return M
