local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local out = vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath,
  })
  if vim.v.shell_error ~= 0 then
    error("Failed to clone lazy.nvim:\n" .. out)
  end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = {
    { import = "plugins" },
    { import = "plugins.lang" },
    -- Yours, and never overwritten by the installer.
    { import = "plugins.local" },
  },
  defaults = { lazy = true },
  -- vitrum lives in this config, not in a plugin, so it is always available;
  -- habamax is the fallback lazy uses if something has gone badly wrong.
  install = { colorscheme = { "vitrum", "habamax" } },
  checker = { enabled = true, notify = false },
  change_detection = { notify = false },
  ui = {
    border = "rounded",
    backdrop = 100,   -- no dimming: the terminal behind is already glass
    icons = { lazy = require("vitrum.icons").ui.bolt .. " " },
  },
  performance = {
    rtp = {
      disabled_plugins = {
        "gzip", "tarPlugin", "tohtml", "tutor", "zipPlugin", "netrwPlugin",
      },
    },
  },
})
