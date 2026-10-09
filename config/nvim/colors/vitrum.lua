-- Makes `:colorscheme vitrum` work, including from `install = { colorscheme }`
-- before any plugin has had a chance to call setup().
require("vitrum").load()
