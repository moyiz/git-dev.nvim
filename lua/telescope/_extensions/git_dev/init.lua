local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local conf = require("telescope.config").values
local actions = require "telescope.actions"
local action_state = require "telescope.actions.state"
local entry_display = require "telescope.pickers.entry_display"
local utils = require "telescope.utils"
local telescope = require "telescope"
local previewers = require "telescope.previewers"

local recents = function(opts)
  local repo_url_width = 32
  local ref_width = 9

  local display_maker = entry_display.create {
    separator = " │ ",
    separator_hl = "TelescopePreviewHyphen",
    items = {
      { width = repo_url_width },
      { width = ref_width },
      { remaining = true },
    },
  }

  local function make_ordinal(entry)
    local ord = entry.args.repo
    for _, v in pairs(entry.parsed) do
      ord = ord .. ("|" .. v)
    end
    return ord
  end

  local function truncate_left(s, w, lean_right)
    local s_len = vim.fn.strdisplaywidth(s)
    if s_len <= w then
      local m = (w - s_len) / 2
      local r = lean_right and (w - s_len) % 2 or 0
      return string.rep(" ", m + r) .. s
    end
    local dots = "…"
    local dots_w = vim.fn.strdisplaywidth(dots)
    return dots .. s:sub(s_len - w + dots_w + 1)
  end

  local entry_maker = function(entry)
    return {
      value = entry,
      display = function(ent)
        return display_maker {
          {
            truncate_left(ent.value.parsed.repo_url, repo_url_width, true),
            "TelescopePreviewExecute",
          },
          {
            truncate_left(
              ent.value.args.ref.commit
                or ent.value.args.ref.tag
                or ent.value.args.ref.branch
                or ent.value.parsed.commit
                or ent.value.parsed.branch
                or "<default>",
              ref_width
            ),
            "TelescopeResultsIdentifier",
          },
          {
            ent.value.parsed.selected_path
                and utils.transform_path({
                  path_display = {
                    -- shorten = { len = 2, exclude = { 1, -1 } },
                  },
                }, ent.value.parsed.selected_path)
              or "<No selected path>",
            "TelescopeResultsFunction",
          },
        }
      end,
      ordinal = make_ordinal(entry), -- used for filtering
    }
  end

  local function make_preview(entry)
    return vim.inspect(entry.value)
  end

  pickers
    .new(opts or {}, {
      prompt_title = "Recently Opened",
      finder = finders.new_table {
        results = require("git-dev").history:get(),
        entry_maker = entry_maker,
      },
      sorter = conf.generic_sorter(opts),
      previewer = previewers.new_buffer_previewer {
        define_preview = function(self, entry)
          vim.api.nvim_set_option_value("ft", "hcl", { buf = self.state.bufnr })
          vim.api.nvim_set_option_value(
            "wrap",
            true,
            { win = self.state.winid }
          )
          vim.api.nvim_buf_set_lines(
            self.state.bufnr,
            0,
            -1,
            false,
            vim.split(make_preview(entry), "\n")
          )
        end,
      },
      attach_mappings = function(prompt_bufnr, _)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          if not selection then
            return
          end
          require("git-dev").open(selection.value.args.repo)
        end)
        return true
      end,
    })
    :find()
end

return telescope.register_extension {
  exports = {
    recents = recents,
  },
}
