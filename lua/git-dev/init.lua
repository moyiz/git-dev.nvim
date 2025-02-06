local M = {}

local U = require "git-dev.utils"

M.config = {
  -- Whether to delete an opened repository when nvim exits.
  -- If `true`, it will create an auto command for opened repositories
  -- to delete the local directory when nvim exists.
  ephemeral = true,
  -- Set buffers of opened repositories to be read-only and unmodifiable.
  read_only = true,
  -- Whether / how to CD into opened repository.
  ---@type "global"|"tab"|"window"|"none"
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
    -- Triggered when repository already exists locally to refresh the local
    -- copy.
    fetch_args = "--jobs=2 --no-all --update-shallow -f --prune --no-tags",
    -- Arguments for `git checkout`.
    -- Triggered by `open` when a branch, tag or commit is given.
    checkout_args = "-f --recurse-submodules",
  },
  -- UI configuration.
  ui = {
    -- Auto-close window after repository was opened.
    auto_close = true,
    -- Delay window closing.
    close_after_ms = 3000,
    -- Window mode.
    ---@type "floating"|"split"
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
  -- Repository cleaning configuration.
  clean = {
    -- Close all related buffers.
    close_buffers = true,
    -- Whether to delete repository directory, keep it, or determine deletion
    -- by its current ephemeral setting.
    ---@type "always"|"never"|"current"
    delete_repo_dir = "current",
  },
  -- XDG handling of `nvim-getdev` URIs.
  -- Requires: `xdg-mime` and `xdg-open`.
  xdg_handler = {
    enabled = false,
    -- A location for the desktop entry.
    desktop_entry_path = vim.fs.normalize(
      vim.fn.stdpath "data" .. "/../applications/git-dev.desktop"
    ),
    -- Launcher script.
    script = {
      path = vim.fn.expand "~/.local/bin/git-dev-open",
      content = '#!/usr/bin/env sh\nnvim -c GitDevXDGHandle\\ "$@"',
    },
  },
  -- More verbosity.
  verbose = false,
}

M.session = nil
M.history = nil

local cd_func = {
  global = U.cmd_to_func "cd",
  tab = U.cmd_to_func "tcd",
  window = U.cmd_to_func "lcd",
  none = function(_, _) end,
}

local function delete_repo_dir(repo_dir)
  local is_deleted = vim.fn.delete(repo_dir, "rf")
  local msg
  if is_deleted == 0 then
    msg = "Deleted: " .. repo_dir
  else
    msg = "Not found: " .. repo_dir
  end
  M.ui:print(msg)
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
    .. U.git_uri_to_dir_name(parsed_repo.repo_url, branch)

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

    ---@type GitDevSessionRepo
    local repo_ctx = {
      repo = parsed_repo.repo_url,
      ref = ref,
      repo_dir = repo_dir,
    }

    if config.ephemeral then
      ui:print "Ephemeral mode: creating autocmd to cleanup when nvim exits..."
      -- Delete repository directory when vim exits.
      repo_ctx.ephemeral_autocmd_id = vim.api.nvim_create_autocmd(
        { "VimLeavePre" },
        {
          group = augroup,
          callback = function()
            delete_repo_dir(repo_dir)
          end,
        }
      )
    end

    if config.read_only then
      -- Set all buffers in the repository directory as read-only
      -- and unmodifiable.
      ui:print("Setting read only mode for " .. repo_dir)
      repo_ctx.read_only_autocmd_id = vim.api.nvim_create_autocmd(
        { "BufReadPost" },
        {
          group = augroup,
          pattern = repo_dir .. "*",
          callback = function()
            vim.cmd "setlocal readonly nomodifiable"
          end,
        }
      )
    end

    local ctx_id = M.session:set_repo(repo_ctx)
    repo_ctx.set_session_autocmd_id = vim.api.nvim_create_autocmd(
      { "BufReadPost" },
      {
        group = augroup,
        pattern = repo_dir .. "*",
        callback = function(t)
          vim.api.nvim_buf_set_var(t.buf, "git_dev_session_id", ctx_id)
        end,
      }
    )

    -- CD into repository directory
    cd_func[config.cd_type](
      { vim.fn.fnameescape(repo_dir) },
      not config.verbose
    )

    -- Open directory (or selected path)
    config.opener(repo_dir, parsed_repo.repo_url, parsed_repo.selected_path)

    -- Add this call to history store.
    M.history:add(repo, ref, opts, parsed_repo)

    ui:print "Done."
    if config.ui.auto_close then
      ui:close(config.ui.close_after_ms)
    end
  end)

  if vim.fn.isdirectory(repo_dir) == 1 then
    ui:print "Repository directory exists, refreshing..."
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

---Cleans all repositories in the repositories directory
---DANGER: Make sure that the repositories directory is exclusive to
---this plugin.
M.clean_all = function()
  vim.fn.delete(M.config.repositories_dir)
end

---@return GitDevSessionRepo?
local function get_session_repo(repo, ref)
  ref = ref or {}
  if repo then
    local ids = M.session:find {
      { name = "repo", value = repo, type = "contains" },
      { name = "ref", value = ref, type = "equal" },
    }
    if #ids == 0 then
      vim.notify "Could not find related repository session."
      return
    elseif #ids > 1 then
      vim.notify "More than one related repository sessions."
      return
    else
      return M.session:get_repo(ids[1])
    end
  end
  -- Fallback to current buffer
  local ctx_id = U.buf_get_var(nil, "git_dev_session_id")
  if ctx_id then
    return M.session:get_repo(ctx_id)
  end
end

---Closes (deletes) all buffers associated with the given repository and ref.
---If none was given, it will try to determine the repository directory from
---current buffer.
---@param repo? string
---@param ref? GitRef
---@return string[]? @An array of closed paths.
M.close_buffers = function(repo, ref)
  local repo_ctx = get_session_repo(repo, ref)
  if not repo_ctx then
    vim.notify "Could not determine repository session."
    return nil
  end
  local ctx_id = M.session:key(repo_ctx)
  local deleted = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local other = U.buf_get_var(buf, "git_dev_session_id")
    if ctx_id == other then
      table.insert(deleted, vim.api.nvim_buf_get_name(buf))
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end
  return deleted
end

---Cleans a repository. It will close all associated buffers and delete the
---repository directory if it was ephemeral.
---If no repository is given, assume it is related to current buffer.
---If no ref is given, assume it is related to current buffer if an explicit
---repository was given.
---@param repo? string
---@param ref? GitRef
---@param opts? table Override plugin settings.
M.clean = function(repo, ref, opts)
  local config = vim.tbl_deep_extend("force", M.config, opts or {})

  local repo_ctx = get_session_repo(repo, ref)
  if not repo_ctx then
    vim.notify "Could not determine repository session."
    return
  end

  if config.clean.close_buffers then
    if not M.close_buffers(repo_ctx.repo, repo_ctx.ref) then
      return
    end
  end

  if vim.uv.cwd() == repo_ctx.repo_dir then
    vim.fn.chdir(vim.env.PWD)
  end

  -- If repository is marked as ephemeral, remove its directory.
  if
    config.clean.delete_repo_dir == "always"
    or config.clean.delete_repo_dir == "current"
      and repo_ctx.ephemeral_autocmd_id
  then
    delete_repo_dir(repo_ctx.repo_dir)
  end

  -- Delete autocmds
  if repo_ctx.ephemeral_autocmd_id then
    vim.api.nvim_del_autocmd(repo_ctx.ephemeral_autocmd_id)
  end
  if repo_ctx.read_only_autocmd_id then
    vim.api.nvim_del_autocmd(repo_ctx.read_only_autocmd_id)
  end
  vim.api.nvim_del_autocmd(repo_ctx.set_session_autocmd_id)

  -- Remove from session
  M.session:remove(M.session:key(repo_ctx))
end

---Parses a Git URL.
---@param repo string
---@return GitDevParsedRepo
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

local function complete_from_session(_, line, pos)
  local argv = vim.split(line:sub(1, pos), " +")
  if #argv < 2 then
    return {}
  end
  local repo_ids =
    M.session:find { { name = "repo", value = argv[2], type = "contains" } }
  if #argv == 2 then
    return U.uniq(U.map(function(k)
      return M.session:get_repo(k).repo
    end, repo_ids))
  elseif #argv == 3 then
    local refs = U.map(function(k)
      local ref = M.session:get_repo(k).ref
      if ref and vim.tbl_count(ref) > 0 then
        return vim.inspect(ref):gsub("%s", "")
      end
      return "{}"
    end, repo_ids)
    table.insert(refs, "{}")
    return U.uniq(refs)
  end
  return {}
end

---Plugin Setup
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

  -- Initialize session
  ---@type GitDevSession
  M.session = require("git-dev.session"):init()

  local xdg = require "git-dev.xdg"
  if M.config.xdg_handler.enabled then
    xdg.enable(M.config.xdg_handler)
    vim.api.nvim_create_user_command("GitDevXDGHandle", function(cmd_args)
      local uri = U.parse_cmd_args(cmd_args)
      M.ui:print(xdg.handle(uri))
    end, {
      desc = "xdg-open handler for git-dev.nvim URIs.",
      nargs = "*",
    })
  else
    xdg.disable(M.config.xdg_handler)
  end

  -- Create commands
  vim.api.nvim_create_user_command("GitDevOpen", function(cmd_args)
    local repo, ref, cmd_opts = U.parse_cmd_args(cmd_args)
    require("git-dev").open(repo, ref, cmd_opts)
  end, {
    desc = "Open a git repository.",
    nargs = "*",
  })

  vim.api.nvim_create_user_command("GitDevCleanAll", function(_)
    require("git-dev").clean_all()
  end, {
    desc = "Delete the repositories directory. CAUTION: be careful "
      .. "with custom paths.",
  })

  vim.api.nvim_create_user_command("GitDevCloseBuffers", function(cmd_args)
    local repo, ref = U.parse_cmd_args(cmd_args)
    require("git-dev").close_buffers(repo, ref)
  end, {
    desc = "Close (delete) all buffers associated with the same "
      .. "repository as the current buffer.",
    nargs = "*",
    complete = complete_from_session,
  })

  vim.api.nvim_create_user_command("GitDevClean", function(cmd_args)
    local repo, ref, cmd_opts = U.parse_cmd_args(cmd_args)
    require("git-dev").clean(repo, ref, cmd_opts)
  end, {
    desc = "Close related buffers, delete repository directory "
      .. "and remove repository from history store.",
    nargs = "*",
    complete = complete_from_session,
  })

  vim.api.nvim_create_user_command("GitDevToggleUI", function(_)
    require("git-dev").toggle_ui()
  end, {
    desc = "Toggle output window.",
  })

  vim.api.nvim_create_user_command(
    "GitDevRecents",
    "Telescope git_dev recents",
    { desc = "Revisit previously opened repositories." }
  )
end

return M
