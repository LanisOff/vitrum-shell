return {
  {
    "mrcjkb/rustaceanvim",
    version = "^6",
    lazy = false, -- plugin configures itself on the rust filetype
    ft = { "rust" },
    config = function()
      local caps = vim.lsp.protocol.make_client_capabilities()
      local ok, blink = pcall(require, "blink.cmp")
      if ok then caps = blink.get_lsp_capabilities(caps) end
      vim.g.rustaceanvim = {
        server = {
          capabilities = caps,
          default_settings = {
            ["rust-analyzer"] = {
              cargo = { allFeatures = true },
              checkOnSave = true,
              check = { command = "clippy" },
              procMacro = { enable = true },
            },
          },
        },
      }
    end,
    keys = {
      { "<leader>cR", function() vim.cmd.RustLsp("codeAction") end, desc = "Rust code action", ft = "rust" },
      { "<leader>dr", function() vim.cmd.RustLsp("debuggables") end, desc = "Rust debuggables", ft = "rust" },
    },
  },
  {
    "saecki/crates.nvim",
    event = { "BufRead Cargo.toml" },
    opts = { completion = { crates = { enabled = true } } },
  },
}
