return {
  "nvim-neotest/neotest",
  dependencies = {
    "nvim-neotest/nvim-nio",
    "nvim-lua/plenary.nvim",
    "antoinemadec/FixCursorHold.nvim",
    "nvim-treesitter/nvim-treesitter",
    "nvim-neotest/neotest-python",
    "nvim-neotest/neotest-jest",
    "rcasia/neotest-java",
    -- Rust tests are provided by rustaceanvim's neotest adapter
  },
  keys = {
    { "<leader>tr", function() require("neotest").run.run() end, desc = "Run nearest test" },
    { "<leader>tf", function() require("neotest").run.run(vim.fn.expand("%")) end, desc = "Run file tests" },
    { "<leader>td", function() require("neotest").run.run({ strategy = "dap" }) end, desc = "Debug nearest test" },
    { "<leader>ts", function() require("neotest").summary.toggle() end, desc = "Test summary" },
    { "<leader>to", function() require("neotest").output.open({ enter = true }) end, desc = "Test output" },
    { "<leader>tS", function() require("neotest").run.stop() end, desc = "Stop test" },
  },
  config = function()
    local icons = require("vitrum.icons")
    local adapters = {
      require("neotest-python")({ dap = { justMyCode = false } }),
      require("neotest-jest")({}),
      require("neotest-java")({}),
    }
    -- rustaceanvim ships a neotest adapter; include it if available
    local ok, rust = pcall(function() return require("rustaceanvim.neotest") end)
    if ok then table.insert(adapters, rust) end
    require("neotest").setup({
      adapters = adapters,
      icons = {
        passed = icons.ui.check,
        failed = icons.ui.close,
        running = icons.ui.circle_o,
        skipped = icons.ui.ellipsis,
        unknown = icons.ui.question,
        expanded = icons.ui.chevron_down,
        collapsed = icons.ui.chevron_right,
      },
      floating = { border = "rounded" },
    })
  end,
}
