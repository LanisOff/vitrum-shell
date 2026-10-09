return {
  "nvim-treesitter/nvim-treesitter",
  branch = "master",
  build = ":TSUpdate",
  event = { "BufReadPost", "BufNewFile" },
  dependencies = { "nvim-treesitter/nvim-treesitter-textobjects" },
  main = "nvim-treesitter.configs",
  opts = {
    ensure_installed = {
      "lua", "luadoc", "vim", "vimdoc", "query",
      "python", "rust", "c", "cpp",
      "javascript", "typescript", "tsx", "html", "css", "json", "jsonc",
      "yaml", "toml", "markdown", "markdown_inline",
      "bash", "fish", "java",
      "gitcommit", "gitignore", "diff", "regex",
      -- The desktop's own languages: niri's config, Quickshell's QML, and the
      -- Rust the compositor patch is written in (already above).
      "kdl", "qmljs", "ini",
    },
    auto_install = true,
    highlight = { enable = true },
    indent = { enable = true },
    incremental_selection = {
      enable = true,
      keymaps = {
        init_selection = "<C-space>",
        node_incremental = "<C-space>",
        node_decremental = "<bs>",
      },
    },
    textobjects = {
      select = {
        enable = true,
        lookahead = true,
        keymaps = {
          ["af"] = "@function.outer", ["if"] = "@function.inner",
          ["ac"] = "@class.outer",    ["ic"] = "@class.inner",
          ["aa"] = "@parameter.outer",["ia"] = "@parameter.inner",
        },
      },
      move = {
        enable = true,
        set_jumps = true,
        goto_next_start = { ["]f"] = "@function.outer", ["]c"] = "@class.outer" },
        goto_previous_start = { ["[f"] = "@function.outer", ["[c"] = "@class.outer" },
      },
    },
  },
}
