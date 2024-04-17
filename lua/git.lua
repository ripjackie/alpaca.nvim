local vim = vim
local uv = vim.uv or vim.loop

local M = {}

local function run(cmd, path, callback)
    if callback then
        vim.system(cmd, { text = true, cwd = path }, function(obj)
            if obj.code == 0 then
                callback(obj.stdout)
            else
                vim.notify(obj.stderr)
                callback(nil)
            end
        end)
    else
        local obj = vim.system(cmd, { text = true, cwd = path }):wait()
        assert(obj.code == 0, obj.stderr)
        return obj.stdout
    end
end

function M.get_head_refs(path)
    local commit = run({ "git", "rev-parse", "HEAD" }, path):gsub('\n', '')
    local reftype, refname = run({ "git", "describe", "--all", "--exact-match" }, path):match("(%C+)/(%C+)\n")
    return {
        commit = commit,
        branch = reftype == "heads" and refname or nil,
        tag = reftype == "tags" and refname or nil
    }
end

function M.get_head_commit(path)
    return run({ "git", "rev-parse", "HEAD" }, path):gsub('\n', '')
end

function M.get_head_ref(path)
    local reftype, refname = run({ "git", "describe", "--all", "--exact-match" }, path):match("(%C+)/(%C+)\n")
    return {
        branch = reftype == "heads" and refname or nil,
        tag = reftype == "tags" and refname or nil
    }
end

function M.get_remote_tags(path)
end

function M.get_remote_branch(path)
end

function M.get_remote_repo(path)
    return run({ "git", "ls-remote", "--get-url" }, path):match("https://github.com/(%C+/%C+)%.git\n")
end

function M.clone_basic(url, path)
    run({ "git", "clone", "--depth=1", "--recurse-submodules", "--shallow-submodules", url, path }, nil)
end

return M
