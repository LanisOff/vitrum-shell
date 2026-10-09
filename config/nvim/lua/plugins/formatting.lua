return {
  {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    cmd = { "ConformInfo" },
    keys = {
      { "<leader>cf", function() require("conform").format({ async = true, lsp_format = "fallback" }) end, mode = { "n", "v" }, desc = "Format buffer" },
    },
    opts = {
      formatters_by_ft = {
        lua = { "stylua" },
        python = { "ruff_format" },
        rust = { "rustfmt" },
        c = { "clang-format" },
        cpp = { "clang-format" },
        javascript = { "prettierd" },
        typescript = { "prettierd" },
        javascriptreact = { "prettierd" },
        typescriptreact = { "prettierd" },
        html = { "prettierd" },
        css = { "prettierd" },
        json = { "prettierd" },
        yaml = { "prettierd" },
        markdown = { "prettierd" },
        sh = { "shfmt" },
        bash = { "shfmt" },
        java = { "google-java-format" },
        fish = { "fish_indent" },
      },
      format_on_save = function(bufnr)
        -- respect a per-buffer disable flag
        if vim.b[bufnr].disable_autoformat then return end
        return { timeout_ms = 1500, lsp_format = "fallback" }
      end,
    },
    init = function()
      vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
    end,
  },
  {
    "mfussenegger/nvim-lint",
    event = { "BufReadPost", "BufWritePost" },
    config = function()
      local lint = require("lint")
      lint.linters_by_ft = {
        python = { "ruff" },
        sh = { "shellcheck" },
        bash = { "shellcheck" },
      }
      local grp = vim.api.nvim_create_augroup("UserLint", { clear = true })
      vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost", "InsertLeave" }, {
        group = grp,
        callback = function() require("lint").try_lint() end,
      })
    end,
  },
}
