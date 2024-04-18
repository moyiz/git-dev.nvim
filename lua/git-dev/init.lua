local M = {}

M.config = {
  --- Whether to delete an opened repository when nvim exits.
  --- If `true`, it will create an auto command for opened repositories
  --- to delete the local directory when nvim exists.
  ephemeral = true,
  -- Set buffers of opened repositories to be read-only and unmodifiable.
  read_only = true,
  -- Whether / how to CD into opened repository.
  -- Options: global|tab|window|none
  cd_type = "global",
  -- The actual `open` behavior.
  ---@param dir string The path to the local repository.
  ---@param repo_uri string The URI that was used to clone this repository.
  opener = function(dir, repo_uri)
    vim.print("Opening " .. repo_uri)
    vim.cmd("edit " .. vim.fn.fnameescape(dir))
  end,
  -- Location of cloned repositories. Should be dedicated for this purpose.
  repositories_dir = vim.fn.stdpath "cache" .. "/git-dev",
  git = {
    -- Name / path of `git` command.
    command = "git",
    -- Default organization if none is specified.
    -- If given repository name does not contain '/' and `default_org` is
    -- not `nil` nor empty, it will be prepended to the given name.
    default_org = nil,
    -- Base URI to use when given repository name is scheme-less.
    base_uri_format = "https://github.com/%s.git",
    -- Arguments for `git clone`.
    -- Triggered when repository does not exist locally.
    -- It will clone submodules too, disable it if it is too slow.
    clone_args = "--depth=1 --jobs=2 --no-tags --single-branch "
      .. "--recurse-submodules --shallow-submodules",
    -- Arguments for `git fetch`.
    -- Triggered when repository is already exists locally to refresh the local
    -- copy.
    fetch_args = "--depth=1 --jobs=2 --no-all --update-shallow -f "
      .. "--prune --no-tags",
  },
  -- Print command outputs.
  verbose = false,
}

--- CD command wrapper.
---@param cmd string A CD-like command (cd, lcd, tcd, ....).
---@return function(string,boolean) Invokes the CD-like command on given path.
---@private
local function change_directory(cmd)
  return function(path, silent)
    return vim.api.nvim_cmd(
      { cmd = cmd, args = { path }, mods = { silent = silent } },
      {}
    )
  end
end

local cd_func = {
  global = change_directory "cd",
  tab = change_directory "tcd",
  window = change_directory "lcd",
  none = function(_, _) end,
}

-- Generates a function to trigger a deletion of `repo_path`
local function clean_repo_callback(repo_path)
  return function()
    local is_deleted = vim.fn.delete(repo_path, "rf")
    if M.config.verbose then
      local msg
      if is_deleted == 0 then
        msg = "Deleted: " .. repo_path
      else
        msg = "Not found: " .. repo_path
      end
      vim.fn.notify(msg)
    end
  end
end

-- Generates a directory name from a Git URI.
-- If `branch` is given, it will be suffixed with "#branch"
-- "https://github.com/example/repo.git" => "github.com__example__repo"
local function git_uri_to_dir_name(uri, branch)
  local dir_name =
    uri:gsub("/+$", ""):gsub(".*://", ""):gsub("/", "__"):gsub(".git$", "")
  if branch and branch ~= "" then
    dir_name = dir_name .. "#" .. branch
  end
  return dir_name
end

-- Returns a valid git URI from `repo`.
-- It basically checks whether `repo` is already a URI,
-- and if not, it formats `base_uri` with it.
-- If `repo` does not contain '/' and `default_org` is given, prepend it.
local function git_uri(repo, default_org, base_uri)
  -- Check if `repo` has scheme or is ssh-like.
  if repo:match "://" or repo:match "@.*:" then
    return repo
  end
  if default_org and default_org ~= "" and not repo:match "/" then
    repo = default_org .. "/" .. repo
  end
  return base_uri:format(repo)
end

local augroup = vim.api.nvim_create_augroup("GitDev", { clear = true })

---@class GitRef Holds a reference for a repository. At least one field must
--- not be `nil`.
---@field branch string|nil
---@field tag string|nil
---@field commit string|nil

---Opens a repository.
---It will clone / refresh repository directory,
---@param repo string Git URI or repository name.
---@param ref GitRef If more than one is specified, the priority is:
--- `commit` > `tag` > `branch`
---@param opts table Override plugin settings.
M.open = function(repo, ref, opts)
  local config = vim.tbl_deep_extend("force", M.config, opts or {})

  if config.verbose then
    vim.print(repo, ref, config)
  end

  if ref == nil then
    ref = {}
  end

  local branch = ref.tag or ref.branch

  local repo_uri =
    git_uri(repo, config.git.default_org, config.git.base_uri_format)
  local repo_path = config.repositories_dir
    .. "/"
    .. git_uri_to_dir_name(repo_uri, ref.commit or branch)
  local output = {}

  if vim.fn.isdirectory(repo_path) == 1 then
    -- Refresh repo
    table.insert(output, "GitDev: Refreshing " .. repo_path)
    table.insert(
      output,
      vim.fn.systemlist(
        config.git.command
          .. " -C "
          .. repo_path
          .. " fetch "
          .. config.git.fetch_args
      )
    )
  else
    -- Fresh clone
    table.insert(
      output,
      vim.fn.systemlist(
        config.git.command
          .. " clone "
          .. config.git.clone_args
          .. " "
          .. (branch and " -b " .. branch or "")
          .. " "
          .. repo_uri
          .. " "
          .. repo_path
      )
    )
    if vim.fn.isdirectory(repo_path) == 0 then
      if config.verbose then
        vim.notify(vim.fn.join(output, "\n"))
      end
      vim.notify("Repository not found at: " .. repo_uri .. ", aborting...")
      return false
    end
  end

  -- Reset to commit hash if specified.
  if ref.commit then
    table.insert(
      output,
      vim.fn.systemlist(
        config.git.command
          .. " -C "
          .. repo_path
          .. " reset --hard "
          .. ref.commit
      )
    )
  end

  if config.verbose then
    vim.notify(vim.fn.join(output, "\n"))
  end

  if config.ephemeral then
    -- Delete repository directory when vim exits.
    vim.api.nvim_create_autocmd({ "VimLeavePre" }, {
      group = augroup,
      callback = clean_repo_callback(repo_path),
    })
  end

  config.opener(repo_path, repo_uri)

  -- CD into repository directory
  cd_func[config.cd_type](vim.fn.fnameescape(repo_path), not config.verbose)

  if config.read_only then
    -- Set all buffers in the repository directory as read-only
    -- and unmodifiable.
    vim.api.nvim_create_autocmd({ "BufReadPost" }, {
      group = augroup,
      pattern = repo_path .. "*",
      callback = function()
        vim.cmd "setlocal readonly nomodifiable"
      end,
    })
  end
end

---Clean all repositories in the repositories directory
---DANGER: Make sure that the repositories directory is exclusive to
---this plugin.
M.clean_all = function()
  vim.fn.delete(M.config.repositories_dir)
end

---Module Setup
---@param opts table|nil Module config table. See |M.config|.
M.setup = function(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  -- Create repositories directory if not exists.
  vim.fn.mkdir(M.config.repositories_dir, "p")

  -- Create commands
  vim.api.nvim_create_user_command("GitDevOpen", function(cmd_args)
    local repo, ref, cmd_opts = unpack(cmd_args.fargs)
    if ref then
      ref = load("return " .. ref)()
    end
    if cmd_opts then
      cmd_opts = load("return " .. cmd_opts)()
    end
    require("git-dev").open(repo, ref, cmd_opts)
  end, {
    desc = "Open a git repository.",
    nargs = "*",
  })

  vim.api.nvim_create_user_command("GitDevCleanAll", function(_)
    require("git-dev").clean_all()
  end, {
    desc = "Deletes the repositories directory. CAUTION: be careful "
      .. "with custom paths.",
  })
end

return M
