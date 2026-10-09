-- Entry point. Order matters:
--   options sets the leader, and must run before any plugin can read it;
--   the colourscheme loads before lazy so there is no flash of default colours
--   while plugins are being resolved.
require("config.options")
require("config.keymaps")
require("config.autocmds")

require("vitrum").setup({})
vim.cmd.colorscheme("vitrum")

require("config.lazy")
