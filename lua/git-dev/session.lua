---@class GitDevSessionRepo
---@field repo string
---@field ref? GitRef
---@field repo_dir string
---@field ephemeral_autocmd_id? number
---@field read_only_autocmd_id? number
---@field set_session_autocmd_id? number

---@alias GitDevSessionRepos table<number, GitDevSessionRepo>

---@class GitDevSession
---@field repos GitDevSessionRepo
local Session = {}

---@param o? GitDevSession
function Session:init(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  self.repos = {}
  return o
end

---@param repo_session GitDevSessionRepo
---@return string @key
function Session:set_repo(repo_session)
  local key = self:key(repo_session)
  self.repos[key] = repo_session
  return key
end

function Session:get_repo(key)
  return self.repos[key]
end

function Session:key(repo_session)
  return repo_session.repo_dir
end

function Session:remove(key)
  self.repos[key] = nil
end

---@alias FilterType "equal"|"contains"

---@class _Filter
---@field name string
---@field value any
---@field type FilterType

---@param filters _Filter[] A list of filters to apply on each repository.
function Session:find(filters)
  local results = {}
  for ctx_id, repo_ctx in pairs(self.repos) do
    local match = true
    for _, filter in ipairs(filters) do
      if
        filter.type == "equal"
          and not vim.deep_equal(repo_ctx[filter.name], filter.value)
        or filter.type == "contains"
          and not repo_ctx[filter.name]:find(filter.value)
      then
        match = false
        break
      end
    end
    if match and ctx_id then
      table.insert(results, ctx_id)
    end
  end
  return results
end

return Session
