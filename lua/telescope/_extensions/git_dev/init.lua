local telescope = require "telescope"

local history = function(opts)
  local config = vim.tbl_deep_extend(
    "force",
    require("git-dev").config.pickers,
    { type = "telescope" }
  )
  require("git-dev").pickers.setup(config).history(opts)
end

return telescope.register_extension {
  exports = {
    -- TODO: Remove
    recents = function(opts)
      vim.notify(
        "'recents' picker has been renamed to 'history' "
          .. "and will be removed in the future",
        vim.log.levels.WARN
      )
      history(opts)
    end,
    history = history,
  },
}
