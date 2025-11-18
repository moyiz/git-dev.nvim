local config = require("git-dev.pickers").config.history
local picker_utils = require("git-dev.pickers").utils

local pickers = {}

---@param local_opts HistoryLocalOpts
function pickers.history(local_opts)
  vim.ui.select(config.get_entries(), {
    prompt = config.title,
    format_item = function(item)
      local parts = config.label_parts(item)
      return vim
        .iter({
          picker_utils.fit_string(
            parts[1],
            local_opts.entry.repo_url.width,
            { align = "left", truncate = "left" }
          ),
          local_opts.separator.text or " ",
          picker_utils.fit_string(
            parts[2],
            local_opts.entry.ref.width,
            { align = "center", truncate = "right" }
          ),
          local_opts.separator.text or " ",
          picker_utils.fit_string(
            parts[3],
            local_opts.entry.selected_path.width,
            { align = "left", truncate = "left" }
          ),
        })
        :join ""
    end,
  }, function(selected)
    if selected then
      config.select_entry(selected)
    end
  end)
end

return pickers
