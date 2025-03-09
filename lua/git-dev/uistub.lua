---A UI stub, implementing the same API as UI class.
---It concatenates with each `print` invocation, and displays text once closed
---with a single call to `vim.notify`.
---@class UIStub
local UIStub = {}

function UIStub:init(o)
  setmetatable(o or {}, self)
  self.__index = self
  return o
end

function UIStub:show(_)
  return self
end

function UIStub:redraw() end
function UIStub:toggle(_) end

local st = ""

function UIStub:print(...)
  -- Transform arguments into a space delimited string and append '\n'.
  local args = { ... }
  local s = ""
  for i = 1, #args do
    if type(args[i]) == "string" then
      s = s .. " " .. args[i]
    else
      s = s .. " " .. vim.inspect(args[i])
    end
  end
  s = s .. "\n"
  vim.schedule(function()
    st = st .. s
  end)
  return self
end

function UIStub:emit(_)
  -- Schedule the write.
  vim.schedule(function()
    vim.notify(st)
    st = ""
  end)
end

function UIStub:close()
  self:emit()
end

return UIStub
