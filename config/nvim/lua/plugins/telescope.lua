local icons = require("vitrum.icons")

return {
  "nvim-telescope/telescope.nvim",
  cmd = "Telescope",
  dependencies = {
    "nvim-lua/plenary.nvim",
    { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
    "nvim-telescope/telescope-ui-select.nvim",
    "nvim-tree/nvim-web-devicons",
  },
  keys = {
    { "<leader>ff", "<cmd>Telescope find_files<CR>", desc = "Find files" },
    { "<leader>fg", "<cmd>Telescope live_grep<CR>", desc = "Live grep" },
    { "<leader>fb", "<cmd>Telescope buffers<CR>", desc = "Buffers" },
    { "<leader>fh", "<cmd>Telescope help_tags<CR>", desc = "Help" },
    { "<leader>fr", "<cmd>Telescope oldfiles<CR>", desc = "Recent files" },
    { "<leader>fw", "<cmd>Telescope grep_string<CR>", desc = "Grep word under cursor" },
    { "<leader>fd", "<cmd>Telescope diagnostics<CR>", desc = "Diagnostics" },
    { "<leader>fk", "<cmd>Telescope keymaps<CR>", desc = "Keymaps" },
    { "<leader><space>", "<cmd>Telescope find_files<CR>", desc = "Find files" },
  },
  config = function()
    local telescope = require("telescope")
    telescope.setup({
      defaults = {
        path_display = { "truncate" },
        -- Spotlight's furniture: a search glyph for the prompt, a chevron for
        -- the selection, rounded borders throughout.
        prompt_prefix = " " .. icons.ui.search .. "  ",
        selection_caret = " " .. icons.ui.chevron_right .. " ",
        entry_prefix = "   ",
        borderchars = {
          prompt = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
          results = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
          preview = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
        },
        layout_strategy = "horizontal",
        layout_config = {
          horizontal = { prompt_position = "top", preview_width = 0.55 },
          width = 0.86,
          height = 0.8,
        },
        sorting_strategy = "ascending",
        winblend = 0,
        mappings = { i = { ["<C-j>"] = "move_selection_next", ["<C-k>"] = "move_selection_previous" } },
      },
      extensions = { ["ui-select"] = { require("telescope.themes").get_dropdown() } },
    })
    pcall(telescope.load_extension, "fzf")
    pcall(telescope.load_extension, "ui-select")
  end,
}
