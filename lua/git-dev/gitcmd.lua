local uv = vim.uv

local GitCmd = {}

---@class GitCmd
---@field cmd? string : Path to `git` command. Default: "git".
---@on_output func? : Invoked on each line of output

---@param o GitCmd
function GitCmd:init(o)
  o = vim.tbl_deep_extend(
    "force",
    { cmd = "git", on_output = function() end },
    o or {}
  )
  setmetatable(o, self)
  self.__index = self
  return o
end

---Spawns a command and returns its handle and std{out,err} pipes.
---@param cmd string
function GitCmd:_spawn(cmd, callback)
  local stdout = uv.new_pipe()
  local stderr = uv.new_pipe()

  local handle
  handle = uv.spawn(
    "sh",
    { args = { "-c", cmd }, stdio = { nil, stdout, stderr } },
    function(code)
      if callback then
        callback(code)
      end
      if handle then
        handle:close()
      end
      stdout:read_stop()
      stdout:close()
      stderr:read_stop()
      stderr:close()
    end
  )

  uv.read_start(stdout, self.on_output)
  uv.read_start(stderr, self.on_output)

  return { handle = handle, stdout = stdout, stderr = stderr }
end

---@class CloneOpts
---@field repo_url string : Remote git repository URL.
---@field repo_dir string : Local path to git repository.
---@field branch? string : Optional branch to set.
---@field extra_args? string

---Clones a git reporitory.
---@param opts CloneOpts
---@param callback? function
function GitCmd:clone(opts, callback)
  return self:_spawn(
    self.cmd
      .. " clone "
      .. (opts.extra_args or "")
      .. " "
      .. (opts.branch and " -b " .. opts.branch or "")
      .. " "
      .. opts.repo_url
      .. " "
      .. opts.repo_dir,
    callback
  )
end

---@class CheckoutOpts
---@field repo_dir string
---@field ref string
---@field extra_args? string

---Checks out a branch, tag or commit.
---@param opts CheckoutOpts
---@param callback? function
function GitCmd:checkout(opts, callback)
  return self:_spawn(
    self.cmd
      .. " -C "
      .. opts.repo_dir
      .. " checkout "
      .. (opts.extra_args or "")
      .. " "
      .. opts.ref,
    callback
  )
end

---@class RefreshOpts
---@field repo_dir string : Local path to git repository.
---@field extra_args? string

---Refreshes local objects and refs from remote.
---@param opts RefreshOpts
---@param callback? function
function GitCmd:refresh(opts, callback)
  return self:_spawn(
    self.cmd .. " -C " .. opts.repo_dir .. " fetch " .. (opts.extra_args or ""),
    callback
  )
end

---@class ResetOpts
---@field repo_dir string : Local path to git repository.
---@field ref? string
---@field extra_args? string

---Hard resets a local repository to given reference.
---@param opts ResetOpts
---@param callback? function
function GitCmd:reset(opts, callback)
  return self:_spawn(
    self.cmd
      .. " -C "
      .. opts.repo_dir
      .. " reset --hard "
      .. (opts.extra_args or "")
      .. " "
      .. (opts.ref or ""),
    callback
  )
end

---@class RemoteRef
---@field commit_id string
---@field ref string

---Lists all references in a repository by optional pattern.
---Synchronous.
---@param repo_url string : Remote git repository URL.
---@param pattern? string : An optional pattern to filter by.
---@return RemoteRef[]
function GitCmd:list_refs_sync(repo_url, pattern)
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
