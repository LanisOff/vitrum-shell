local map = vim.keymap.set

-- Clear search highlight
map("n", "<Esc>", "<cmd>nohlsearch<CR>")

-- Better window navigation
map("n", "<C-h>", "<C-w>h", { desc = "Go to left window" })
map("n", "<C-j>", "<C-w>j", { desc = "Go to lower window" })
map("n", "<C-k>", "<C-w>k", { desc = "Go to upper window" })
map("n", "<C-l>", "<C-w>l", { desc = "Go to right window" })

-- Resize with arrows
map("n", "<C-Up>", "<cmd>resize +2<CR>", { desc = "Increase height" })
map("n", "<C-Down>", "<cmd>resize -2<CR>", { desc = "Decrease height" })
map("n", "<C-Left>", "<cmd>vertical resize -2<CR>", { desc = "Decrease width" })
map("n", "<C-Right>", "<cmd>vertical resize +2<CR>", { desc = "Increase width" })

-- Move lines
map("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
map("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })

-- Keep cursor centered
map("n", "<C-d>", "<C-d>zz")
map("n", "<C-u>", "<C-u>zz")
map("n", "n", "nzzzv")
map("n", "N", "Nzzzv")

-- Buffers
map("n", "<S-h>", "<cmd>bprevious<CR>", { desc = "Prev buffer" })
map("n", "<S-l>", "<cmd>bnext<CR>", { desc = "Next buffer" })
map("n", "<leader>bd", "<cmd>bdelete<CR>", { desc = "Delete buffer" })

-- Diagnostics (<leader>e is reserved for the file explorer)
map("n", "[d", function() vim.diagnostic.jump({ count = -1 }) end, { desc = "Prev diagnostic" })
map("n", "]d", function() vim.diagnostic.jump({ count = 1 }) end, { desc = "Next diagnostic" })
map("n", "<leader>cd", vim.diagnostic.open_float, { desc = "Line diagnostics" })

-- --------------------------------------------------------------- vitrum ----
--
-- The desktop's conventions, where they translate. Mod is Super out there and
-- cannot reach a terminal application, so these live under the leader.

map("n", "<leader>ut", "<cmd>VitrumSync<CR>", { desc = "Sync appearance with the desktop" })
map("n", "<leader>uT", function()
  local t = require("vitrum")
  t.setup({ transparent = not t.config.transparent })
  t.load()
  vim.notify("Transparency " .. (t.config.transparent and "on" or "off"))
end, { desc = "Toggle transparency" })
map("n", "<leader>ub", function()
  local t = require("vitrum")
  t.setup({ mode = (vim.o.background == "dark") and "light" or "dark" })
  t.load()
end, { desc = "Toggle light / dark" })
