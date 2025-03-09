---Create a new scratch and unlisted buffer and return its handle.
local function _create_buffer()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, "git-dev#" .. buf)
  -- Scratch buffer
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "hide", { buf = buf })
  vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
  -- Unlisted
  vim.api.nvim_set_option_value("buflisted", false, { buf = buf })
  return buf
end

local function _lock_buffer(buf)
  vim.api.nvim_set_option_value("readonly", true, { buf = buf })
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
end

local function _unlock_buffer(buf)
  vim.api.nvim_set_option_value("readonly", false, { buf = buf })
  vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
end

---Create a window with preset options.
local function _create_window(buf, config)
  local win = vim.api.nvim_open_win(buf, false, config)
  vim.api.nvim_set_option_value("signcolumn", "no", { win = win })
  return win
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
  self.buffer = nil
  self.window = nil
  self.win_config = o.win_config
  return o
end

---Ensure that `self.buffer` is a valid buffer handle.
function UI:_ensure_buffer_valid()
  if not self.buffer or not vim.api.nvim_buf_is_valid(self.buffer) then
    self.buffer = _create_buffer()
  end
end

---Show UI window.
---Closes previous window if exists.
---@param win_config? win_config
function UI:show(win_config)
  local config = vim.tbl_deep_extend("force", self.win_config, win_config or {})
  if self.window ~= nil then
    vim.api.nvim_win_close(self.window, true)
  end
  self:_ensure_buffer_valid()
  self.window = _create_window(self.buffer, config)
  self:redraw()
  return self
end

---Redraws window and sets cursor to the last line.
function UI:redraw()
  if not self.window then
    return
  end
  self:_ensure_buffer_valid()
  local row = vim.api.nvim_buf_line_count(self.buffer)
  -- Follow text in buffer
  vim.api.nvim_win_set_cursor(self.window, { row, 1 })
  vim.cmd.redraw()
end

--A `vim.print` like function that appends to `self.buffer`.
function UI:print(...)
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

  -- Schedule the write.
  vim.schedule(function()
    self:_ensure_buffer_valid()
    local lines = vim.api.nvim_buf_line_count(self.buffer) - 1
    _unlock_buffer(self.buffer)
    vim.api.nvim_buf_set_text(
      self.buffer,
      lines,
      0,
      lines,
      0,
      vim.split(s, "\n")
    )
    _lock_buffer(self.buffer)
    self:redraw()
  end)
  return self
end

function UI:emit() end

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
---@param win_config? win_config
function UI:toggle(win_config)
  if self.window ~= nil then
    self:close()
  else
    self:show(win_config)
  end
end

return UI
