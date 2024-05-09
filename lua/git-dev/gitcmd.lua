local GitCmd = {}

---@class GitCmd
---@field cmd? string : Path to `git` command. Default: "git".

---@param o GitCmd
function GitCmd:init(o)
  o = vim.tbl_deep_extend("force", { cmd = "git" }, o or {})
  setmetatable(o, self)
  self.__index = self
  return o
end

---Clones a git reporitory.
---@param repo_url string : Remote git repository URL.
---@param repo_dir string : Local path to git repository.
---@param branch? string : Optional branch to set.
---@param extra_args? string
function GitCmd:clone(repo_url, repo_dir, branch, extra_args)
  return vim.fn.systemlist(
    self.cmd
      .. " clone "
      .. (extra_args or "")
      .. " "
      .. (branch and " -b " .. branch or "")
      .. " "
      .. repo_url
      .. " "
      .. repo_dir
  )
end

---Checks out a branch, tag or commit.
---@param repo_dir string
---@param ref string
---@param extra_args? string
function GitCmd:checkout(repo_dir, ref, extra_args)
  return vim.fn.systemlist(
    self.cmd
      .. " -C "
      .. repo_dir
      .. " checkout "
      .. (extra_args or "")
      .. " "
      .. ref
  )
end

---Refreshes local objects and refs from remote.
---@param repo_dir string : Local path to git repository.
---@param extra_args? string
function GitCmd:refresh(repo_dir, extra_args)
  return vim.fn.systemlist(
    self.cmd .. " -C " .. repo_dir .. " fetch " .. (extra_args or "")
  )
end

---Hard resets a local repository to given reference.
---@param repo_dir string : Local path to git repository.
---@param ref? string
---@param extra_args? string
function GitCmd:reset(repo_dir, ref, extra_args)
  return vim.fn.systemlist(
    self.cmd
      .. " -C "
      .. repo_dir
      .. " reset --hard "
      .. (extra_args or "")
      .. " "
      .. (ref or "")
  )
end

---@class RemoteRef
---@field commit_id string
---@field ref string

---Lists all references in a repository by optional pattern.
---@param repo_url string : Remote git repository URL.
---@param pattern? string : An optional pattern to filter by.
---@return RemoteRef[]
function GitCmd:list_refs(repo_url, pattern)
  return vim.tbl_map(
    function(raw_ref)
      local ref = vim.fn.split(raw_ref, "\t")
      return { commit_id = ref[1], ref = ref[2] }
    end,
    vim.fn.systemlist(
      self.cmd .. " ls-remote -htq " .. repo_url .. " " .. (pattern or "")
    )
  )
end

return GitCmd
