local icons = require("vitrum.icons")

return {
  "mfussenegger/nvim-dap",
  dependencies = {
    { "rcarriga/nvim-dap-ui", dependencies = { "nvim-neotest/nvim-nio" } },
    "theHamsta/nvim-dap-virtual-text",
    "jay-babu/mason-nvim-dap.nvim",
    "mfussenegger/nvim-dap-python",
  },
  keys = {
    { "<F5>", function() require("dap").continue() end, desc = "Debug: continue" },
    { "<F10>", function() require("dap").step_over() end, desc = "Debug: step over" },
    { "<F11>", function() require("dap").step_into() end, desc = "Debug: step into" },
    { "<F12>", function() require("dap").step_out() end, desc = "Debug: step out" },
    { "<leader>db", function() require("dap").toggle_breakpoint() end, desc = "Toggle breakpoint" },
    { "<leader>dB", function() require("dap").set_breakpoint(vim.fn.input("Condition: ")) end, desc = "Conditional breakpoint" },
    { "<leader>dc", function() require("dap").continue() end, desc = "Continue" },
    { "<leader>du", function() require("dapui").toggle() end, desc = "Toggle DAP UI" },
    { "<leader>dt", function() require("dap").terminate() end, desc = "Terminate" },
  },
  config = function()
    local dap = require("dap")
    local dapui = require("dapui")

    dapui.setup({
      floating = { border = "rounded" },
      controls = {
        icons = {
          pause = icons.ui.pause,
          play = icons.ui.play,
          step_into = icons.ui.step_into,
          step_over = icons.ui.step_over,
          step_out = icons.ui.step_out,
          step_back = icons.ui.chevron_left,
          run_last = icons.ui.history,
          terminate = icons.ui.stop,
          disconnect = icons.ui.close,
        },
      },
    })
    require("nvim-dap-virtual-text").setup({})

    require("mason-nvim-dap").setup({
      ensure_installed = { "python", "codelldb", "js" },
      automatic_installation = true,
      handlers = {}, -- use default adapter definitions
    })

    -- Python via debugpy (from Mason)
    local dbg = vim.fn.stdpath("data") .. "/mason/packages/debugpy/venv/bin/python"
    pcall(function() require("dap-python").setup(dbg) end)

    -- Open/close UI automatically
    dap.listeners.after.event_initialized["dapui_config"] = function() dapui.open() end
    dap.listeners.before.event_terminated["dapui_config"] = function() dapui.close() end
    dap.listeners.before.event_exited["dapui_config"] = function() dapui.close() end

    -- Breakpoint signs, in the desktop's semantic colours.
    vim.fn.sign_define("DapBreakpoint", { text = icons.ui.circle, texthl = "DapBreakpoint" })
    vim.fn.sign_define("DapBreakpointCondition", { text = icons.ui.circle_o, texthl = "DapBreakpointCondition" })
    vim.fn.sign_define("DapLogPoint", { text = icons.ui.dot, texthl = "DapLogPoint" })
    vim.fn.sign_define("DapStopped", { text = icons.ui.chevron_right, texthl = "DapStopped", linehl = "DapStoppedLine" })
  end,
}
