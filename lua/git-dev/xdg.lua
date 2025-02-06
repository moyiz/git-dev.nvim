---@class XDGDesktopEntry
---@field name string
---@field exec string
---@field mime_type string

local XDG = {}

local uv = vim.uv
local utils = require "git-dev.utils"

---@param uri string?
XDG.handle = function(uri)
  if not uri then
    return
  end
  -- Trim
  uri = uri:gsub("^%s+", ""):gsub("%s+$", "")
  local method = uri:match "://([^/]+)"
  local params = vim.split(uri, "?")[2]
  local parsed = {}
  for _, param in ipairs(vim.split(params, "&")) do
    local k, v = unpack(vim.split(param, "="))
    parsed[k] = utils.load_param(vim.uri_decode(v))
  end
  return require("git-dev")[method](unpack(vim.tbl_values(parsed)))
end

---@param entry XDGDesktopEntry
local function generate_entry(entry)
  return ([[
    [Desktop Entry]
    Name=%s
    Type=Application
    Exec=%s
    Terminal=true
    MimeType=%s
    NoDisplay=true
  ]]):gsub("  +", ""):format(entry.name, entry.exec, entry.mime_type)
end

XDG.enable = function(opts)
  utils.overwrite_if_changed(opts.script.path, opts.script.content, utils.o700)
  local desktop_entry = {
    name = "GitDev",
    exec = vim.fn.expand(opts.script.path) .. " %u",
    mime_type = "x-scheme-handler/nvim-gitdev",
  }

  utils.overwrite_if_changed(
    opts.desktop_entry_path,
    generate_entry(desktop_entry)
  )

  -- Update scheme handler if incorrect
  local sh_spawn = require("git-dev.utils").sh_spawn
  local s = sh_spawn(
    "xdg-mime query default " .. desktop_entry.mime_type,
    function(code)
      if code ~= 0 then
        vim.api.nvim_err_writeln "Failed to get default handler"
      end
    end
  )
  uv.read_start(s.stdout, function(err, data)
    if not err and data then
      local entry_name = vim.fs.basename(opts.desktop_entry_path)
      if entry_name ~= vim.trim(data) then
        sh_spawn(
          "xdg-mime default " .. entry_name .. " " .. desktop_entry.mime_type,
          function(code)
            if code ~= 0 then
              vim.api.nvim_err_writeln "Failed to set default handler"
            end
          end
        )
      end
    end
  end)
end

XDG.disable = function(opts)
  if uv.fs_stat(opts.script.path) then
    uv.fs_unlink(opts.script.path)
  end
  if uv.fs_stat(opts.desktop_entry_path) then
    uv.fs_unlink(opts.desktop_entry_path)
  end
end

return XDG
