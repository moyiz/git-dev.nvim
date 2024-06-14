local function _create_buffer()
  local _set_option = function(name, value)
    vim.api.nvim_set_option_value(name, value, { scope = "local" })
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, "git-dev#" .. buf)
  _set_option("buftype", "nofile")
  _set_option("swapfile", false)
  _set_option("bufhidden", "wipe")
  _set_option("readonly", true)
  _set_option("modifiable", false)
  _set_option("signcolumn", "no")
  return buf
end

---@alias win_config vim.api.keyset.win_config
---
---@class UI
---@field buffer? integer A buffer to write to.
---@field window? integer A window to show the output buffer.
---@field win_config win_config
local UI = {}

function UI:init(o)
  setmetatable(o or {}, self)
  self.__index = self
  self.buffer = self.buffer or _create_buffer()
  self.window = nil
  self.win_config = o.win_config
  return self
end

---Show window.
---Closes previous window if exists.
---@param win_config? win_config
function UI:show(win_config)
  local config = vim.tbl_deep_extend("force", self.win_config, win_config or {})
  if self.window ~= nil then
    vim.api.nvim_win_close(self.window, true)
  end
  self.window = vim.api.nvim_open_win(self.buffer, false, config)
  self:redraw()
  return self
end

---Redraws window and sets cursor to the last line.
function UI:redraw()
  local row = vim.api.nvim_buf_line_count(self.buffer)
  -- Follow text in buffer
  vim.api.nvim_win_set_cursor(self.window, { row, 1 })
  vim.cmd.redraw()
end

---Prints given arguments into the current buffer.
function UI:print(...)
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
    local lines = vim.api.nvim_buf_line_count(self.buffer) - 1
    vim.api.nvim_buf_set_text(
      self.buffer,
      lines,
      0,
      lines,
      0,
      vim.split(s, "\n")
    )
    self:redraw()
  end)
  return self
end

---Closes window after given delay.
---@param delay? integer Time to wait before closing the window in ms.
function UI:close(delay)
  delay = delay or 0
  local timer = vim.uv.new_timer()
  timer:start(
    delay,
    0,
    vim.schedule_wrap(function()
      if vim.api.nvim_win_is_valid(self.window) then
        vim.api.nvim_win_close(self.window, true)
      end
      self.window = nil
      timer:stop()
      timer:close()
    end)
  )
end

---Toggles UI window.
function UI:toggle()
  if self.window ~= nil then
    self:close()
  else
    self:show()
  end
end

return UI
