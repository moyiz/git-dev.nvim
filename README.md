# git-dev.nvim

Explore remote git repositories inside neovim (experimental).

A plugin to open remote Git repositories inside Neovim by managing ephemeral
shallow clones automatically. It aims to provide a similar experience to
`GitHub.dev` but directly within Neovim.

- [git-dev.nvim](#git-devnvim)
  - [:scroll: Features](#scroll-features)
  - [:hammer: Installation](#hammer-installation)
    - [Lazy](#lazy)
  - [:blue_book: Usage / API](#blue_book-usage--api)
    - [:open_file_folder: Open](#open_file_folder-open)
      - [Parameters](#parameters)
    - [:broom: Clean All](#broom-clean-all)
  - [:gear: Options](#gear-options)
  - [:notebook: Recipes](#notebook-recipes)
    - [Interactive Opening](#interactive-opening)
    - [nvim-tree Opener](#nvim-tree-opener)
    - [Open repository in a new tab](#open-repository-in-a-new-tab)
    - [Customized short URI](#customized-short-uri)
    - [:telescope: Telescope](#telescope-telescope)
  - [:crystal_ball: Future Plans / Thoughts](#crystal_ball-future-plans--thoughts)
  - [License](#license)

## :scroll: Features
- Open remote Git repositories inside Neovim at branch, tag or commit.
- Seamless integration with your workflow (e.g. LSP and tree-sitter).
- Cleanup when Neovim exists.

## :hammer: Installation
Use your favorite plugin manager:
### Lazy

```lua
{
  "moyiz/git-dev.nvim",
  event = "VeryLazy",
  opts = {},
}
```


## :blue_book: Usage / API
### :open_file_folder: Open
Open the repository.
By either using the lua function `require("git-dev).open(repo, ref, opts)` or
the command `:GitDevOpen`).

#### Parameters
- `repo` - `string` - A partial or full Git URI.
- `ref` - `table` - Target reference to checkout (default: `nil`). Empty `ref`
will checkout the default branch.
Examples: `{ branch = "..." }|{ tag = "..." }|{ commit = "..." }`.
If more than one is specified, the priority is: `commit` > `tag` > `branch`.
- `opts` - `table` - Override plugin configuration for this call (default:
`nil`). See [Options](#gear-options) below. 

#### Examples
```lua

```

### :broom: Clean All
Clean all cached local repositories.
**Caution**: It will delete the repositories directory itself. If you changed
the default value, make sure that the new directory is being used only for this
purpose.
By either using the lua function `require("git-dev").clean_all()` or the command
`:GitDevCleanAll`.


## :gear: Options
```lua
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
```


## :notebook: Recipes
### Interactive Opening
The sky is the limit. I have settled for this key binding at the moment (set via
`lazy.nvim`):
```lua
{
  "moyiz/git-dev.nvim",
  ...
  keys = {
    {
      "<leader>o",
      function()
        local repo = vim.fn.input "Repository name / URI: "
        if repo ~= "" then
          require("git-dev").open(repo)
        end
      end,
      desc = "[O]pen a remote git repository",
    }
  }
  ...
}
```

### nvim-tree Opener
```lua
opener = function(dir)
    vim.cmd("NvimTreeOpen " .. vim.fn.fnameescape(dir))
end
```

### Open repository in a new tab
```lua
cd_type = "tab",
opener = function(dir)
  vim.cmd "tabnew"
  vim.cmd("NvimTreeOpen " .. vim.fn.fnameescape(dir))
end,
```

### Customized short URI
By default, this plugin accepts short repository URI (e.g. `org/repo`) by
converting it to `https://github.com/org/repo.git`. This behavior can be
customized by setting `git.base_uri_format`.

```lua
-- Shorten another base URI.
git = {
  base_uri_format = "https://git.home.arpa/%s.git",
}

-- Open my own repositories by name with SSH.
-- E.g. "git-dev.nvim" rather than "moyiz/git-dev.nvim"
git = {
  base_uri_format = "git@github.com:moyiz/%s.git",
}

-- Enforce only full URIs (do not accept partial names).
git = {
  base_uri_format = "%s"
}
```

### :telescope: Telescope
TBD

## :crystal_ball: Future Plans / Thoughts
- Telescope extension to view, open and manage cloned repositories (will
require `ephemeral = false`).
- Open repository in visual selection / current "word".
- `vimdoc`

## License
See [License](./LICENSE).

<!-- vim: set textwidth=80: -->
