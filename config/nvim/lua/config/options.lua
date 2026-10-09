-- Leader FIRST, before any plugin can read it.
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

local opt = vim.opt
opt.number = true
opt.relativenumber = true
opt.mouse = "a"
opt.showmode = false
opt.clipboard = "unnamedplus"
opt.breakindent = true
opt.undofile = true
opt.ignorecase = true
opt.smartcase = true
opt.signcolumn = "yes"
opt.updatetime = 250
opt.timeoutlen = 400
opt.splitright = true
opt.splitbelow = true
opt.list = true
opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }
opt.inccommand = "split"
opt.cursorline = true
opt.scrolloff = 8
opt.confirm = true
opt.termguicolors = true
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.smartindent = true
opt.wrap = false
opt.completeopt = "menu,menuone,noselect"
opt.winborder = "rounded"

-- The terminal underneath is real compositor glass, so leave the
-- editor's own chrome as thin as possible and let it show through.
opt.pumblend = 0          -- the completion menu is a sheet, not a wash
opt.winblend = 0
opt.fillchars = {
  eob = " ",              -- no ~ past the end of the buffer
  fold = " ",
  foldopen = "▾",   -- plain box-drawing, so folds are legible in a TTY too
  foldsep = " ",
  foldclose = "▸",
  diff = "╱",
  horiz = "─", horizup = "┴", horizdown = "┬",
  vert = "│", vertleft = "┤", vertright = "├", verthoriz = "┼",
}
opt.smoothscroll = true
opt.laststatus = 3        -- one global statusline, like one menu bar
opt.cmdheight = 0         -- noice draws the command line as a floating sheet
opt.shortmess:append("sIWc")
opt.sessionoptions = { "buffers", "curdir", "tabpages", "winsize", "help", "globals", "skiprtp", "folds" }

-- Folds, from treesitter, but open by default.
opt.foldmethod = "expr"
opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
opt.foldlevel = 99
opt.foldlevelstart = 99
opt.foldenable = true

-- Undercurls survive tmux because tmux.conf declares usstyle for the outer
-- terminal; without that these are silently dropped.
vim.g.markdown_recommended_style = 0
