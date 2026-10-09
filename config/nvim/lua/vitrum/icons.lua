-- ===========================================================================
--  vitrum — icons
-- ===========================================================================
--
--  Every glyph the config uses, in one table, addressed by name.
--
--  They are built from codepoints rather than pasted in as characters. Nerd
--  Font glyphs live in the Private Use Area, where they are invisible in a
--  diff, unsearchable, and easy to mangle by copying a file through a tool
--  that normalises text. `u(0xf1b2)` beside the name `mark` survives all of
--  that and tells you what it is.
--
--  Codepoints are Nerd Fonts v3. If one shows as a box, the font is missing,
--  not the config.
-- ===========================================================================

local function u(cp)
  return vim.fn.nr2char(cp)
end

local M = {}

M.mark = u(0xf1b2)   -- the vitrum mark (a cube)

-- ------------------------------------------------------------ diagnostics --
M.diagnostics = {
  error = u(0xf057) .. " ",   -- times-circle
  warn  = u(0xf071) .. " ",   -- exclamation-triangle
  info  = u(0xf05a) .. " ",   -- info-circle
  hint  = u(0xf0eb) .. " ",   -- lightbulb-o
}

-- -------------------------------------------------------------------- git --
M.git = {
  branch    = u(0xe725),
  commit    = u(0xe729),
  added     = u(0xf457),      -- oct-diff-added
  modified  = u(0xf459),      -- oct-diff-modified
  removed   = u(0xf458),      -- oct-diff-removed
  renamed   = u(0xf45a),
  untracked = u(0xf128),
  ignored   = u(0xf147),
  staged    = u(0xf055),
  conflict  = u(0xf071),
  bar       = u(0x258e),      -- ▎ the hunk sign in the gutter
}

-- ------------------------------------------------------------------- ui ----
M.ui = {
  chevron_right = u(0xf054),
  chevron_left  = u(0xf053),
  chevron_down  = u(0xf078),
  arrow_right   = u(0xf061),
  circle        = u(0xf111),
  circle_o      = u(0xf10c),
  check         = u(0xf00c),
  close         = u(0xf00d),
  search        = u(0xf002),
  folder        = u(0xf07b),
  folder_open   = u(0xf07c),
  file          = u(0xf15b),
  files         = u(0xf0c5),
  lock          = u(0xf023),
  bell          = u(0xf0f3),
  cog           = u(0xf013),
  bolt          = u(0xf0e7),
  clock         = u(0xf017),
  bookmark      = u(0xf02e),
  tag           = u(0xf02b),
  terminal      = u(0xf489),
  package       = u(0xf487),
  bug           = u(0xf188),
  flask         = u(0xf0c3),
  robot         = u(0xf06a9),  -- nf-md-robot
  history       = u(0xf1da),
  keyboard      = u(0xf11c),
  eye           = u(0xf06e),
  pin           = u(0xf08d),
  dot           = u(0xf444),
  ellipsis      = u(0xf141),
  zoom          = u(0xf065),
  warning       = u(0xf071),
  sitemap       = u(0xf0e8),
  code          = u(0xf121),
  book          = u(0xf02d),
  question      = u(0xf059),
  play          = u(0xf04b),
  pause         = u(0xf04c),
  stop          = u(0xf04d),
  step_over     = u(0xf051),
  step_into     = u(0xf063),
  step_out      = u(0xf062),
}

-- The rounded pill caps the desktop, the prompt and tmux all use.
M.pill = {
  left  = u(0xe0b6),
  right = u(0xe0b4),
  -- Thin variants, for the statusline's inner section joins.
  thin_left  = u(0xe0b7),
  thin_right = u(0xe0b5),
}

M.u = u

return M
