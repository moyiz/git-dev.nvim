local function gen_repos()
  local repos = {
    {
      foo = "bar",
      foo2 = "bar2",
    },
    {
      foo = "baz",
      foo2 = "bar2",
    },
    {
      foo = "bas",
      foo2 = "bar2",
    },
    {
      foo = "gas",
      foo2 = "gas2",
    },
  }
  for i, repo in ipairs(repos) do
    repo.repo_dir = i
  end
  return repos
end

local filters_to_nr = {
  { { { name = "foo", value = "baz", type = "equal" } }, 1 },
  { { { name = "foo", value = "baz", type = "contains" } }, 1 },

  { { { name = "foo", value = "as", type = "equal" } }, 0 },
  { { { name = "foo", value = "as", type = "contains" } }, 2 },

  {
    {
      { name = "foo", value = "as", type = "contains" },
      { name = "foo2", value = "bar2", type = "equal" },
    },
    1,
  },
}

local function test_sanity()
  local t = dofile("./tests/lib.lua").TestSession:init {}
  local Session = require "git-dev.session"
  local s = Session:init {}

  local repos = gen_repos()
  for _, repo in pairs(repos) do
    s:set_repo(repo)
  end

  t:assert(#s.repos == #repos, "Number of records")

  for i, f_to_nr in ipairs(filters_to_nr) do
    local filter, nr = unpack(f_to_nr)
    local result = #s:find(filter)
    local passed = result == nr
    t:assert(passed, vim.inspect(filter):gsub("%s", ""), i)
    if not passed then
      vim.print("Expected " .. nr .. " but got " .. result)
    end
  end

  return t.failed == 0
end

local T = {}
T.run = function()
  return test_sanity()
end
return T
