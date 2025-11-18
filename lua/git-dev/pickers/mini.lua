local config = require("git-dev.pickers").config.history
local picker_utils = require("git-dev.pickers").utils

local pickers = {}

---Generates a history picker for mini.pick
---@param local_opts HistoryLocalOpts
function pickers.history(local_opts)
  local minipick = require "mini.pick"
  local ns = vim.api.nvim_create_namespace "GitDevPickers"
  minipick.start {
    source = {
      name = config.title,
      items = config.get_entries,
      choose = config.select_entry,
      show = function(buf_id, items)
        local widths = picker_utils.normalize_width(
          vim.fn.winwidth(0), -- should deduct separator width
          local_opts.entry.ratios,
          {
            local_opts.entry.repo_url.width,
            local_opts.entry.ref.width,
            local_opts.entry.selected_path.width,
          }
        )
        local entries_parts = vim.tbl_map(function(item)
          local parts = config.label_parts(item)

          return {
            picker_utils.fit_string(
              parts[1],
              widths[1],
              { align = "left", truncate = "left" }
            ),
            local_opts.separator.text or " ",
            picker_utils.fit_string(
              parts[2],
              widths[2],
              { align = "center", truncate = "right" }
            ),
            local_opts.separator.text or " ",
            picker_utils.fit_string(
              parts[3],
              widths[3],
              { align = "left", truncate = "left" }
            ),
          }
        end, items)
        vim.api.nvim_buf_set_lines(
          buf_id,
          0,
          -1,
          false,
          vim.tbl_map(function(parts)
            return vim.iter(parts):join ""
          end, entries_parts)
        )

        -- Highlight parts
        local hl_groups = {
          local_opts.entry.repo_url.hl_group,
          local_opts.separator.hl_group,
          local_opts.entry.ref.hl_group,
          local_opts.separator.hl_group,
          local_opts.entry.selected_path.hl_group,
        }
        vim.api.nvim_buf_clear_namespace(buf_id, ns, 0, -1)
        for i, entry in ipairs(entries_parts) do
          local col = 0
          for j, hl in ipairs(hl_groups) do
            local end_col = col + string.len(entry[j])
            if hl then
              vim.api.nvim_buf_set_extmark(buf_id, ns, i - 1, col, {
                end_row = i - 1,
                end_col = end_col,
                hl_group = hl,
                priority = 202,
              })
            end
            col = end_col
          end
        end
      end,
      preview = function(buf_id, item)
        return config.preview(
          buf_id,
          minipick.get_picker_state().windows.main,
          item
        )
      end,
    },
  }
end

return pickers
