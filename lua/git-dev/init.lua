local augroup = vim.api.nvim_create_augroup("GitDev", { clear = true })

local M = {}

M.defaults = {
  -- Whether to delete an opened repository when nvim is closed.
  -- If `true`, it will create an auto command for opened repositories
  -- to delete the local directory when nvim exists.
  ephemeral = true,
  -- Set buffers of opened repositories to read-only and unmodifiable.
  read_only = true,
  -- Whether / how to CD into opened repository.
  -- Options: global|tab|window|none
  cd_type = "global",
  -- Accepts a repository directory path and opens it.
  -- This function does the "open" part of the repository.
  opener = function(dir)
    vim.cmd("edit " .. vim.fn.fnameescape(dir))
  end,
  -- Location of cloned repositories. Should be dedicated for this purpose.
  repositories_dir = vim.fn.stdpath "cache" .. "/git-dev",
  git = {
    -- Name / path of `git` command.
    command = "git",
    -- Default organization if none is specified.
    -- If given repository name does not contain '/' and `default_org` is
    -- not `nil` nor empty, it will be prepend to the given name.
    default_org = nil,
    -- Base URI to use when given repository name is scheme-less.
    base_uri_format = "https://github.com/%s.git",
    -- Arguments for `git clone`. Triggered when repository does not
    -- exist locally.
    -- It will clone submodules too, disable it if it is too slow.
    clone_args = "--depth=1 --jobs=2 --no-tags --single-branch "
      .. "--recurse-submodules --shallow-submodules",
    -- Arguments for `git fetch`. Triggered when repository is already exists
    -- locally to refresh the local copy.
    fetch_args = "--depth=1 --jobs=2 --no-all --update-shallow -f "
      .. "--prune --no-tags",
  },
  -- Show command outputs in :messages
  verbose = false,
}

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
  none = function(_) end,
}

-- Generates a function to trigger a deletion of `repo_path`
local function clean_repo_callback(repo_path)
  return function()
    local is_deleted = vim.fn.delete(repo_path, "rf")
    if M.defaults.verbose then
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

-- Opens a repository.
-- It will clone / refresh repository directory,
-- `repo` is either a scheme-less string or a Git URI.
-- `ref` = { branch = "..." } | { tag = "..." } | { "commit": "..." }
-- If more than one is specified, the priority is: `commit` > `tag` > `branch`
-- `opts` A table to override plugin settings.
M.open = function(repo, ref, opts)
  local config = vim.tbl_deep_extend("force", M.defaults, opts or {})

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
      vim.fn.system(
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
      vim.fn.system(
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
      vim.fn.system(
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

  config.opener(repo_path)

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

-- Clean all repositories in the repositories directory
-- DANGER: Make sure that the repositories directory is exclusive to
-- this plugin.
M.clean_all = function()
  vim.fn.delete(M.defaults.repositories_dir)
end

M.setup = function(opts)
  M.defaults = vim.tbl_deep_extend("force", M.defaults, opts or {})

  -- Create repositories directory if not exists.
  vim.fn.mkdir(M.defaults.repositories_dir, "p")

  -- Create commands
  vim.api.nvim_create_user_command("GitDevOpen", function(cmd_opts)
    vim.defer_fn(function()
      require("git-dev").open(unpack(cmd_opts.fargs))
    end, 0)
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
