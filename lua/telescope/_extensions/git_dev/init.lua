local telescope = require "telescope"

return telescope.register_extension {
  exports = {
    recents = require "telescope._extensions.git_dev.recents",
  },
}
