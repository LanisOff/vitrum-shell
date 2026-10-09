return {
  "saghen/blink.cmp",
  version = "*", -- release tag ships a prebuilt fuzzy binary (no Rust build needed)
  event = "InsertEnter",
  dependencies = {
    "rafamadriz/friendly-snippets",
    { "L3MON4D3/LuaSnip", version = "v2.*", build = "make install_jsregexp" },
  },
  opts = {
    snippets = { preset = "luasnip" },
    appearance = { nerd_font_variant = "mono" },
    keymap = {
      preset = "default",
      ["<CR>"] = { "accept", "fallback" },
      ["<Tab>"] = { "select_next", "snippet_forward", "fallback" },
      ["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },
    },
    completion = {
      documentation = {
        auto_show = true,
        auto_show_delay_ms = 200,
        window = { border = "rounded" },
      },
      menu = {
        border = "rounded",
        draw = { treesitter = { "lsp" } },
      },
      ghost_text = { enabled = false }, -- leave inline ghost-text to Supermaven
    },
    signature = { enabled = true, window = { border = "rounded" } },
    sources = {
      default = { "lsp", "path", "snippets", "buffer", "lazydev" },
      providers = {
        lazydev = { name = "LazyDev", module = "lazydev.integrations.blink", score_offset = 100 },
      },
    },
    fuzzy = { implementation = "prefer_rust_with_warning" },
  },
  config = function(_, opts)
    require("blink.cmp").setup(opts)
    -- autopairs integration
    local ok, ap = pcall(require, "nvim-autopairs.completion.cmp")
    if ok then pcall(ap.setup) end
  end,
}
