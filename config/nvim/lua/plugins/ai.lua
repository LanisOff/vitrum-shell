return {
  {
    "supermaven-inc/supermaven-nvim",
    event = "InsertEnter",
    opts = {
      keymaps = {
        accept_suggestion = "<Tab>",
        clear_suggestion = "<C-]>",
        accept_word = "<C-j>",
      },
      -- keep it out of noisy buffers
      ignore_filetypes = { help = true, ["neo-tree"] = true, TelescopePrompt = true },
      color = { suggestion_color = nil, cterm = nil }, -- use the SupermavenSuggestion group from the theme
    },
  },
  {
    "coder/claudecode.nvim",
    dependencies = { "folke/snacks.nvim" },
    cmd = { "ClaudeCode", "ClaudeCodeSend", "ClaudeCodeFocus", "ClaudeCodeDiffAccept", "ClaudeCodeDiffDeny" },
    keys = {
      { "<leader>ac", "<cmd>ClaudeCode<CR>", desc = "Toggle Claude", mode = { "n", "v" } },
      { "<leader>af", "<cmd>ClaudeCodeFocus<CR>", desc = "Focus Claude" },
      { "<leader>as", "<cmd>ClaudeCodeSend<CR>", mode = "v", desc = "Send selection to Claude" },
      { "<leader>aa", "<cmd>ClaudeCodeDiffAccept<CR>", desc = "Accept Claude diff" },
      { "<leader>ad", "<cmd>ClaudeCodeDiffDeny<CR>", desc = "Deny Claude diff" },
    },
    opts = {}, -- launches the `claude` CLI already on your PATH
  },
}
