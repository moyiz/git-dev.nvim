local M = {}

M.config = {
  -- Whether to delete an opened repository when nvim exits.
  -- If `true`, it will create an auto command for opened repositories
  -- to delete the local directory when nvim exists.
  ephemeral = true,
  -- Set buffers of opened repositories to be read-only and unmodifiable.
  read_only = true,
  -- Whether / how to CD into opened repository.
  -- Options: global|tab|window|none
  cd_type = "global",
  -- The actual `open` behavior.
  ---@param dir string The path to the local repository.
  ---@param repo_uri string The URI that was used to clone this repository.
  ---@param selected_path? string A relative path to a file in this repository.
  opener = function(dir, repo_uri, selected_path)
    M.ui:print("Opening " .. repo_uri)
    local dest =
      vim.fn.fnameescape(selected_path and dir .. "/" .. selected_path or dir)
    vim.cmd("edit " .. dest)
  end,
  -- Location of cloned repositories. Should be dedicated for this purpose.
  repositories_dir = vim.fn.stdpath "cache" .. "/git-dev",
  -- Extend the builtin URL parsers.
  -- Should map domains to parse functions. See |parser.lua|.
  extra_domain_to_parser = nil,
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
    clone_args = "--jobs=2 --single-branch --recurse-submodules "
      .. "--shallow-submodules --progress",
    -- Arguments for `git fetch`.
    -- Triggered when repository is already exists locally to refresh the local
    -- copy.
    fetch_args = "--jobs=2 --no-all --update-shallow -f --prune --no-tags",
    -- Arguments for `git checkout`.
    -- Triggered when a branch, tag or commit is given.
    checkout_args = "-f --recurse-submodules",
  },
  -- UI configuration.
  ui = {
    -- Auto-close window after repository was opened.
    auto_close = true,
    -- Delay window closing.
    close_after_ms = 3000,
    -- Window mode.
    -- Options: floating|split
    mode = "floating",
    -- Window configuration for floating mode.
    -- See `:h nvim_open_win`.
    ---@type win_config
    floating_win_config = {
      title = "git-dev",
      title_pos = "center",
      anchor = "NE",
      style = "minimal",
      border = "rounded",
      relative = "editor",
      width = 79,
      height = 9,
      row = 1,
      col = vim.o.columns,
      noautocmd = true,
    },
    -- Window configuration for split mode.
    -- See `:h nvim_open_win`.
    ---@type win_config
    split_win_config = {
      split = "right",
      width = 79,
      noautocmd = true,
    },
  },
  -- History configuration.
  history = {
    -- Maximum number of records to keep in history.
    n = 32,
    -- Store file path.
    path = vim.fn.stdpath "data" .. "/git-dev/history.json",
  },
  -- More verbosity.
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

-- Generates a function to trigger a deletion of `repo_dir`
local function clean_repo_callback(repo_dir)
  return function()
    vim.print("Cleaning " .. repo_dir)
    local is_deleted = vim.fn.delete(repo_dir, "rf")
    if M.config.verbose then
      local msg
      if is_deleted == 0 then
        msg = "Deleted: " .. repo_dir
      else
        msg = "Not found: " .. repo_dir
      end
      vim.print(msg)
    end
  end
end

-- Generates a directory name from a Git URI.
-- If `branch` is given, it will be suffixed with "#branch"
-- "https://github.com/example/repo.git" => "github.com__example__repo"
local function git_uri_to_dir_name(uri, branch)
  local dir_name =
    uri:gsub("/+$", ""):gsub(".*://", ""):gsub("[/:]", "__"):gsub(".git$", "")
  if branch and branch ~= "" then
    dir_name = dir_name .. "#" .. branch:gsub("/", "__")
  end
  return dir_name
end

local augroup = vim.api.nvim_create_augroup("GitDev", { clear = true })

---@class GitRef Holds a reference for a repository. At least one field must
--- not be `nil`.
---@field branch? string
---@field tag? string
---@field commit? string

---Opens a repository.
---It will clone / refresh repository directory,
---@param repo string Git URI or repository name.
---@param ref? GitRef If more than one is specified, the priority is:
--- `commit` > `tag` > `branch`.
---@param opts? table Override plugin settings.
M.open = function(repo, ref, opts)
  if not repo then
    vim.notify "Missing repository. See |:h git-dev-usage-open|"
    return
  end
  ref = ref or {}

  local config = vim.tbl_deep_extend("force", M.config, opts or {})
  local ui = M.ui
  ui:show()

  local gitcmd = require("git-dev.gitcmd"):init {
    cmd = config.git.command,
    on_output = function(err, data)
      if data and config.verbose then
        ui:print(data)
      end
      if err then
        ui:print("ERROR: " .. err)
      end
    end,
  }
  local parser = require("git-dev.parser"):init {
    gitcmd = gitcmd,
    base_uri_format = config.git.base_uri_format,
    extra_domain_to_parser = config.extra_domain_to_parser,
  }

  ui:print("Parsing: " .. repo)
  local parsed_repo = parser:parse(repo)
  local branch = ref.commit
    or ref.tag
    or ref.branch
    or parsed_repo.commit
    or parsed_repo.branch

  if not branch and parsed_repo.full_blob then
    ui:print "Could not detect branch / tag / commit in given URI."
  end

  local repo_dir = config.repositories_dir
    .. "/"
    .. git_uri_to_dir_name(parsed_repo.repo_url, branch)

  if config.verbose then
    ui:print(parsed_repo)
  end

  local post_action_callback = vim.schedule_wrap(function()
    if vim.fn.isdirectory(repo_dir) == 0 then
      ui:print(
        "Repository not found at: " .. parsed_repo.repo_url .. ", aborting..."
      )
      return false
    end
    if branch then
      ui:print "Making sure that the correct branch / tag is checked out..."
      gitcmd:checkout {
        repo_dir = repo_dir,
        ref = branch,
        extra_args = config.git.checkout_args,
      }
    end

    if config.ephemeral then
      ui:print "Ephemeral mode: creating autocmd to cleanup when nvim exits..."
      -- Delete repository directory when vim exits.
      vim.api.nvim_create_autocmd({ "VimLeavePre" }, {
        group = augroup,
        callback = clean_repo_callback(repo_dir),
      })
    end

    -- CD into repository directory
    cd_func[config.cd_type](vim.fn.fnameescape(repo_dir), not config.verbose)

    -- Open directory (or selected path)
    config.opener(repo_dir, parsed_repo.repo_url, parsed_repo.selected_path)

    if config.read_only then
      -- Set all buffers in the repository directory as read-only
      -- and unmodifiable.
      ui:print("Setting read only mode for " .. repo_dir)
      vim.api.nvim_create_autocmd({ "BufReadPost" }, {
        group = augroup,
        pattern = repo_dir .. "*",
        callback = function()
          vim.cmd "setlocal readonly nomodifiable"
        end,
      })
    end

    -- Add this call to history store.
    M.history:add(repo, ref, opts, parsed_repo)

    ui:print "Done."
    if config.ui.auto_close then
      ui:close(config.ui.close_after_ms)
    end
  end)

  if vim.fn.isdirectory(repo_dir) == 1 then
    ui:print "Repository directory exists, refreashing..."
    gitcmd:refresh(
      { repo_dir = repo_dir, extra_args = config.git.fetch_args },
      post_action_callback
    )
  else
    -- Fresh clone
    ui:print "Repository does not exist locally, cloning..."
    gitcmd:clone({
      repo_url = parsed_repo.repo_url,
      repo_dir = repo_dir,
      branch = parsed_repo.branch,
      extra_args = config.git.clone_args,
    }, post_action_callback)
  end
end

---Clean all repositories in the repositories directory
---DANGER: Make sure that the repositories directory is exclusive to
---this plugin.
M.clean_all = function()
  vim.fn.delete(M.config.repositories_dir)
end

---Parses a Git URL.
---@param repo string
---@return GitRepo
M.parse = function(repo, opts)
  local config = vim.tbl_deep_extend("force", M.config, opts or {})
  local gitcmd = require("git-dev.gitcmd"):init { cmd = config.git.command }
  local parser = require("git-dev.parser"):init {
    gitcmd = gitcmd,
    base_uri_format = config.git.base_uri_format,
    extra_domain_to_parser = config.extra_domain_to_parser,
  }
  return parser:parse(repo)
end

---Toggle UI Window
---@param win_config? vim.api.keyset.win_config
M.toggle_ui = function(win_config)
  M.ui:toggle(win_config)
end

---Module Setup
---@param opts? table Module config table. See |M.config|.
M.setup = function(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  -- Create needed directories if non existent.
  vim.fn.mkdir(M.config.repositories_dir, "p")
  vim.fn.mkdir(vim.fs.dirname(M.config.history.path), "p")

  -- Prepare UI
  local win_config
  if M.config.ui.mode == "split" then
    local v = vim.version()
    -- `nvim_open_win` supports splitting in Neovim>=0.10.0
    -- `ge` was added in 0.10.0.
    if vim.version.lt({ v.major, v.minor, v.patch }, { 0, 10, 0 }) == false then
      win_config = M.config.ui.split_win_config
    else
      vim.notify(
        "Split mode is not supported in Neovim < 0.10.0. "
          .. "Falling back to floating mode."
      )
      win_config = M.config.ui.floating_win_config
    end
  else
    win_config = M.config.ui.floating_win_config
  end
  M.ui = require("git-dev.ui"):init {
    win_config = win_config,
  }

  -- Initialize store
  ---@type GitDevHistory
  M.history = require("git-dev.history"):init(M.config.history)

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

  vim.api.nvim_create_user_command("GitDevToggleUI", function(_)
    require("git-dev").toggle_ui()
  end, {
    desc = "Toggle the window showing git-dev output.",
  })

  vim.api.nvim_create_user_command(
    "GitDevRecents",
    "Telescope git_dev recents",
    { desc = "Revisit previously opened repositories." }
  )
end

return M
