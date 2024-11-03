local function test_sanity()
  local t = dofile("./tests/lib.lua").TestSession:init {}
  local Store = require "git-dev.store"
  local st = Store:init {}

  local keys = {}
  for i = 1, 30 do
    keys[i] = st:add(i)
    -- Ensure `update_time` will differ between records for consistent tests.
    vim.uv.sleep(1)
  end

  t:assert(st:total() == 30, "Number of records.")
  t:assert(
    vim.deep_equal(st:least_recent(3), { keys[1], keys[2], keys[3] }),
    "Least recent items."
  )

  for i = 1, 10 do
    st:remove(keys[i])
  end

  t:assert(st:total() == 20, "Number of records.")
  t:assert(
    vim.deep_equal(st:least_recent(3), { keys[11], keys[12], keys[13] }),
    "Least recent items."
  )

  t:assert(st:get(keys[2]) == nil, "Non-existing key.")
  t:assert(st:get(keys[20]) == 20, "Existing key.")

  st:purge()

  t:assert(st:total() == 0, "Purging store.")

  return t.failed == 0
end

local T = {}
T.run = function()
  return test_sanity()
end
return T
