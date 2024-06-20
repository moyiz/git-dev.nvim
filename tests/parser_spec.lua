local T = {}
T.run = function()
  local t = dofile("./tests/lib.lua").Session:init {}
  local Parser = require "git-dev.parser"

  local test_cases = {
    -- Github URLs
    {
      url = "https://github.com/moyiz/git-dev.nvim/tree",
      expected = {
        repo_url = "https://github.com/moyiz/git-dev.nvim.git",
        type = "http",
      },
    },
    {
      url = "https://github.com/moyiz/git-dev.nvim/tree/url-parsing",
      expected = {
        branch = "url-parsing",
        repo_url = "https://github.com/moyiz/git-dev.nvim.git",
        type = "http",
      },
    },
    {
      url = "https://github.com/moyiz/git-dev.nvim/blob",
      expected = {
        repo_url = "https://github.com/moyiz/git-dev.nvim.git",
        type = "http",
      },
    },
    {
      url = "https://github.com/moyiz/git-dev.nvim/dummy",
      expected = {
        repo_url = "https://github.com/moyiz/git-dev.nvim.git",
        type = "http",
      },
    },
    {
      url = "https://github.com/echasnovski/mini.nvim.git",
      expected = {
        repo_url = "https://github.com/echasnovski/mini.nvim.git",
        type = "http",
      },
    },
    {
      url = "https://github.com/echasnovski/mini.nvim",
      expected = {
        repo_url = "https://github.com/echasnovski/mini.nvim.git",
        type = "http",
      },
    },
    {
      url = "https://github.com/echasnovski/mini.nvim///",
      expected = {
        repo_url = "https://github.com/echasnovski/mini.nvim.git",
        type = "http",
      },
    },
    {
      url = "https://github.com/echasnovski/mini.nvim/tree/stable",
      expected = {
        repo_url = "https://github.com/echasnovski/mini.nvim.git",
        branch = "stable",
        type = "http",
      },
    },
    {
      url = "https://github.com/echasnovski/mini.nvim/tree/v0.12.0",
      expected = {
        repo_url = "https://github.com/echasnovski/mini.nvim.git",
        branch = "v0.12.0",
        type = "http",
      },
    },
    {
      url = "https://github.com/echasnovski/mini.nvim/blob/main/README.md",
      expected = {
        repo_url = "https://github.com/echasnovski/mini.nvim.git",
        full_blob = "main/README.md",
        type = "http",
      },
    },
    {
      url = "https://github.com/echasnovski/mini.nvim/blob/stable/README.md",
      expected = {
        repo_url = "https://github.com/echasnovski/mini.nvim.git",
        full_blob = "stable/README.md",
        type = "http",
      },
    },
    {
      url = "https://github.com/echasnovski/mini.nvim/blob/main/lua/mini/basics.lua",
      expected = {
        repo_url = "https://github.com/echasnovski/mini.nvim.git",
        full_blob = "main/lua/mini/basics.lua",
        type = "http",
      },
    },
    {
      url = "https://github.com/echasnovski/mini.nvim/blob/0cdf41afab4f13b7529d9965cff9c3d2d67b0bfb/lua/mini/statusline.lua",
      expected = {
        repo_url = "https://github.com/echasnovski/mini.nvim.git",
        commit = "0cdf41afab4f13b7529d9965cff9c3d2d67b0bfb",
        selected_path = "lua/mini/statusline.lua",
        type = "http",
      },
    },
    {
      -- branch name: `features/reuse-only`
      url = "https://github.com/spack/spack/tree/features/reuse-only ",
      expected = {
        repo_url = "https://github.com/spack/spack.git",
        branch = "features/reuse-only",
        type = "http",
      },
    },
    {
      url = "https://github.com/spack/spack/blob/features/reuse-only/.github/dependabot.yml",
      expected = {
        repo_url = "https://github.com/spack/spack.git",
        full_blob = "features/reuse-only/.github/dependabot.yml",
        type = "http",
      },
    },
    -- Gitlab URLs
    {
      url = "https://gitlab.com/gitlab-org/code-creation/repository-x-ray.git",
      expected = {
        repo_url = "https://gitlab.com/gitlab-org/code-creation/repository-x-ray.git",
        type = "http",
      },
    },
    {
      url = "https://gitlab.com/gitlab-org/code-creation/repository-x-ray/-/blob/main/.gitlab/CODEOWNERS?ref_type=heads",
      expected = {
        repo_url = "https://gitlab.com/gitlab-org/code-creation/repository-x-ray.git",
        branch = "main",
        selected_path = ".gitlab/CODEOWNERS",
        type = "http",
      },
      remote_refs = {
        { commit_id = "1", ref = "refs/heads/main" },
      },
    },
    {
      url = "https://gitlab.com/gitlab-org/code-creation/repository-x-ray/-/blob/1.2.0/.gitlab/CODEOWNERS",
      expected = {
        repo_url = "https://gitlab.com/gitlab-org/code-creation/repository-x-ray.git",
        branch = "1.2.0",
        selected_path = ".gitlab/CODEOWNERS",
        type = "http",
      },
      remote_refs = {
        { commit_id = "1", ref = "refs/tags/1.2.0" },
      },
    },
    {
      url = "https://gitlab.com/gitlab-org/code-creation/repository-x-ray/-/tree/1.1.0",
      expected = {
        repo_url = "https://gitlab.com/gitlab-org/code-creation/repository-x-ray.git",
        branch = "1.1.0",
        type = "http",
      },
    },
    {
      url = "https://gitlab.com/gitlab-org/code-creation/repository-x-ray/-/blob/010e6076637568b291b7563e089175130ce72369/cmd/scan/main.go",
      expected = {
        repo_url = "https://gitlab.com/gitlab-org/code-creation/repository-x-ray.git",
        commit = "010e6076637568b291b7563e089175130ce72369",
        selected_path = "cmd/scan/main.go",
        type = "http",
      },
    },
    {
      -- branch name: acook/generic_docker_source_entry
      url = "https://gitlab.com/gitlab-org/code-creation/repository-x-ray/-/blob/acook/generic_docker_source_entry/cmd/scan/main.go ",
      expected = {
        repo_url = "https://gitlab.com/gitlab-org/code-creation/repository-x-ray.git",
        branch = "acook/generic_docker_source_entry",
        selected_path = "cmd/scan/main.go",
        type = "http",
      },
      remote_refs = {
        { commit_id = "1", ref = "refs/heads/acook" },
        {
          commit_id = "2",
          ref = "refs/heads/acook/generic_docker_source_entry",
        },
        { commit_id = "3", ref = "refs/tags/main" },
      },
    },
    -- Codeberg URLs
    {
      url = "https://codeberg.org/FreeBSD/freebsd-ports",
      expected = {
        repo_url = "https://codeberg.org/FreeBSD/freebsd-ports.git",
        type = "http",
      },
    },
    {
      url = "https://codeberg.org/FreeBSD/freebsd-ports///",
      expected = {
        repo_url = "https://codeberg.org/FreeBSD/freebsd-ports.git",
        type = "http",
      },
    },
    {
      url = "https://codeberg.org/FreeBSD/freebsd-ports/src/branch/2024Q2 ",
      expected = {
        repo_url = "https://codeberg.org/FreeBSD/freebsd-ports.git",
        branch = "2024Q2",
        type = "http",
      },
    },
    {
      url = "https://codeberg.org/FreeBSD/freebsd-ports/raw/branch/2024Q2 ",
      expected = {
        repo_url = "https://codeberg.org/FreeBSD/freebsd-ports.git",
        branch = "2024Q2",
        type = "http",
      },
    },
    {
      url = "https://codeberg.org/FreeBSD/freebsd-ports/raw/branch/2024Q2/some/file ",
      expected = {
        repo_url = "https://codeberg.org/FreeBSD/freebsd-ports.git",
        branch = "2024Q2",
        selected_path = "some/file",
        type = "http",
      },
      remote_refs = {
        { commit_id = "1", ref = "refs/heads/2024Q2" },
      },
    },
    {
      -- tag: release/13.3.0
      url = "https://codeberg.org/FreeBSD/freebsd-ports/src/tag/release/13.3.0 ",
      expected = {
        repo_url = "https://codeberg.org/FreeBSD/freebsd-ports.git",
        branch = "release/13.3.0",
        type = "http",
      },
      remote_refs = {
        { commit_id = 1, ref = "refs/tags/release/13.3.0" },
      },
    },
    {
      -- branch name: renovate/vue-monorepo
      url = "https://codeberg.org/forgejo/forgejo/src/branch/renovate/vue-monorepo/cmd/admin.go ",
      expected = {
        branch = "renovate/vue-monorepo",
        repo_url = "https://codeberg.org/forgejo/forgejo.git",
        selected_path = "cmd/admin.go",
        type = "http",
      },
      remote_refs = {
        { commit_id = "1", ref = "refs/heads/renovate/vue-monorepo" },
        { commit_id = "2", ref = "refs/heads/renovate" },
      },
    },
    {
      url = "https://codeberg.org/forgejo/forgejo/src/commit/5f82ead13cb7706d3f660271d94de6101cef4119/cmd/admin.go",
      expected = {
        repo_url = "https://codeberg.org/forgejo/forgejo.git",
        commit = "5f82ead13cb7706d3f660271d94de6101cef4119",
        selected_path = "cmd/admin.go",
        type = "http",
      },
    },
    {
      url = "https://codeberg.org/forgejo/forgejo/src/",
      expected = {
        repo_url = "https://codeberg.org/forgejo/forgejo.git",
        type = "http",
      },
    },
    {
      url = "https://codeberg.org/forgejo/forgejo/src/commit",
      expected = {
        repo_url = "https://codeberg.org/forgejo/forgejo.git",
        type = "http",
      },
    },
    {
      url = "https://codeberg.org/forgejo/forgejo/src/branch",
      expected = {
        repo_url = "https://codeberg.org/forgejo/forgejo.git",
        type = "http",
      },
    },
    {
      url = "https://codeberg.org/forgejo/forgejo/src/branch/tag",
      expected = {
        branch = "tag",
        repo_url = "https://codeberg.org/forgejo/forgejo.git",
        type = "http",
      },
    },

    {
      url = "https://codeberg.org/forgejo/forgejo/src/branch/renovate/postcss-packages",
      expected = {
        repo_url = "https://codeberg.org/forgejo/forgejo.git",
        type = "http",
        branch = "renovate/postcss-packages",
      },
      remote_refs = {
        { id = "1", ref = "refs/heads/renovate/postcss-packages" },
      },
    },
    {
      url = "moyiz/na",
      expected = {
        repo_url = "https://github.com/moyiz/na.git",
        type = "base_uri",
      },
      base_uri_format = "https://github.com/%s.git",
    },
    {
      url = "test",
      expected = {
        repo_url = "this is a test",
        type = "base_uri",
      },
      base_uri_format = "this is a %s",
    },

    -- SSH
    {
      url = "git@git.localhost:/path/to/file",
      expected = {
        repo_url = "git@git.localhost:/path/to/file",
        type = "ssh",
      },
    },
    {
      url = "ssh://git@git.localhost",
      expected = {
        repo_url = "ssh://git@git.localhost",
        type = "raw",
      },
    },
    -- Non existing domain to parser mapping
    {
      url = "https://a.b.c/bla.git",
      expected = {
        repo_url = "https://a.b.c/bla.git",
        type = "raw",
      },
    },
  }

  local function test_parsers(cases)
    for i, case in ipairs(cases) do
      local parser = Parser:init {
        gitcmd = {
          list_refs_sync = function(_)
            return case.remote_refs or {}
          end,
        },
        base_uri_format = case.base_uri_format,
        default_org = case.default_org,
      }
      local output = parser:parse(case.url)
      local passed = vim.deep_equal(output, case.expected)
      t:assert(passed, case.url, i)
      if not passed then
        print "Expected:"
        vim.print(case.expected)
        print "Output:"
        vim.print(output)
      end
    end
    vim.print(
      string.format("%d/%d tests have passed!\n", #cases - t.failed, #cases)
    )
    return t.failed == 0
  end

  return test_parsers(test_cases)
end
return T
