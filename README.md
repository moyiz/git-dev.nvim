
<!-- panvimdoc-include-comment


=============================================================================

-->
```
               / /           |                         /
          ___   (___ ___  ___| ___           ___         _ _
         |   )| |        |   )|___) \  )    |   ) \  )| | | )
         |__/ | |__      |__/ |__    \/     |  /   \/ | |  /
         __/                            -
```


Open remote git repositories in the comfort of Neovim.

A plugin to open remote Git repositories inside Neovim by managing ephemeral
shallow clones automatically. It aims to provide a similar experience to
`GitHub.dev` but directly within Neovim.

<!-- panvimdoc-ignore-start -->

<!-- toc omit heading -->
## 📹 Demo
[git-dev-2024-04-14_13.39.17.webm](https://github.com/moyiz/git-dev.nvim/assets/8603313/2f16bd70-d338-434d-a8d9-8b09cd75a7f4)

<!-- toc omit heading -->
## Table of Contents
- [:art: Features](#art-features)
- [:hammer: Installation](#hammer-installation)
  - [Lazy](#lazy)
- [:blue_book: Usage](#blue_book-usage)
  - [:open_file_folder: Open](#open_file_folder-open)
    - [Parameters](#parameters)
    - [Examples](#examples)
  - [:broom: Clean All](#broom-clean-all)
- [:gear: Options](#gear-options)
- [:notebook: Recipes](#notebook-recipes)
  - [:grey_question: Interactive Opening](#grey_question-interactive-opening)
  - [:evergreen_tree: nvim-tree](#evergreen_tree-nvim-tree)
  - [:bookmark_tabs: New tab](#bookmark_tabs-new-tab)
  - [:fox_face: Web browser](#fox_face-web-browser)
  - [Customize URI](#customize-uri)
  - [:telescope: Telescope](#telescope-telescope)
- [:crystal_ball: Future Plans / Thoughts](#crystal_ball-future-plans--thoughts)
- [:scroll: License](#scroll-license)

<!-- panvimdoc-ignore-end -->

## :art: Features
- Open remote Git repositories inside Neovim at branch, tag or commit.
- Seamless integration with your workflow (e.g. LSP and tree-sitter).
- Ephemeral repositories - cleanup when Neovim exits.

<!-- panvimdoc-ignore-start -->

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
See [Options](#gear-options).

<!-- panvimdoc-ignore-end -->

## :blue_book: Usage
### :open_file_folder: Open
`API`: `require("git-dev").open(repo, ref, opts)`

`Command`: `:GitDevOpen`

Open the repository in Neovim.

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
-- :GitDevOpen moyiz/git-dev.nvim
require("git-dev").open("moyiz/git-dev.nvim")

-- :GitDevOpen derailed/k9s '{ tag = "v0.32.4" }'
require("git-dev").open("derailed/k9s", { tag = "v0.32.4" })

-- :GitDevOpen echasnovski/mini.nvim '{ branch = "stable" }' '{ ephemeral = false }'
require("git-dev").open("echasnovski/mini.nvim", { branch = "stable "}, { ephemeral = false })

-- :GitDevOpen https://git.savannah.gnu.org/git/bash.git '{}' '{ read_only = false }'
require("git-dev").open("https://git.savannah.gnu.org/git/bash.git", {}, { read_only = false })
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
```

## :notebook: Recipes
### :grey_question: Interactive Opening
The sky is the limit. I have settled for this key binding at the moment (set via
`lazy.nvim`):
```lua
{
  "moyiz/git-dev.nvim",
  ...
  keys = {
    {
      "<leader>go",
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

### :evergreen_tree: nvim-tree
To open with [nvim-tree](https://github.com/nvim-tree/nvim-tree.lua):

```lua
opts = {
  opener = function(dir)
    vim.cmd("NvimTreeOpen " .. vim.fn.fnameescape(dir))
  end
}
```

### :bookmark_tabs: New tab
Recommended. Repositories will be opened in a new tab and its CWD will be set.

```lua
opts = {
  cd_type = "tab",
  opener = function(dir)
    vim.cmd "tabnew"
    vim.cmd("NvimTreeOpen " .. vim.fn.fnameescape(dir))
  end
}
```

### :fox_face: Web browser
It does not make much sense on its own, but a showcase for getting both the
repository URI and the local directory.

```lua
opts = {
  cd_type = "none",
  opener = function(_, repo_uri)
     -- vim.cmd("!librewolf " .. repo_uri)
     vim.cmd("!firefox " .. repo_uri)
  end
}
```

### Customize URI
By default, this plugin accepts partial repository URI (e.g. `org/repo`) by
applying it onto a format string. This behavior can be customized by setting
`git.base_uri_format` to change the URI, or `git.default_org` to prepend a
default organization name if the given repository name does not contain `/`.

```lua
-- Change default URI
opts = {
  git = {
    base_uri_format = "https://git.home.arpa/%s.git",
  }
}

-- Open my own repositories by name with SSH.
-- E.g. "git-dev.nvim" rather than "moyiz/git-dev.nvim"
opts = {
  git = {
    default_org = "moyiz",
    base_uri_format = "git@github.com:%s.git",
  }
}

-- Enforce only full URIs (do not accept partial names).
opts = {
  git = {
    base_uri_format = "%s"
  }
}
```

### :telescope: Telescope
TBD

<!-- panvimdoc-ignore-start -->

## :crystal_ball: Future Plans / Thoughts
- Telescope extension to view, open and manage cloned repositories (will
require `ephemeral = false`).
- Open repository in visual selection / current "word".
- Asynchronous command invocation.
- `vimdoc`

## :scroll: License
See [License](./LICENSE).

<!-- panvimdoc-ignore-end -->

<!-- vim: set textwidth=80: -->
