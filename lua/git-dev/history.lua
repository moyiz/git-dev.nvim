local Store = require "git-dev.store"

---@class GitDevHistory
---@field path string History file path.
---@field n? number Maximum number of records to keep in history.
local History = {}

function History:init(o)
  o = vim.tbl_deep_extend("force", {}, o or {})
  setmetatable(o, self)
  self.__index = self
  self._store = Store:init { path = o.path }
  return o
end

---@class HistoryRecord
---@field args OpenArgs
---@field parsed GitRepo

---@class OpenArgs
---@field repo string
---@field ref table
---@field opts table

function History:add(repo, ref, opts, parsed_repo)
  ---@type HistoryRecord
  local record = {
    args = { repo = repo, ref = ref, opts = opts },
    parsed = parsed_repo,
  }
  self._store:set(repo .. "|" .. vim.json.encode(ref), record)
  self:trim()
end

function History:get()
  return self._store:get_all()
end

---Purges all history records.
function History:purge()
  self._store:purge()
end

---Trims history to a maximum number of records.
---@param n? number Override `n` from `init`.
function History:trim(n)
  n = n or self.n or math.huge
  local records_to_trim = self._store:total() - n
  if records_to_trim <= 0 then
    return
  end
  for _, key in ipairs(self._store:least_recent(records_to_trim)) do
    self._store:remove(key)
  end
end

return History
