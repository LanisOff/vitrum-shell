local icons = require("vitrum.icons")

return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    cmd = "Neotree",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
    },
    keys = {
      { "<leader>e", "<cmd>Neotree toggle reveal<CR>", desc = "Explorer (toggle)" },
      { "<leader>E", "<cmd>Neotree focus<CR>", desc = "Explorer (focus)" },
    },
    -- IDE feel: the first time a real file loads, dock the tree (left) and the
    -- symbol outline (right), neither stealing focus. Sequenced — tree first,
    -- then aerial on a short defer — so the two window opens don't race in the
    -- same tick (which throws "Invalid window id"). Guarded so it never fights
    -- the snacks dashboard, and it fires only once so closing a panel sticks.
    init = function()
      local opened = false
      vim.api.nvim_create_autocmd("BufReadPost", {
        group = vim.api.nvim_create_augroup("UserIdeLayout", { clear = true }),
        callback = function(ev)
          if opened then return end
          if vim.bo[ev.buf].buftype ~= "" then return end
          if vim.api.nvim_buf_get_name(ev.buf) == "" then return end
          opened = true
          vim.schedule(function()
            pcall(vim.cmd, "Neotree show")
            vim.defer_fn(function() pcall(vim.cmd, "AerialOpen") end, 60)
          end)
        end,
      })
    end,
    opts = {
      close_if_last_window = true,
      popup_border_style = "rounded",
      -- File / Bufs / Git tabs across the top of the tree, the way Finder puts
      -- its view switcher in the toolbar.
      source_selector = {
        winbar = true,
        statusline = false,
        content_layout = "center",
        tabs_layout = "equal",
        separator = { left = icons.pill.left, right = icons.pill.right },
        sources = {
          { source = "filesystem", display_name = " " .. icons.ui.folder .. " File " },
          { source = "buffers", display_name = " " .. icons.ui.files .. " Bufs " },
          { source = "git_status", display_name = " " .. icons.git.branch .. " Git " },
        },
      },
      default_component_configs = {
        indent = {
          indent_marker = "│",
          last_indent_marker = "└",
          expander_collapsed = icons.ui.chevron_right,
          expander_expanded = icons.ui.chevron_down,
        },
        icon = {
          folder_closed = icons.ui.folder,
          folder_open = icons.ui.folder_open,
          folder_empty = icons.ui.folder,
          default = icons.ui.file,
        },
        modified = { symbol = icons.ui.dot },
        git_status = {
          symbols = {
            added = icons.git.added,
            modified = icons.git.modified,
            deleted = icons.git.removed,
            renamed = icons.git.renamed,
            untracked = icons.git.untracked,
            ignored = icons.git.ignored,
            staged = icons.git.staged,
            conflict = icons.git.conflict,
            unstaged = icons.git.modified,
          },
        },
      },
      filesystem = {
        follow_current_file = { enabled = true },
        use_libuv_file_watcher = true,
        filtered_items = { visible = true, hide_dotfiles = false, hide_gitignored = false },
      },
      window = { width = 32 },
    },
  },
  {
    "stevearc/oil.nvim",
    lazy = false,
    dependencies = { "nvim-tree/nvim-web-devicons" },
    keys = { { "-", "<cmd>Oil<CR>", desc = "Open parent dir (oil)" } },
    opts = {
      view_options = { show_hidden = true },
      float = { border = "rounded" },
    },
  },
}
