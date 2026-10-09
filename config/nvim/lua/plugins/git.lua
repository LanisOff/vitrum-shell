local icons = require("vitrum.icons")

return {
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      signs = {
        add          = { text = icons.git.bar },
        change       = { text = icons.git.bar },
        -- Deletions have no line of their own to mark, so they get a rule
        -- rather than a bar. Plain box-drawing, not Nerd Font: these must
        -- render even in a TTY.
        delete       = { text = "▁" },
        topdelete    = { text = "▔" },
        changedelete = { text = icons.git.bar },
        untracked    = { text = icons.git.bar },
      },
      current_line_blame_opts = { delay = 400, virt_text_pos = "eol" },
      preview_config = { border = "rounded" },
      on_attach = function(bufnr)
        local gs = require("gitsigns")
        local function map(mode, l, r, desc)
          vim.keymap.set(mode, l, r, { buffer = bufnr, desc = desc })
        end
        map("n", "]h", gs.next_hunk, "Next hunk")
        map("n", "[h", gs.prev_hunk, "Prev hunk")
        map("n", "<leader>gs", gs.stage_hunk, "Stage hunk")
        map("n", "<leader>gr", gs.reset_hunk, "Reset hunk")
        map("n", "<leader>gp", gs.preview_hunk, "Preview hunk")
        map("n", "<leader>gb", function() gs.blame_line({ full = true }) end, "Blame line")
        map("n", "<leader>gB", gs.toggle_current_line_blame, "Toggle line blame")
      end,
    },
  },
  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewFileHistory" },
    keys = {
      { "<leader>gd", "<cmd>DiffviewOpen<CR>", desc = "Diffview open" },
      { "<leader>gh", "<cmd>DiffviewFileHistory %<CR>", desc = "File history" },
      { "<leader>gc", "<cmd>DiffviewClose<CR>", desc = "Diffview close" },
    },
  },
}
