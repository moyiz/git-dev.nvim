local Session = {}

function Session:init(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  self.failed = 0
  self.total = 0
  return o
end

---@param result boolean  Whether the test passed or not.
---@param desc string
---@param i? number An optional index prefix for the test.
function Session:assert(result, desc, i)
  self.total = self.total + 1
  local status = ""
  if i then
    status = status .. i .. ": "
  end
  if result then
    status = status .. "[PASSED]"
  else
    self.failed = self.failed + 1
    status = status .. "[FAILED]"
  end
  if desc then
    status = status .. " - " .. desc
  end
  print(status)
end

return {
  Session = Session,
}
