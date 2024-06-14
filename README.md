
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
  - [:eyeglasses: Parse](#eyeglasses-parse)
    - [Parameters](#parameters)
  - [:goggles: Toggle UI](#goggles-toggle-ui)
    - [Parameters](#parameters)
- [:gear: Options](#gear-options)
- [:spider_web: URL Parsing](#spider_web-url-parsing)
  - [Supported URLs](#supported-urls)
  - [Examples](#examples)
  - [Limitations](#limitations)
- [:notebook: Recipes](#notebook-recipes)
  - [:grey_question: Interactive Opening](#grey_question-interactive-opening)
  - [:evergreen_tree: nvim-tree](#evergreen_tree-nvim-tree)
  - [:evergreen_tree: neo-tree](#evergreen_tree-neo-tree)
  - [:bookmark_tabs: New tab](#bookmark_tabs-new-tab)
  - [:fox_face: Web browser](#fox_face-web-browser)
  - [:pencil: Customizing Default URL](#pencil-customizing-default-url)
  - [:house_with_garden: Private Repositories - Parse HTTP as SSH](#house_with_garden-private-repositories---parse-http-as-ssh)
  - [:telescope: Telescope](#telescope-telescope)
- [:crystal_ball: Future Plans / Thoughts](#crystal_ball-future-plans--thoughts)
- [:scroll: License](#scroll-license)

<!-- panvimdoc-ignore-end -->

## :art: Features
- Open remote Git repositories inside Neovim at branch, tag or commit.
- Supports most URLs from GitHub, GitLab, Gitea and Codeberg.
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

Lazier (documentation will not be available until first use):
```lua
{
  "moyiz/git-dev.nvim",
  lazy = true,
  cmd = { "GitDevOpen", "GitDevCleanAll" },
  opts = {},
}
```

See [Options](#gear-options).

<!-- panvimdoc-ignore-end -->

## :blue_book: Usage
### :open_file_folder: Open
API: `require("git-dev").open(repo, ref, opts)`

Command: `GitDevOpen`

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
API: `require("git-dev").clean_all()`

Command: `GitDevCleanAll`

Clean all cached local repositories.

**Caution**: It will delete the repositories directory itself. If you changed
the default value, make sure that the new directory is being used only for this
purpose.

By either using the lua function `require("git-dev").clean_all()` or the command
`GitDevCleanAll`.

### :eyeglasses: Parse
API: `require("git-dev").parse(repo, opts)`

Parses a Git URL.

#### Parameters
- `repo` - `string` - A partial or full Git URI.
- `opts` - `table` - Override plugin configuration for this call (default:
`nil`). See [Options](#gear-options) below. 

See [URL Parsing](#spider_web-url-parsing).

### :goggles: Toggle UI
API: `require("git-dev").toggle_ui(win_config)`

Command: `GitDevToggleUI`

Manually toggle the window showing `git-dev` output. Accepts optional table to
override default window configuration.

#### Parameters
- `win_config` - `vim.api.keyset.win_config` - Override window configuration
for this call.

## :gear: Options
```lua
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
  -- UI configuration
  ui = {
    -- Auto-close window after repository was opened.
    auto_close = true,
    -- Delay window closing.
    close_after_ms = 3000,
    -- Window mode. A workaround to remove `relative`.
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
    },
    -- Window configuration for split mode.
    -- See `:h nvim_open_win`.
    ---@type win_config
    split_win_config = {
      split = "right",
      width = 79,
    },
  },
  -- Print command outputs.
  verbose = false,
}
```

## :spider_web: URL Parsing
It is reasonable to assume that browsing arbitrary Git repositories will 
probably begin in a web browser. The main purpose of this feature is to allow 
quicker transition from the currently viewed branch / tag / commit / file to 
Neovim.

This plugin supports multiple types and flavors of URLs. It will accept most
GitHub, GitLab, Gitea and Codeberg URLs, and will try to extract the actual
git repository URL, selected branch / tag / commit and selected file.

If such extraction was successful, `opener` will be provided with
`selected_path`, which is a relative path of a file in the repository. Its main
use-case is to auto-open currently viewed file.

Nested branches (contain slashes) are supported.

Notice that passing explicit `ref` to `GitDevOpen` will take precedence on
parsed fields.

### Supported URLs
- GitHub
  - `https://github.com/<repo>`
  - `https://github.com/<repo>.git`
  - `https://github.com/<repo>/tree/<branch>`
  - `https://github.com/<repo>/tree/<tag>`
  - `https://github.com/<repo>/blob/<branch>`
  - `https://github.com/<repo>/blob/<branch>/<file_path>`
  - `https://github.com/<repo>/blob/<tag>`
  - `https://github.com/<repo>/blob/<tag>/<file_path>`
- GitLab
  - `https://gitlab.com/<repo>`
  - `https://gitlab.com/<repo>.git`
  - `https://gitlab.com/<repo>/-/tree/<branch>`
  - `https://gitlab.com/<repo>/-/tree/<tag>`
  - `https://gitlab.com/<repo>/-/blob/<branch>`
  - `https://gitlab.com/<repo>/-/blob/<branch>/<file_path>`
  - `https://gitlab.com/<repo>/-/blob/<tag>`
  - `https://gitlab.com/<repo>/-/blob/<tag>/<file_path>`
- Gitea
  - `https://gitea.com/<repo>`
  - `https://gitea.com/<repo>.git`
  - `https://gitea.com/<repo>/(src|raw)/tag/<tag>`
  - `https://gitea.com/<repo>/(src|raw)/tag/<tag>/<file_path>`
  - `https://gitea.com/<repo>/(src|raw)/branch/<branch>`
  - `https://gitea.com/<repo>/(src|raw)/branch/<branch>/<file_path>`
  - `https://gitea.com/<repo>/(src|raw)/commit/<commit_id>`
  - `https://gitea.com/<repo>/(src|raw)/commit/<commit_id>/<file_path>`
- Codeberg - Same as Gitea.

### Examples
Open `README.md` in main branch:
```lua
require("git-dev").open("https://github.com/echasnovski/mini.nvim/blob/main/README.md")
```
Parser output:
```lua
{
  branch = "main",
  repo_url = "https://github.com/echasnovski/mini.nvim.git",
  selected_path = "README.md",
  type = "http"
}
```

Open `cmd/scan/main.go` in `acook/generic_docker_source_entry` branch:
```lua
require("git-dev").open("https://gitlab.com/gitlab-org/code-creation/repository-x-ray/-/blob/acook/generic_docker_source_entry/cmd/scan/main.go")
```
Parser output:
```lua
{
  branch = "acook/generic_docker_source_entry",
  repo_url = "https://gitlab.com/gitlab-org/code-creation/repository-x-ray.git",
  selected_path = "cmd/scan/main.go",
  type = "http"
}
```

See `lua/git-dev/parser_spec.lua` for more examples.

(Or: `GitDevOpen https://github.com/moyiz/git-dev/blob/master/lua/git-dev/parser_spec.lua`)

### Limitations
Notice this feature is quite experimental. If you encounter any issues or have
any questions or requests, feel free to reach out.


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
  opener = function(dir, _, selected_path)
    -- vim.cmd("Oil " .. vim.fn.fnameescape(dir))
    vim.cmd("NvimTreeOpen " .. vim.fn.fnameescape(dir))
    if selected_path then
      vim.cmd("edit " .. selected_path)
    end
  end
}
```

### :evergreen_tree: neo-tree
```lua
opts = {
  opener = function(dir, _, selected_path)
    vim.cmd("Neotree " .. dir)
    if selected_path then
      vim.cmd("edit " .. selected_path)
    end
  end
}
```

### :bookmark_tabs: New tab
Recommended. Repositories will be opened in a new tab and its CWD will be set.

```lua
opts = {
  cd_type = "tab",
  opener = function(dir, _, selected_path)
    vim.cmd "tabnew"
    vim.cmd("Neotree " .. dir)
    if selected_path then
      vim.cmd("edit " .. selected_path)
    end
  end
}
```

### :fox_face: Web browser
It does not make much sense on its own, but a showcase for getting both the
repository URL and the local directory.

```lua
opts = {
  cd_type = "none",
  opener = function(_, repo_url)
     -- vim.cmd("!librewolf " .. repo_url)
     vim.cmd("!firefox " .. repo_url)
  end
}
```

### :pencil: Customizing Default URL
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

### :house_with_garden: Private Repositories - Parse HTTP as SSH
All repositories in my home Gitea service are private. Cloning such repositories
using HTTP URLs will require inserting user and password. Since my SSH keys are
already set, a custom parser can workaround it by leveraging the `domain`
parameter of the parser function.
```lua
opts = {
  extra_domain_to_parser = {
    ["git.home.arpa"] = function(parser, text, _)
      text = text:gsub("https://([^/]+)/(.*)$", "ssh://git@%1:2222/%2")
      return parser:parse_gitea_like_url(text, "ssh://git@git.home.arpa:2222")
    end,
  },
}
```
Notice that my Gitea service listens on port 2222 for SSH. This custom parser
tricks `parse_gitea_like_url` by converting a HTTP URL to SSH like URL (which 
is not a valid git URI). I.e. 
```
https://git.home.arpa/homelab/k8s/src/commit/ef3fec4973042f0e0357a136d927fe2839350170/apps/gitea/kustomization.yaml
```
To:
```
ssh://git@git.home.arpa:2222/homelab/k8s/src/commit/ef3fec4973042f0e0357a136d927fe2839350170/apps/gitea/kustomization.yaml
```

Then, the parser trims the "domain" and proceeds as usual. Output:
```lua
{
  commit = "ef3fec4973042f0e0357a136d927fe2839350170",
  repo_url = "ssh://git@git.home.arpa:2222/homelab/k8s.git",
  selected_path = "apps/gitea/kustomization.yaml",
  type = "http"
}
```

### :telescope: Telescope
TBD

<!-- panvimdoc-ignore-start -->

## :crystal_ball: Future Plans / Thoughts
- Telescope extension to view, open and manage cloned repositories (will
require `ephemeral = false`).
- Open repository in visual selection / current "word".

## :scroll: License
See [License](./LICENSE).

<!-- panvimdoc-ignore-end -->

<!-- vim: set textwidth=80: -->
