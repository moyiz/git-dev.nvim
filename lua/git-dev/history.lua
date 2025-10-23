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

---@class GitDevHistoryRecord
---@field args GitDevOpenArgs
---@field parsed GitDevParsedRepo

---@class GitDevOpenArgs
---@field repo string
---@field ref table
---@field opts table

---@return Key
function History:add(repo, ref, opts, parsed_repo)
  ---@type GitDevHistoryRecord
  local record = {
    args = { repo = repo, ref = ref, opts = opts },
    parsed = parsed_repo,
  }
  local key = self:key(record)
  self._store:set(key, record)
  self:trim()
  return key
end

function History:get()
  return self._store:get_all()
end

---@param record GitDevHistoryRecord
function History:key(record)
  return record.args.repo .. "|" .. vim.json.encode(record.args.ref)
end

function History:update_opts(key, opts)
  local record = self._store:get(key)
  if not record then
    return
  end
  record.args.opts =
    vim.tbl_deep_extend("force", record.args.opts or {}, opts or {})
  self._store:set(key, record)
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
