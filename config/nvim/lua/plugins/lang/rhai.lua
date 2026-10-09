-- Rhai support. There is no Rhai parser in the nvim-treesitter registry and no
-- Mason LSP package, so:
--   * syntax highlighting + ftdetect come from the official vim-rhai plugin;
--   * an optional `rhai-lsp` binary on PATH is wired up if present (best-effort).
-- Basic .rhai filetype detection also lives in autocmds.lua so the ft-lazy load
-- below triggers reliably.

-- Best-effort LSP: start a `rhai-lsp` only if such a binary exists. No-op
-- otherwise; must never error.
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("UserRhai", { clear = true }),
  pattern = "rhai",
  callback = function(ev)
    local bin = vim.fn.exepath("rhai-lsp")
    if bin == "" then return end -- no LSP available: syntax only
    local caps = vim.lsp.protocol.make_client_capabilities()
    local ok, blink = pcall(require, "blink.cmp")
    if ok then caps = blink.get_lsp_capabilities(caps) end
    vim.lsp.start({
      name = "rhai_lsp",
      cmd = { bin, "run" },
      root_dir = vim.fs.root(ev.buf, { ".git" }) or vim.fn.getcwd(),
      capabilities = caps,
    })
  end,
})

return {
  -- Official Rhai syntax highlighting + ftdetect.
  { "rhaiscript/vim-rhai", ft = "rhai" },
}
