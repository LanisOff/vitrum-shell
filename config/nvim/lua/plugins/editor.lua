local icons = require("vitrum.icons")

return {
  { "kylechui/nvim-surround", event = "VeryLazy", opts = {} },
  { "echasnovski/mini.ai", event = "VeryLazy", opts = {} },
  { "windwp/nvim-autopairs", event = "InsertEnter", opts = {} },
  { "folke/ts-comments.nvim", event = "VeryLazy", opts = {} },
  {
    "folke/todo-comments.nvim",
    event = { "BufReadPost", "BufNewFile" },
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {},
    keys = {
      { "<leader>xt", "<cmd>Trouble todo toggle<CR>", desc = "TODOs (Trouble)" },
    },
  },
  {
    "folke/trouble.nvim",
    cmd = "Trouble",
    opts = {
      icons = {
        indent = { fold_open = icons.ui.chevron_down, fold_closed = icons.ui.chevron_right },
      },
    },
    keys = {
      { "<leader>xx", "<cmd>Trouble diagnostics toggle<CR>", desc = "Diagnostics" },
      { "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<CR>", desc = "Buffer diagnostics" },
      { "<leader>xs", "<cmd>Trouble symbols toggle<CR>", desc = "Symbols" },
      { "<leader>xr", "<cmd>Trouble lsp_references toggle<CR>", desc = "References" },
      { "<leader>xq", "<cmd>Trouble qflist toggle<CR>", desc = "Quickfix" },
    },
  },
  {
    "stevearc/aerial.nvim",
    -- master needs Neovim 0.12; 0.11 (Gentoo stable) gets the branch kept for it
    branch = vim.fn.has("nvim-0.12") == 0 and "nvim-0.11" or nil,
    -- load on file open (not just on command) so open_automatic can dock it
    event = { "BufReadPost", "BufNewFile" },
    cmd = { "AerialToggle", "AerialOpen" },
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
    opts = {
      layout = { default_direction = "prefer_right", min_width = 30 },
      show_guides = true, -- tree lines like the reference screenshot
      -- NB: no open_automatic here — the IDE layout is opened once, sequenced
      -- after neo-tree, from explorer.lua to avoid a same-tick window race.
    },
    keys = { { "<leader>cs", "<cmd>AerialToggle<CR>", desc = "Symbols outline" } },
  },
  {
    "folke/persistence.nvim",
    event = "BufReadPre",
    opts = {},
    keys = {
      { "<leader>qs", function() require("persistence").load() end, desc = "Restore session" },
      { "<leader>ql", function() require("persistence").load({ last = true }) end, desc = "Restore last session" },
    },
  },
}
