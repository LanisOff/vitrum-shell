local augroup = vim.api.nvim_create_augroup("UserConfig", { clear = true })

-- Highlight on yank (vim.hl in 0.11+, fall back to vim.highlight)
vim.api.nvim_create_autocmd("TextYankPost", {
  group = augroup,
  callback = function() (vim.hl or vim.highlight).on_yank() end,
})

-- Trim trailing whitespace on save
vim.api.nvim_create_autocmd("BufWritePre", {
  group = augroup,
  callback = function()
    local save = vim.fn.winsaveview()
    vim.cmd([[keeppatterns %s/\s\+$//e]])
    vim.fn.winrestview(save)
  end,
})

-- Filetype: treat .rhai as rhai
vim.filetype.add({ extension = { rhai = "rhai" } })

-- niri's config language, so editing ~/.config/niri/config.kdl is not plain
-- text. The treesitter parser is called kdl too.
vim.filetype.add({ extension = { kdl = "kdl" } })

-- Close some filetypes with q
vim.api.nvim_create_autocmd("FileType", {
  group = augroup,
  pattern = { "help", "qf", "man", "checkhealth", "lspinfo" },
  callback = function(ev)
    vim.bo[ev.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = ev.buf, silent = true })
  end,
})

-- --------------------------------------------------------------- vitrum ----
--
-- Follow the desktop: vitrum-theme rewrites nvim.json whenever the palette or
-- the scheme changes (wallpaper, light/dark, accent). It is watched, not polled.

do
  local path = require("vitrum.palette").path()
  if vim.uv and vim.uv.new_fs_event then
    local handle = vim.uv.new_fs_event()
    local dir = vim.fn.fnamemodify(path, ":h")
    if handle and vim.fn.isdirectory(dir) == 1 then
      -- The file is replaced (written then renamed), so the directory is watched.
      handle:start(dir, {}, vim.schedule_wrap(function(err, name)
        if not err and name == "nvim.json" then require("vitrum").sync() end
      end))
    end
  end
end
