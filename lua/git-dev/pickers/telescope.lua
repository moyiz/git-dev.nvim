local config = require("git-dev.pickers").config.history
local picker_utils = require("git-dev.pickers").utils

---@param local_opts HistoryLocalOpts
local history = function(local_opts, opts)
  local pickers = require "telescope.pickers"
  local finders = require "telescope.finders"
  local actions = require "telescope.actions"
  local action_state = require "telescope.actions.state"
  local entry_display = require "telescope.pickers.entry_display"
  local previewers = require "telescope.previewers"
  local state = require "telescope.state"

  local display_maker = entry_display.create {
    separator = local_opts.separator.text or " ",
    separator_hl = local_opts.separator.hl_group,
    items = {
      { remaining = true },
      { remaining = true },
      { remaining = true },
    },
  }

  local widths

  pickers
    .new(opts or {}, {
      prompt_title = config.title,
      finder = finders.new_table {
        results = config.get_entries(),
        entry_maker = function(entry)
          return {
            value = entry,
            display = function(_)
              if widths == nil then
                local status =
                  state.get_status(vim.F.if_nil(vim.api.nvim_get_current_buf()))
                local winid = status.layout.results.winid
                widths = picker_utils.normalize_width(
                  vim.fn.winwidth(winid), -- should deduct separator width
                  local_opts.entry.ratios,
                  {
                    local_opts.entry.repo_url.width,
                    local_opts.entry.ref.width,
                    local_opts.entry.selected_path.width,
                  }
                )
              end
              local parts = config.label_parts(entry)
              return display_maker {
                {
                  picker_utils.fit_string(
                    parts[1],
                    widths[1],
                    { align = "left", truncate = "left" }
                  ),
                  local_opts.entry.repo_url.hl_group,
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
                  picker_utils.fit_string(
                    parts[3],
                    widths[3],
                    { align = "left", truncate = "left" }
                  ),
                  local_opts.entry.selected_path.hl_group,
                },
              }
            end,
            ordinal = config.ordinal(entry), -- used for filtering
          }
        end,
      },
      previewer = previewers.new_buffer_previewer {
        define_preview = function(self, entry)
          return config.preview(self.state.bufnr, self.state.winid, entry.value)
        end,
      },
      attach_mappings = function(prompt_bufnr, _)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          if not selection then
            return
          end
          config.select_entry(selection.value)
        end)
        return true
      end,
    })
    :find()
end

return {
  history = history,
}
