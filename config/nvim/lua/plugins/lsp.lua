local icons = require("vitrum.icons")

return {
  "neovim/nvim-lspconfig",
  event = { "BufReadPre", "BufNewFile" },
  dependencies = {
    { "mason-org/mason.nvim", opts = { ui = { border = "rounded" } } },
    "mason-org/mason-lspconfig.nvim",
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    { "j-hui/fidget.nvim", opts = {} },
    { "folke/lazydev.nvim", ft = "lua", opts = {
        library = { { path = "${3rd}/luv/library", words = { "vim%.uv" } } },
    } },
  },
  config = function()
    -- Diagnostics UI
    vim.diagnostic.config({
      severity_sort = true,
      float = { border = "rounded", source = true },
      virtual_text = { prefix = icons.ui.dot },
      signs = {
        text = {
          [vim.diagnostic.severity.ERROR] = icons.diagnostics.error,
          [vim.diagnostic.severity.WARN]  = icons.diagnostics.warn,
          [vim.diagnostic.severity.INFO]  = icons.diagnostics.info,
          [vim.diagnostic.severity.HINT]  = icons.diagnostics.hint,
        },
      },
    })

    -- Keymaps on attach
    vim.api.nvim_create_autocmd("LspAttach", {
      group = vim.api.nvim_create_augroup("UserLspAttach", { clear = true }),
      callback = function(ev)
        local map = function(keys, fn, desc)
          vim.keymap.set("n", keys, fn, { buffer = ev.buf, desc = "LSP: " .. desc })
        end
        map("gd", "<cmd>Telescope lsp_definitions<CR>", "Go to definition")
        map("gr", "<cmd>Telescope lsp_references<CR>", "References")
        map("gI", "<cmd>Telescope lsp_implementations<CR>", "Implementations")
        map("gy", "<cmd>Telescope lsp_type_definitions<CR>", "Type definition")
        map("K", vim.lsp.buf.hover, "Hover")
        map("<leader>rn", vim.lsp.buf.rename, "Rename")
        map("<leader>ca", vim.lsp.buf.code_action, "Code action")
        map("<leader>cl", vim.lsp.codelens.run, "CodeLens")
        local client = vim.lsp.get_client_by_id(ev.data.client_id)
        if client and client:supports_method("textDocument/inlayHint") then
          vim.keymap.set("n", "<leader>ci", function()
            vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = ev.buf }), { bufnr = ev.buf })
          end, { buffer = ev.buf, desc = "LSP: Toggle inlay hints" })
        end
      end,
    })

    -- Capabilities from blink (guarded)
    local caps = vim.lsp.protocol.make_client_capabilities()
    local ok, blink = pcall(require, "blink.cmp")
    if ok then caps = blink.get_lsp_capabilities(caps) end
    vim.lsp.config("*", { capabilities = caps })

    -- Per-server settings
    local servers = {
      lua_ls = { settings = { Lua = { workspace = { checkThirdParty = false }, hint = { enable = true }, codeLens = { enable = true }, diagnostics = { globals = { "vim" } } } } },
      basedpyright = { settings = { basedpyright = { analysis = { typeCheckingMode = "standard", autoImportCompletions = true } } } },
      clangd = { cmd = { "clangd", "--background-index", "--clang-tidy" } },
      vtsls = { settings = { typescript = { inlayHints = { parameterNames = { enabled = "all" } } } } },
      eslint = {},
      tailwindcss = {},
      bashls = {},
      fish_lsp = {},
      jsonls = {},
      yamlls = {},
    }
    for name, cfg in pairs(servers) do
      vim.lsp.config(name, cfg)
    end

    -- Register Mason with lspconfig, but DO NOT auto-enable everything:
    -- automatic_enable turns on any installed package that maps to an
    -- lspconfig server, including formatters with an experimental LSP mode
    -- (e.g. `stylua --lsp`). Enable an explicit, curated list instead.
    -- rust_analyzer and jdtls are intentionally absent (owned by
    -- rustaceanvim / nvim-jdtls).
    require("mason-lspconfig").setup({ automatic_enable = false })

    vim.lsp.enable({
      "lua_ls", "basedpyright", "clangd", "vtsls", "eslint",
      "tailwindcss", "bashls", "jsonls", "yamlls", "fish_lsp",
    })

    -- Single source of truth for everything Mason should install (LSP servers,
    -- formatters, linters, DAP adapters). Uses Mason package names.
    require("mason-tool-installer").setup({
      ensure_installed = {
        -- LSP servers
        "lua-language-server", "basedpyright", "clangd", "vtsls", "eslint-lsp",
        "tailwindcss-language-server", "bash-language-server", "json-lsp",
        "yaml-language-server", "fish-lsp",
        -- formatters / linters
        "stylua", "ruff", "prettierd", "shfmt", "shellcheck",
        "clang-format", "google-java-format",
        -- Java (LSP owned by nvim-jdtls; debug/test bundles for DAP + neotest)
        "jdtls", "java-debug-adapter", "java-test",
        -- DAP adapters
        "debugpy", "codelldb", "js-debug-adapter",
      },
    })
  end,
}
