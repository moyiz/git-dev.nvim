---@class SeparatorConfig
---@field text? string
---@field hl_group? string

---@class EntryConfig
---@field width? number
---@field hl_group? string

---@class HistoryEntryConfig
---@field ratios number[]?
---@field repo_url EntryConfig
---@field ref  EntryConfig
---@field selected_path  EntryConfig

---@class HistoryLocalOpts
---@field entry HistoryEntryConfig
---@field separator SeparatorConfig

---@class GitDevPickerOpts
---@field type nil|"mini"|"snacks"|"telescope"|"uiselect"
---@field history HistoryLocalOpts

local P = {
  config = {
    history = {
      title = "Recently Opened",
      get_entries = function()
        return require("git-dev").history:get()
      end,
      -- Action on selection
      select_entry = function(entry)
        if entry then
          require("git-dev").open(
            entry.args.repo,
            entry.args.ref,
            entry.args.opts
          )
        end
      end,
      -- An array of an entry text parts
      label_parts = function(entry)
        return {
          entry.parsed.repo_url,
          entry.parsed.commit or entry.parsed.branch or "<default>",
          entry.parsed.selected_path or "<No selected path>",
        }
      end,
      preview = function(buf_id, win_id, item)
        if win_id then
          vim.api.nvim_set_option_value("wrap", true, { win = win_id })
        end
        if buf_id then
          vim.api.nvim_set_option_value("ft", "lua", { buf = buf_id })
          vim.api.nvim_buf_set_lines(
            buf_id,
            0,
            -1,
            false,
            vim.split(vim.inspect(item), "\n")
          )
        end
      end,
      -- A string for fuzzy finding if supported by picker
      ordinal = function(entry)
        local ord = entry.args.repo
        for _, v in pairs(entry.parsed) do
          ord = ord .. ("|" .. v)
        end
        return ord
      end,
    },
  },
  utils = {},
}

---@param opts GitDevPickerOpts
function P.setup(opts)
  P.config = vim.tbl_deep_extend("force", P.config, opts)
  -- Pick the first available picker
  if not P.config.type then
    if pcall(vim.inspect, MiniPick) then
      P.config.type = "mini"
    elseif pcall(require, "snacks.picker") then
      P.config.type = "snacks"
    elseif pcall(require, "telescope") then
      P.config.type = "telescope"
    else
      P.config.type = "uiselect"
    end
  end
  -- Register pickers if supported
  if P.config.type == "telescope" then
    pcall(require("telescope").load_extension, "git_dev")
  elseif P.config.type == "mini" then
    pcall(function()
      for name, picker in pairs(require "git-dev.pickers.mini") do
        require("mini.pick").registry["git_dev_" .. name] = picker
      end
    end)
  end
  return P
end

function P.history(local_opts)
  local opts = vim.tbl_deep_extend("force", P.config.history, local_opts or {})
  local ok, p = pcall(require, "git-dev.pickers." .. P.config.type)
  if ok then
    p.history(opts)
  else
    vim.notify("Unknown picker type: " .. P.config.type, vim.log.levels.ERROR)
  end
end

---@class FitOptions
---@field align? "left"|"right"|"center"
---@field truncate? "left"|"right"|"both"
---@field ellipsis? string

---Fits a string into a given width by truncating and aligning it.
---@param s string
---@param w number?
---@param opts FitOptions?
function P.utils.fit_string(s, w, opts)
  if not w then
    return s
  end
  if not opts then
    opts = {}
  end
  opts.truncate = opts.truncate or "left"
  opts.align = opts.align or "left"
  opts.ellipsis = opts.ellipsis or "…"

  local s_len = s:len()
  local elp_len = vim.fn.strdisplaywidth(opts.ellipsis)
  if s_len > w then
    if opts.truncate == "left" then
      s = opts.ellipsis .. s:sub(-w + elp_len)
    elseif opts.truncate == "right" then
      s = s:sub(1, w - elp_len) .. opts.ellipsis
    elseif opts.truncate == "both" then
      s = opts.ellipsis
        .. s:sub(
          s_len / 2 - w / 2 + elp_len,
          s_len / 2 + w / 2 - (w % 2) - elp_len
        )
        .. opts.ellipsis
    end
  end
  local pad = w - s:len()
  if opts.align == "left" then
    s = s .. string.rep(" ", pad)
  elseif opts.align == "right" then
    s = string.rep(" ", pad) .. s
  elseif opts.align == "center" then
    s = string.rep(" ", pad / 2) .. s .. string.rep(" ", pad / 2 + (pad % 2))
  end
  return s
end

function P.utils.sum(arr)
  return vim.iter(arr):fold(0, function(acc, v)
    if v then
      return acc + v
    end
    return acc
  end)
end

---Gets a maximum width, an array of ratios and an array of fixed widths.
---Returns an array of widths within the limit.
---The sum of the fixed widths must be smaller than the maximum width.
---Remaining space will be
---@param max_width number
---@param ratios number[]? Determines the relative ratio of the remaining space.
---@param fixed number[]? Forces a width, non-nil values will ignore ratio.
---@return number[]
function P.utils.normalize_width(max_width, ratios, fixed)
  fixed = fixed and vim.deepcopy(fixed) or {}
  ratios = ratios and vim.deepcopy(ratios) or {}

  local total_fixed = P.utils.sum(fixed)
  if total_fixed > max_width then
    return {}
  end

  local remaining = max_width
  local idxs = {}
  local widths = {}

  local len = math.max(#ratios, #fixed)
  for i = 1, len do
    if fixed[i] then
      ratios[i] = nil
      widths[i] = fixed[i]
      remaining = remaining - fixed[i]
    else
      idxs[#idxs + 1] = i
      widths[i] = 0
    end
  end

  local total_ratio = P.utils.sum(ratios)
  local remainder = remaining
  for _, i in ipairs(idxs) do
    if ratios[i] then
      -- how to do integer divide (non-fractional)?
      widths[i] = math.floor((ratios[i] / total_ratio) * remaining)
      remainder = remainder - widths[i]
    end
  end

  -- Add remainder to the first non-zero width
  for i = 1, #widths do
    if widths[i] and widths[i] > 0 then
      widths[i] = widths[i] + remainder
      break
    end
  end
  return widths
end

return P
