local config = require("git-dev.pickers").config.history
local picker_utils = require("git-dev.pickers").utils

local pickers = {}

---@param local_opts HistoryLocalOpts
function pickers.history(local_opts)
  local snacks = require "snacks"

  local widths

  return snacks.picker.pick {
    source = "git-dev",
    title = config.title,
    items = config.get_entries(),
    confirm = function(_, item)
      config.select_entry(item)
    end,
    format = function(item, p)
      if not widths then
        widths = picker_utils.normalize_width(
          vim.fn.winwidth(p.list.win.win), -- should deduct separator width
          local_opts.entry.ratios,
          {
            local_opts.entry.repo_url.width,
            local_opts.entry.ref.width,
            local_opts.entry.selected_path.width,
          }
        )
      end
      local parts = config.label_parts(item)
      return {
        {
          picker_utils.fit_string(
            parts[1],
            widths[1],
            { align = "left", truncate = "left" }
          ),
          local_opts.entry.repo_url.hl_group,
        },
        {
          local_opts.separator.text or " ",
          local_opts.separator.hl_group,
        },
        {
          picker_utils.fit_string(
            parts[2],
            widths[2],
            { align = "center", truncate = "right" }
          ),
          local_opts.entry.ref.hl_group,
        },
        {
          local_opts.separator.text or " ",
          local_opts.separator.hl_group,
        },
        {
          picker_utils.fit_string(
            parts[3],
            widths[3],
            { align = "left", truncate = "left" }
          ),
          local_opts.entry.selected_path.hl_group,
        },
      }
    end,
    transform = function(item)
      item.text = config.ordinal(item)
      item.preview = {
        ft = "lua",
        text = vim.inspect {
          args = item.args,
          parsed = item.parsed,
        },
      }
      return item
    end,
    preview = "preview",
  }
end

return pickers
