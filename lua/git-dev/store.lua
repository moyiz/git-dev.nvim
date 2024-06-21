---A simple, unsafe and inefficient in-memory KV store with optional background
---writes to a file and update time tracking.
---
---File Schema:
--[[
{
  "version": 1,
  "data": {
    "key1": { ... },
    "key2": { ... },
    ...
  },
  "metadata": {
    "update_time": {
      "key1": "timestamp1",
      "key2": "timestamp2",
    }
  }
}
--]]
---@class StoreSchema
---@field version number
---@field data Data
---@field metadata Metadata
local StoreSchema = {}

function StoreSchema.new()
  return {
    version = 1,
    data = {},
    metadata = {
      update_time = {},
    },
  }
end

---@generic K
---@alias Key K
---@generic V
---@alias Value V

---@alias Data table<Key, Value>

---@class Metadata
---@field update_time table<Key, number>

local uv = vim.uv

local o600 = 384

---@class Store
---@field path? string DB file path or `nil` for in-memory.
---@field _db? StoreSchema
local Store = {}

---@param o Store
function Store:init(o)
  setmetatable(o, self)
  self.__index = self
  o:load()
  return o
end

---Dumps the store as a string that can be loaded.
---@return string @Representation of the store.
function Store:dump_string()
  return vim.json.encode(self._db)
end

---Loads a string representation of the store.
---@param s string
function Store:load_string(s)
  self._db = vim.json.decode(s)
  return self._db
end

---Dumps in-memory data to a path if it was passed to `init`.
function Store:dump_file()
  if not self.path then
    return
  end
  local fd = uv.fs_open(self.path, "w", o600)
  if not fd then
    vim.notify("Error opening " .. self.path)
    return
  end
  uv.fs_write(fd, self:dump_string())
  uv.fs_close(fd)
end

---Loads a file into the in-memory store if a file path was set.
function Store:load()
  if not self.path then
    if not self._db then
      self._db = StoreSchema.new()
    end
    return
  end
  local stat = uv.fs_stat(self.path)
  if not stat then
    self._db = self._db or StoreSchema.new()
    return
  end
  local fd = uv.fs_open(self.path, "r", o600)
  if not fd then
    vim.notify("Error opening " .. self.path)
    return
  end
  local data = uv.fs_read(fd, stat.size)
  uv.fs_close(fd)
  if data then
    return self:load_string(data)
  else
    self._db = self._db or StoreSchema.new()
  end
end

function Store:_update_update_time(key)
  local current = os.time() + os.clock()
  self._db.metadata.update_time[key] = current
  return current
end

---Sets a key-value in store and returns the key.
function Store:set(key, value)
  self:load()
  self._db.data[key] = value
  self:_update_update_time(key)
  self:dump_file()
  return key
end

---Adds a value to the store with a random key and returns it.
function Store:add(value)
  local r = uv.random(16)
  if not r then
    vim.notify "Failed to generate random bytes"
    return
  end
  local key = ""
  for i = 1, #r do
    key = key .. string.format("%02x", r:byte(i))
  end
  return self:set(key, value)
end

---Get a value from store.
function Store:get(key)
  self:load()
  return self._db.data[key]
end

---Removes a key-value from the store and returns its value.
function Store:remove(key)
  self:load()
  local item = self._db.data[key]
  self._db.data[key] = nil
  self._db.metadata.update_time[key] = nil
  self:dump_file()
  return item
end

---Get the number of records in store.
---@return integer
function Store:total()
  self:load()
  return vim.tbl_count(self._db and self._db.data or {})
end

---Get the keys of the `n` least recent items in store.
---Order is not guaranteed. Not very efficient.
---@param n integer Number of least recent records to return.
---@return table
function Store:least_recent(n)
  self:load()
  local keys = vim.tbl_keys(self._db.metadata.update_time)
  table.sort(keys, function(k1, k2)
    return self._db.metadata.update_time[k1] < self._db.metadata.update_time[k2]
  end)
  return vim.list_slice(keys, 1, n)
end

---Purges the store. Removes store file if exists.
function Store:purge()
  if self.path then
    uv.fs_unlink(self.path)
  end
  self._db = nil
end

---Get a list of all values in store.
---@return table
function Store:get_all()
  self:load()
  return vim.tbl_values(self._db.data)
end

return Store
