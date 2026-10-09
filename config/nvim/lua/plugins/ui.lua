local icons = require("vitrum.icons")

-- Active LSP servers + conform formatters + nvim-lint linters for this buffer,
-- rendered as one space-joined list (e.g. "basedpyright ruff mypy black").
local function attached_tools()
  local buf = vim.api.nvim_get_current_buf()
  local names, seen = {}, {}
  local add = function(n)
    if n and n ~= "" and not seen[n] then seen[n] = true; names[#names + 1] = n end
  end
  for _, c in pairs(vim.lsp.get_clients({ bufnr = buf })) do add(c.name) end
  local ok_c, conform = pcall(require, "conform")
  if ok_c and conform.list_formatters then
    for _, f in ipairs(conform.list_formatters(buf)) do
      if f.available then add(f.name) end
    end
  end
  local ok_l, lint = pcall(require, "lint")
  if ok_l then
    for _, l in ipairs(lint.linters_by_ft[vim.bo[buf].filetype] or {}) do add(l) end
  end
  return table.concat(names, " ")
end

return {
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = function()
      -- Rounded caps rather than powerline arrows, so the statusline reads as
      -- the same pill the Dock and the prompt are made of.
      return {
        options = {
          theme = require("vitrum.lualine").build(),
          globalstatus = true,
          component_separators = "",
          section_separators = { left = icons.pill.right, right = icons.pill.left },
          disabled_filetypes = { statusline = { "dashboard", "snacks_dashboard" } },
        },
        sections = {
          lualine_a = { { "mode", icon = icons.mark } },
          lualine_b = {
            { "branch", icon = icons.git.branch },
            {
              "diff",
              symbols = {
                added = icons.git.added .. " ",
                modified = icons.git.modified .. " ",
                removed = icons.git.removed .. " ",
              },
            },
          },
          lualine_c = {
            { "filename", path = 1, symbols = { modified = " " .. icons.ui.dot, readonly = " " .. icons.ui.lock } },
          },
          lualine_x = {
            { attached_tools, icon = icons.ui.cog, color = { gui = "italic" } },
            {
              "diagnostics",
              symbols = {
                error = icons.diagnostics.error,
                warn = icons.diagnostics.warn,
                info = icons.diagnostics.info,
                hint = icons.diagnostics.hint,
              },
            },
            "encoding",
            "fileformat",
            { "filetype", icon_only = false },
          },
          lualine_y = { { "progress" } },
          lualine_z = { { "location", icon = icons.ui.pin } },
        },
        inactive_sections = {
          lualine_c = { { "filename", path = 1 } },
          lualine_x = { "location" },
        },
        extensions = { "neo-tree", "lazy", "trouble", "aerial", "man", "quickfix" },
      }
    end,
    config = function(_, opts)
      require("lualine").setup(opts)
      -- The theme is a plain table, so it does not follow :VitrumSync on its
      -- own — hand lualine a freshly built one whenever the scheme reloads.
      vim.api.nvim_create_autocmd("ColorScheme", {
        group = vim.api.nvim_create_augroup("VitrumLualine", { clear = true }),
        pattern = "vitrum",
        callback = function()
          local o = vim.deepcopy(opts)
          o.options.theme = require("vitrum.lualine").build()
          require("lualine").setup(o)
        end,
      })
    end,
  },
  {
    -- Winbar breadcrumbs (EventHandler > track_start) with a clickable picker
    "Bekaboo/dropbar.nvim",
    event = { "BufReadPost", "BufNewFile" },
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      icons = {
        ui = { bar = { separator = " " .. icons.ui.chevron_right .. " ", extends = icons.ui.ellipsis } },
      },
    },
    keys = {
      { "<leader>cB", function() require("dropbar.api").pick() end, desc = "Breadcrumbs (pick)" },
    },
  },
  {
    "akinsho/bufferline.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      options = {
        diagnostics = "nvim_lsp",
        always_show_bufferline = false,
        -- Safari's tab shape: rounded on both ends, a slim indicator on top.
        separator_style = { icons.pill.right, icons.pill.left },
        indicator = { style = "underline" },
        modified_icon = icons.ui.dot,
        close_icon = icons.ui.close,
        buffer_close_icon = icons.ui.close,
        left_trunc_marker = icons.ui.chevron_left,
        right_trunc_marker = icons.ui.chevron_right,
        offsets = {
          { filetype = "neo-tree", text = "Explorer", separator = true, highlight = "NeoTreeTitleBar" },
          { filetype = "aerial", text = "Symbols", separator = true, highlight = "NeoTreeTitleBar" },
        },
        diagnostics_indicator = function(_, _, diag)
          local s = {}
          if diag.error then s[#s + 1] = icons.diagnostics.error .. diag.error end
          if diag.warning then s[#s + 1] = icons.diagnostics.warn .. diag.warning end
          return table.concat(s, " ")
        end,
      },
    },
  },
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      preset = "helix",
      win = { border = "rounded" },
      icons = { separator = icons.ui.chevron_right },
      spec = {
        { "<leader>f", group = "find", icon = icons.ui.search },
        { "<leader>g", group = "git", icon = icons.git.branch },
        { "<leader>c", group = "code", icon = icons.ui.code },
        { "<leader>d", group = "debug", icon = icons.ui.bug },
        { "<leader>t", group = "test", icon = icons.ui.flask },
        { "<leader>a", group = "ai", icon = icons.ui.robot },
        { "<leader>x", group = "diagnostics", icon = icons.ui.warning },
        { "<leader>b", group = "buffer", icon = icons.ui.files },
        { "<leader>q", group = "session", icon = icons.ui.history },
        { "<leader>u", group = "ui", icon = icons.ui.eye },
      },
    },
  },
  {
    "folke/noice.nvim",
    event = "VeryLazy",
    dependencies = { "MunifTanjim/nui.nvim", "rcarriga/nvim-notify" },
    opts = {
      lsp = {
        override = {
          ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
          ["vim.lsp.util.stylize_markdown"] = true,
          ["cmp.entry.get_documentation"] = true,
        },
      },
      presets = {
        bottom_search = true,
        command_palette = true,
        long_message_to_split = true,
        lsp_doc_border = true,
      },
      -- Spotlight's proportions: a sheet near the top of the screen, not a
      -- line glued to the bottom.
      views = {
        cmdline_popup = {
          position = { row = "18%", col = "50%" },
          size = { width = 68, height = "auto" },
          border = { style = "rounded", padding = { 0, 2 } },
          win_options = { winhighlight = { Normal = "NoiceCmdlinePopup", FloatBorder = "NoiceCmdlinePopupBorder" } },
        },
        popupmenu = {
          relative = "editor",
          position = { row = "24%", col = "50%" },
          size = { width = 68, height = 10 },
          border = { style = "rounded", padding = { 0, 1 } },
        },
        mini = { win_options = { winblend = 0 } },
      },
    },
  },
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    opts = function()
      return {
        bigfile = { enabled = true },
        quickfile = { enabled = true },
        indent = { enabled = true, scope = { enabled = true } },
        statuscolumn = { enabled = true },
        words = { enabled = true },
        notifier = { enabled = true, style = "fancy" },
        input = { enabled = true },
        scope = { enabled = true },
        dashboard = {
          enabled = true,
          -- snacks' own header (NEOVIM); only the keys are ours.
          preset = {
            keys = {
              { icon = icons.ui.search, key = "f", desc = "Find file", action = ":Telescope find_files" },
              { icon = icons.ui.file, key = "n", desc = "New file", action = ":ene | startinsert" },
              { icon = icons.ui.code, key = "g", desc = "Find text", action = ":Telescope live_grep" },
              { icon = icons.ui.history, key = "r", desc = "Recent files", action = ":Telescope oldfiles" },
              { icon = icons.ui.cog, key = "c", desc = "Config", action = ":e $MYVIMRC" },
              { icon = icons.ui.clock, key = "s", desc = "Restore session", section = "session" },
              { icon = icons.ui.package, key = "l", desc = "Lazy", action = ":Lazy" },
              { icon = icons.ui.close, key = "q", desc = "Quit", action = ":qa" },
            },
          },
        },
        terminal = { enabled = true, win = { border = "rounded" } },
        lazygit = { enabled = true },
        styles = {
          notification = { border = "rounded", wo = { winblend = 0 } },
        },
      }
    end,
    keys = {
      { "<leader>gg", function() require("snacks").lazygit() end, desc = "Lazygit" },
      { "<c-\\>", function() require("snacks").terminal.toggle() end, desc = "Toggle terminal", mode = { "n", "t" } },
      { "<leader>tt", function() require("snacks").terminal.toggle() end, desc = "Toggle terminal" },
    },
  },
}
