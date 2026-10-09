-- ===========================================================================
--  vitrum — a Neovim colourscheme from the desktop's palette
-- ===========================================================================
--
--  The UI chrome is the desktop's own palette (vitrum-theme renders it to
--  nvim.json, from the wallpaper or a preset); the syntax colours are hues
--  tuned for the scheme. It follows the desktop on its own (the file is
--  watched); `:VitrumSync` reloads by hand.
--
--      require("vitrum").setup({ transparent = true })
--      vim.cmd.colorscheme("vitrum")
--
--  Transparency is on by default and it matters: the terminal underneath is
--  real compositor glass, and an opaque editor throws that away.
-- ===========================================================================

local Palette = require("vitrum.palette")

local M = {}

-- ---------------------------------------------------------------- config ---

M.config = {
  --- Let the terminal's background — that is, the compositor's glass — show
  --- through. Floats and popups stay solid so they read as sheets above it.
  transparent = true,

  --- A terminal has no other way to mark prose.
  italic_comments = true,
  italic_keywords = false,
  bold_functions = false,

  --- Unfocused splits get a slightly darker background, the way an inactive
  --- unfocused window loses its colour.
  dim_inactive = true,

  --- "auto" follows settings.json. "light"/"dark" pins it.
  mode = "auto",

  --- nil follows settings.json; a name from Palette.accents pins it.
  accent = nil,

  --- Anything here is merged over the computed groups, last word wins:
  ---     overrides = { Comment = { fg = "#888888" } }
  overrides = {},
}

--- The palette in use, refreshed by load(). Read it if you are writing a
--- statusline or a plugin spec that needs a colour.
M.colors = nil

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

-- -------------------------------------------------------------- resolving --

local function resolve()
  local p, mode = Palette.current()
  if M.config.mode == "light" or M.config.mode == "dark" then
    -- A forced mode reads the other scheme from the same file next time; until
    -- then the fallback table for that scheme stands in.
    if M.config.mode ~= mode then p, mode = vim.deepcopy(Palette.fallback[M.config.mode]), M.config.mode end
  end
  if M.config.accent then p.accent = M.config.accent end
  p.mode = mode
  return p, mode
end


function M.groups(p)
  local cfg = M.config
  local none = "NONE"

  -- The editor background. Transparent means "let the terminal through",
  -- which is not the same as "black".
  local bg = cfg.transparent and none or p.bg
  local bg_alt = cfg.transparent and none or p.bg_alt

  local comment_style = { italic = cfg.italic_comments }
  local keyword_style = { italic = cfg.italic_keywords }
  local func_style = { bold = cfg.bold_functions }

  local syn = p.syn

  local g = {
    -- ------------------------------------------------------------ editor --
    Normal        = { fg = p.fg, bg = bg },
    NormalNC      = { fg = p.fg, bg = cfg.dim_inactive and (cfg.transparent and none or p.bg_dim) or bg },
    NormalFloat   = { fg = p.fg, bg = p.bg_elev },
    FloatBorder   = { fg = p.line, bg = p.bg_elev },
    FloatTitle    = { fg = p.accent, bg = p.bg_elev, bold = true },
    FloatFooter   = { fg = p.fg_dim, bg = p.bg_elev },

    Cursor        = { fg = p.bg, bg = p.accent },
    lCursor       = { link = "Cursor" },
    CursorIM      = { link = "Cursor" },
    TermCursor    = { link = "Cursor" },
    CursorLine    = { bg = p.bg_high },
    CursorColumn  = { bg = p.bg_high },
    ColorColumn   = { bg = p.bg_alt },
    CursorLineNr  = { fg = p.accent, bold = true },
    LineNr        = { fg = p.muted },
    LineNrAbove   = { fg = p.muted },
    LineNrBelow   = { fg = p.muted },
    SignColumn    = { fg = p.muted, bg = bg },
    FoldColumn    = { fg = p.muted, bg = bg },
    Folded        = { fg = p.fg_dim, bg = p.bg_high },
    Conceal       = { fg = p.muted },

    EndOfBuffer   = { fg = bg == none and p.bg or bg },
    NonText       = { fg = p.muted },
    Whitespace    = { fg = p.muted },
    SpecialKey    = { fg = p.muted },
    MatchParen    = { fg = p.accent, bold = true, underline = true },

    Directory     = { fg = p.accent },
    Title         = { fg = p.accent, bold = true },
    Question      = { fg = p.green },
    ModeMsg       = { fg = p.fg_dim, bold = true },
    MoreMsg       = { fg = p.green },
    MsgArea       = { fg = p.fg },
    MsgSeparator  = { fg = p.line, bg = bg },
    ErrorMsg      = { fg = p.red, bold = true },
    WarningMsg    = { fg = p.orange },

    Visual        = { bg = p.sel },
    VisualNOS     = { bg = p.sel },
    Search        = { fg = p.bg, bg = p.yellow },
    IncSearch     = { fg = p.bg, bg = p.orange, bold = true },
    CurSearch     = { fg = p.bg, bg = p.orange, bold = true },
    Substitute    = { fg = p.bg, bg = p.pink },
    QuickFixLine  = { bg = p.bg_high, bold = true },

    -- The completion menu, drawn like a Spotlight result list.
    Pmenu         = { fg = p.fg, bg = p.bg_elev },
    PmenuSel      = { fg = p.on_accent, bg = p.accent, bold = true },
    PmenuKind     = { fg = p.fg_dim, bg = p.bg_elev },
    PmenuKindSel  = { fg = p.on_accent, bg = p.accent },
    PmenuExtra    = { fg = p.fg_dim, bg = p.bg_elev },
    PmenuExtraSel = { fg = p.on_accent, bg = p.accent },
    PmenuSbar     = { bg = p.bg_high },
    PmenuThumb    = { bg = p.muted },
    WildMenu      = { link = "PmenuSel" },

    StatusLine    = { fg = p.fg, bg = p.bg_elev },
    StatusLineNC  = { fg = p.muted, bg = bg_alt },
    WinBar        = { fg = p.fg_dim, bg = bg },
    WinBarNC      = { fg = p.muted, bg = bg },
    WinSeparator  = { fg = p.line, bg = bg },
    TabLine       = { fg = p.fg_dim, bg = p.bg_alt },
    TabLineFill   = { bg = bg },
    TabLineSel    = { fg = p.accent, bg = bg, bold = true },

    DiffAdd       = { bg = "#12301c", fg = none },
    DiffChange    = { bg = "#1d2740", fg = none },
    DiffDelete    = { bg = "#3a1418", fg = none },
    DiffText      = { bg = "#27406b", fg = none },
    Added         = { fg = p.green },
    Changed       = { fg = p.yellow },
    Removed       = { fg = p.red },

    SpellBad      = { sp = p.red, undercurl = true },
    SpellCap      = { sp = p.yellow, undercurl = true },
    SpellLocal    = { sp = p.teal, undercurl = true },
    SpellRare     = { sp = p.purple, undercurl = true },

    -- ------------------------------------------------------------ syntax --
    Comment        = vim.tbl_extend("force", { fg = syn.comment }, comment_style),
    Constant       = { fg = syn.const },
    String         = { fg = syn.string },
    Character      = { fg = syn.string },
    Number         = { fg = syn.number },
    Boolean        = { fg = syn.number },
    Float          = { fg = syn.number },
    Identifier     = { fg = p.fg },
    Function       = vim.tbl_extend("force", { fg = syn.func }, func_style),
    Statement      = vim.tbl_extend("force", { fg = syn.keyword }, keyword_style),
    Conditional    = { link = "Statement" },
    Repeat         = { link = "Statement" },
    Label          = { link = "Statement" },
    Operator       = { fg = p.fg },
    Keyword        = { link = "Statement" },
    Exception      = { link = "Statement" },
    PreProc        = { fg = syn.preproc },
    Include        = { fg = syn.preproc },
    Define         = { fg = syn.preproc },
    Macro          = { fg = syn.preproc },
    PreCondit      = { fg = syn.preproc },
    Type           = { fg = syn.type },
    StorageClass   = { link = "Statement" },
    Structure      = { fg = syn.type },
    Typedef        = { fg = syn.type },
    Special        = { fg = syn.attribute },
    SpecialChar    = { fg = syn.number },
    Tag            = { fg = syn.type },
    Delimiter      = { fg = p.fg_dim },
    SpecialComment = { fg = syn.doc_keyword, italic = cfg.italic_comments },
    Debug          = { fg = p.orange },
    Underlined     = { underline = true },
    Ignore         = { fg = p.muted },
    Error          = { fg = p.red },
    Todo           = { fg = p.bg, bg = p.yellow, bold = true },

    -- ------------------------------------------------------- diagnostics --
    DiagnosticError = { fg = p.red },
    DiagnosticWarn  = { fg = p.orange },
    DiagnosticInfo  = { fg = p.blue },
    DiagnosticHint  = { fg = p.teal },
    DiagnosticOk    = { fg = p.green },

    DiagnosticVirtualTextError = { fg = p.red, bg = none },
    DiagnosticVirtualTextWarn  = { fg = p.orange, bg = none },
    DiagnosticVirtualTextInfo  = { fg = p.blue, bg = none },
    DiagnosticVirtualTextHint  = { fg = p.teal, bg = none },
    DiagnosticVirtualTextOk    = { fg = p.green, bg = none },

    DiagnosticUnderlineError = { sp = p.red, undercurl = true },
    DiagnosticUnderlineWarn  = { sp = p.orange, undercurl = true },
    DiagnosticUnderlineInfo  = { sp = p.blue, undercurl = true },
    DiagnosticUnderlineHint  = { sp = p.teal, undercurl = true },
    DiagnosticUnderlineOk    = { sp = p.green, undercurl = true },

    DiagnosticFloatingError = { fg = p.red, bg = p.bg_elev },
    DiagnosticFloatingWarn  = { fg = p.orange, bg = p.bg_elev },
    DiagnosticFloatingInfo  = { fg = p.blue, bg = p.bg_elev },
    DiagnosticFloatingHint  = { fg = p.teal, bg = p.bg_elev },

    DiagnosticSignError = { fg = p.red },
    DiagnosticSignWarn  = { fg = p.orange },
    DiagnosticSignInfo  = { fg = p.blue },
    DiagnosticSignHint  = { fg = p.teal },

    DiagnosticDeprecated = { fg = p.fg_dim, strikethrough = true },
    DiagnosticUnnecessary = { fg = p.muted },

    -- --------------------------------------------------------------- lsp --
    LspReferenceText  = { bg = p.bg_high },
    LspReferenceRead  = { bg = p.bg_high },
    LspReferenceWrite = { bg = p.bg_high, underline = true },
    LspSignatureActiveParameter = { fg = p.accent, bold = true },
    LspInlayHint      = { fg = p.muted, bg = none, italic = true },
    LspCodeLens       = { fg = p.muted, italic = true },
    LspCodeLensSeparator = { fg = p.muted },
    LspInfoBorder     = { link = "FloatBorder" },

    -- -------------------------------------------------------- treesitter --
    ["@variable"]                 = { fg = p.fg },
    ["@variable.builtin"]         = { fg = syn.keyword },
    ["@variable.parameter"]       = { fg = p.fg },
    ["@variable.member"]          = { fg = syn.property },

    ["@constant"]                 = { fg = syn.const },
    ["@constant.builtin"]         = { fg = syn.const_other },
    ["@constant.macro"]           = { fg = syn.preproc },

    ["@module"]                   = { fg = syn.class },
    ["@module.builtin"]           = { fg = syn.class },
    ["@label"]                    = { fg = syn.keyword },

    ["@string"]                   = { fg = syn.string },
    ["@string.documentation"]     = { fg = syn.doc },
    ["@string.regexp"]            = { fg = p.mint },
    ["@string.escape"]            = { fg = syn.number, bold = true },
    ["@string.special"]           = { fg = syn.attribute },
    ["@string.special.url"]       = { fg = syn.url, underline = true },
    ["@string.special.path"]      = { fg = syn.url },

    ["@character"]                = { fg = syn.string },
    ["@character.special"]        = { fg = syn.number },
    ["@boolean"]                  = { fg = syn.number },
    ["@number"]                   = { fg = syn.number },
    ["@number.float"]             = { fg = syn.number },

    ["@type"]                     = { fg = syn.type },
    ["@type.builtin"]             = { fg = syn.type },
    ["@type.definition"]          = { fg = syn.type },
    ["@attribute"]                = { fg = syn.attribute },
    ["@attribute.builtin"]        = { fg = syn.attribute },
    ["@property"]                 = { fg = syn.property },

    ["@function"]                 = vim.tbl_extend("force", { fg = syn.func }, func_style),
    ["@function.builtin"]         = { fg = syn.func_other },
    ["@function.call"]            = { fg = syn.func },
    ["@function.macro"]           = { fg = syn.preproc },
    ["@function.method"]          = { fg = syn.func },
    ["@function.method.call"]     = { fg = syn.func },
    ["@constructor"]              = { fg = syn.class },
    ["@operator"]                 = { fg = p.fg },

    ["@keyword"]                  = vim.tbl_extend("force", { fg = syn.keyword }, keyword_style),
    ["@keyword.function"]         = { link = "@keyword" },
    ["@keyword.operator"]         = { link = "@keyword" },
    ["@keyword.import"]           = { fg = syn.preproc },
    ["@keyword.type"]             = { link = "@keyword" },
    ["@keyword.modifier"]         = { link = "@keyword" },
    ["@keyword.repeat"]           = { link = "@keyword" },
    ["@keyword.return"]           = { link = "@keyword" },
    ["@keyword.debug"]            = { fg = p.orange },
    ["@keyword.exception"]        = { link = "@keyword" },
    ["@keyword.conditional"]      = { link = "@keyword" },
    ["@keyword.directive"]        = { fg = syn.preproc },
    ["@keyword.directive.define"] = { fg = syn.preproc },

    ["@punctuation.delimiter"]    = { fg = p.fg_dim },
    ["@punctuation.bracket"]      = { fg = p.fg_dim },
    ["@punctuation.special"]      = { fg = syn.attribute },

    ["@comment"]                  = { link = "Comment" },
    ["@comment.documentation"]    = { fg = syn.doc, italic = cfg.italic_comments },
    ["@comment.error"]            = { fg = p.bg, bg = p.red, bold = true },
    ["@comment.warning"]          = { fg = p.bg, bg = p.orange, bold = true },
    ["@comment.todo"]             = { fg = p.bg, bg = p.yellow, bold = true },
    ["@comment.note"]             = { fg = p.bg, bg = p.teal, bold = true },

    ["@markup.strong"]            = { bold = true },
    ["@markup.italic"]            = { italic = true },
    ["@markup.strikethrough"]     = { strikethrough = true },
    ["@markup.underline"]         = { underline = true },
    ["@markup.heading"]           = { fg = p.accent, bold = true },
    ["@markup.heading.1"]         = { fg = p.accent, bold = true },
    ["@markup.heading.2"]         = { fg = p.purple, bold = true },
    ["@markup.heading.3"]         = { fg = p.teal, bold = true },
    ["@markup.heading.4"]         = { fg = p.green, bold = true },
    ["@markup.heading.5"]         = { fg = p.orange, bold = true },
    ["@markup.heading.6"]         = { fg = p.pink, bold = true },
    ["@markup.quote"]             = { fg = p.fg_dim, italic = true },
    ["@markup.math"]              = { fg = p.mint },
    ["@markup.link"]              = { fg = syn.url },
    ["@markup.link.label"]        = { fg = p.accent },
    ["@markup.link.url"]          = { fg = syn.url, underline = true },
    ["@markup.raw"]               = { fg = p.mint },
    ["@markup.raw.block"]         = { fg = p.mint },
    ["@markup.list"]              = { fg = p.accent },
    ["@markup.list.checked"]      = { fg = p.green },
    ["@markup.list.unchecked"]    = { fg = p.fg_dim },

    ["@diff.plus"]                = { fg = p.green },
    ["@diff.minus"]               = { fg = p.red },
    ["@diff.delta"]               = { fg = p.yellow },

    ["@tag"]                      = { fg = syn.keyword },
    ["@tag.builtin"]              = { fg = syn.keyword },
    ["@tag.attribute"]            = { fg = syn.attribute },
    ["@tag.delimiter"]            = { fg = p.fg_dim },

    -- Semantic tokens sit above treesitter; give them the same answers so a
    -- buffer does not change colour the moment the language server attaches.
    ["@lsp.type.class"]         = { link = "@type" },
    ["@lsp.type.comment"]       = {},
    ["@lsp.type.decorator"]     = { link = "@attribute" },
    ["@lsp.type.enum"]          = { link = "@type" },
    ["@lsp.type.enumMember"]    = { link = "@constant" },
    ["@lsp.type.function"]      = { link = "@function" },
    ["@lsp.type.interface"]     = { link = "@type" },
    ["@lsp.type.macro"]         = { link = "@function.macro" },
    ["@lsp.type.method"]        = { link = "@function.method" },
    ["@lsp.type.namespace"]     = { link = "@module" },
    ["@lsp.type.parameter"]     = { link = "@variable.parameter" },
    ["@lsp.type.property"]      = { link = "@property" },
    ["@lsp.type.struct"]        = { link = "@type" },
    ["@lsp.type.type"]          = { link = "@type" },
    ["@lsp.type.typeParameter"] = { link = "@type.definition" },
    ["@lsp.type.variable"]      = { link = "@variable" },
    ["@lsp.mod.readonly"]       = { link = "@constant" },
    ["@lsp.mod.deprecated"]     = { strikethrough = true },
    ["@lsp.typemod.function.defaultLibrary"] = { link = "@function.builtin" },
    ["@lsp.typemod.variable.defaultLibrary"] = { link = "@variable.builtin" },
  }

  -- ------------------------------------------------------------- plugins --
  --
  -- Everything below is a plugin's own namespace. Each block is independent,
  -- so removing a plugin means deleting a block.

  local plugins = {
    -- telescope
    TelescopeNormal        = { fg = p.fg, bg = p.bg_elev },
    TelescopeBorder        = { fg = p.line, bg = p.bg_elev },
    TelescopeTitle         = { fg = p.on_accent, bg = p.accent, bold = true },
    TelescopePromptNormal  = { fg = p.fg, bg = p.bg_high },
    TelescopePromptBorder  = { fg = p.bg_high, bg = p.bg_high },
    TelescopePromptTitle   = { fg = p.on_accent, bg = p.accent, bold = true },
    TelescopePromptPrefix  = { fg = p.accent },
    TelescopePromptCounter = { fg = p.fg_dim },
    TelescopeResultsNormal = { fg = p.fg_dim, bg = p.bg_elev },
    TelescopeResultsBorder = { fg = p.bg_elev, bg = p.bg_elev },
    TelescopePreviewNormal = { fg = p.fg, bg = p.bg_elev },
    TelescopePreviewBorder = { fg = p.bg_elev, bg = p.bg_elev },
    TelescopePreviewTitle  = { fg = p.bg, bg = p.green, bold = true },
    TelescopeSelection     = { fg = p.fg_hi, bg = p.sel, bold = true },
    TelescopeSelectionCaret = { fg = p.accent, bg = p.sel },
    TelescopeMatching      = { fg = p.accent, bold = true },
    TelescopeMultiSelection = { fg = p.green },

    -- neo-tree
    NeoTreeNormal          = { fg = p.fg_dim, bg = bg_alt },
    NeoTreeNormalNC        = { fg = p.fg_dim, bg = bg_alt },
    NeoTreeWinSeparator    = { fg = p.line, bg = bg_alt },
    NeoTreeEndOfBuffer     = { fg = bg_alt == none and p.bg or bg_alt, bg = bg_alt },
    NeoTreeRootName        = { fg = p.accent, bold = true },
    NeoTreeDirectoryName   = { fg = p.fg_dim },
    NeoTreeDirectoryIcon   = { fg = p.accent },
    NeoTreeFileName        = { fg = p.fg_dim },
    NeoTreeFileNameOpened  = { fg = p.fg },
    NeoTreeIndentMarker    = { fg = p.muted },
    NeoTreeExpander        = { fg = p.muted },
    NeoTreeSymbolicLinkTarget = { fg = p.teal },
    NeoTreeCursorLine      = { bg = p.bg_high },
    NeoTreeTitleBar        = { fg = p.on_accent, bg = p.accent },
    NeoTreeGitAdded        = { fg = p.green },
    NeoTreeGitModified     = { fg = p.yellow },
    NeoTreeGitDeleted      = { fg = p.red },
    NeoTreeGitUntracked    = { fg = p.fg_dim, italic = true },
    NeoTreeGitIgnored      = { fg = p.muted },
    NeoTreeGitConflict     = { fg = p.orange, bold = true },
    NeoTreeTabActive       = { fg = p.accent, bg = bg_alt, bold = true },
    NeoTreeTabInactive     = { fg = p.muted, bg = bg_alt },
    NeoTreeTabSeparatorActive   = { fg = bg_alt == none and p.bg or bg_alt, bg = bg_alt },
    NeoTreeTabSeparatorInactive = { fg = bg_alt == none and p.bg or bg_alt, bg = bg_alt },

    -- gitsigns
    GitSignsAdd            = { fg = p.green },
    GitSignsChange         = { fg = p.yellow },
    GitSignsDelete         = { fg = p.red },
    GitSignsAddInline      = { bg = "#1c4a2c" },
    GitSignsChangeInline   = { bg = "#4a4520" },
    GitSignsDeleteInline   = { bg = "#4a1c22" },
    GitSignsCurrentLineBlame = { fg = p.muted, italic = true },

    -- blink.cmp
    BlinkCmpMenu            = { fg = p.fg, bg = p.bg_elev },
    BlinkCmpMenuBorder      = { fg = p.line, bg = p.bg_elev },
    BlinkCmpMenuSelection   = { fg = p.on_accent, bg = p.accent, bold = true },
    BlinkCmpScrollBarThumb  = { bg = p.muted },
    BlinkCmpScrollBarGutter = { bg = p.bg_high },
    BlinkCmpLabel           = { fg = p.fg },
    BlinkCmpLabelDeprecated = { fg = p.muted, strikethrough = true },
    BlinkCmpLabelMatch      = { fg = p.accent, bold = true },
    BlinkCmpLabelDetail     = { fg = p.fg_dim },
    BlinkCmpLabelDescription = { fg = p.muted },
    BlinkCmpKind            = { fg = p.purple },
    BlinkCmpSource          = { fg = p.muted },
    BlinkCmpGhostText       = { fg = p.muted, italic = true },
    BlinkCmpDoc             = { fg = p.fg, bg = p.bg_elev },
    BlinkCmpDocBorder       = { fg = p.line, bg = p.bg_elev },
    BlinkCmpDocSeparator    = { fg = p.line, bg = p.bg_elev },
    BlinkCmpSignatureHelp   = { fg = p.fg, bg = p.bg_elev },
    BlinkCmpSignatureHelpBorder = { fg = p.line, bg = p.bg_elev },
    BlinkCmpSignatureHelpActiveParameter = { fg = p.accent, bold = true },

    -- noice / notify
    NoiceCmdline            = { fg = p.fg, bg = p.bg_elev },
    NoiceCmdlineIcon        = { fg = p.accent },
    NoiceCmdlineIconSearch  = { fg = p.yellow },
    NoiceCmdlinePopup       = { fg = p.fg, bg = p.bg_elev },
    NoiceCmdlinePopupBorder = { fg = p.line },
    NoiceCmdlinePopupTitle  = { fg = p.accent, bold = true },
    NoiceCmdlinePrompt      = { fg = p.accent },
    NoiceConfirm            = { fg = p.fg, bg = p.bg_elev },
    NoiceConfirmBorder      = { fg = p.line },
    NoiceMini               = { fg = p.fg_dim, bg = p.bg_elev },
    NoicePopup              = { fg = p.fg, bg = p.bg_elev },
    NoicePopupBorder        = { fg = p.line },
    NoiceVirtualText        = { fg = p.fg_dim },
    NoiceLspProgressTitle   = { fg = p.fg },
    NoiceLspProgressClient  = { fg = p.accent, bold = true },
    NoiceLspProgressSpinner = { fg = p.purple },

    NotifyBackground        = { bg = p.bg_elev },
    NotifyERRORBorder       = { fg = p.red },
    NotifyWARNBorder        = { fg = p.orange },
    NotifyINFOBorder        = { fg = p.blue },
    NotifyDEBUGBorder       = { fg = p.muted },
    NotifyTRACEBorder       = { fg = p.purple },
    NotifyERRORIcon         = { fg = p.red },
    NotifyWARNIcon          = { fg = p.orange },
    NotifyINFOIcon          = { fg = p.blue },
    NotifyDEBUGIcon         = { fg = p.muted },
    NotifyTRACEIcon         = { fg = p.purple },
    NotifyERRORTitle        = { fg = p.red, bold = true },
    NotifyWARNTitle         = { fg = p.orange, bold = true },
    NotifyINFOTitle         = { fg = p.blue, bold = true },
    NotifyDEBUGTitle        = { fg = p.muted, bold = true },
    NotifyTRACETitle        = { fg = p.purple, bold = true },

    -- snacks
    SnacksNormal            = { fg = p.fg, bg = p.bg_elev },
    SnacksWinBar            = { fg = p.accent, bg = p.bg_elev, bold = true },
    SnacksBackdrop          = { bg = p.bg_dim },
    SnacksDashboardHeader   = { fg = p.accent, bold = true },
    SnacksDashboardTitle    = { fg = p.accent },
    SnacksDashboardDesc     = { fg = p.fg },
    SnacksDashboardIcon     = { fg = p.purple },
    SnacksDashboardKey      = { fg = p.orange },
    SnacksDashboardFooter   = { fg = p.muted, italic = true },
    SnacksDashboardSpecial  = { fg = p.purple },
    SnacksIndent            = { fg = p.muted },
    SnacksIndentScope       = { fg = p.accent },
    SnacksNotifierInfo      = { fg = p.blue },
    SnacksNotifierWarn      = { fg = p.orange },
    SnacksNotifierError     = { fg = p.red },
    SnacksPickerMatch       = { fg = p.accent, bold = true },

    -- which-key
    WhichKey                = { fg = p.accent, bold = true },
    WhichKeyGroup           = { fg = p.purple },
    WhichKeyDesc            = { fg = p.fg },
    WhichKeySeparator       = { fg = p.muted },
    WhichKeyFloat           = { bg = p.bg_elev },
    WhichKeyBorder          = { fg = p.line, bg = p.bg_elev },
    WhichKeyTitle           = { fg = p.accent, bold = true },
    WhichKeyValue           = { fg = p.fg_dim },

    -- trouble
    TroubleNormal           = { fg = p.fg, bg = bg_alt },
    TroubleNormalNC         = { fg = p.fg, bg = bg_alt },
    TroubleText             = { fg = p.fg },
    TroubleCount            = { fg = p.purple, bold = true },
    TroubleIndent           = { fg = p.muted },
    TroublePos              = { fg = p.fg_dim },
    TroubleSource           = { fg = p.muted },

    -- aerial
    AerialLine              = { bg = p.bg_high, bold = true },
    AerialGuide             = { fg = p.muted },
    AerialNormal            = { fg = p.fg_dim, bg = bg_alt },

    -- bufferline
    BufferLineFill                 = { bg = p.bg_dim },
    BufferLineBackground           = { fg = p.muted, bg = p.bg_alt },
    BufferLineBufferSelected       = { fg = p.fg_hi, bg = bg, bold = true, italic = false },
    BufferLineBufferVisible        = { fg = p.fg_dim, bg = p.bg_alt },
    BufferLineSeparator            = { fg = p.bg_dim, bg = p.bg_alt },
    BufferLineSeparatorSelected    = { fg = p.bg_dim, bg = bg },
    BufferLineSeparatorVisible     = { fg = p.bg_dim, bg = p.bg_alt },
    BufferLineIndicatorSelected    = { fg = p.accent, bg = bg },
    BufferLineModified             = { fg = p.yellow, bg = p.bg_alt },
    BufferLineModifiedSelected     = { fg = p.yellow, bg = bg },
    BufferLineModifiedVisible      = { fg = p.yellow, bg = p.bg_alt },
    BufferLineCloseButton          = { fg = p.muted, bg = p.bg_alt },
    BufferLineCloseButtonSelected  = { fg = p.red, bg = bg },
    BufferLineOffsetSeparator      = { fg = p.line, bg = p.bg_alt },
    BufferLineErrorSelected        = { fg = p.red, bg = bg, bold = true },
    BufferLineWarningSelected      = { fg = p.orange, bg = bg, bold = true },
    BufferLineInfoSelected         = { fg = p.blue, bg = bg, bold = true },
    BufferLineHintSelected         = { fg = p.teal, bg = bg, bold = true },

    -- dropbar
    DropBarIconKindDefault  = { fg = p.purple },
    DropBarIconUISeparator  = { fg = p.muted },
    DropBarMenuNormalFloat  = { fg = p.fg, bg = p.bg_elev },
    DropBarMenuFloatBorder  = { fg = p.line, bg = p.bg_elev },
    DropBarMenuCurrentContext = { bg = p.bg_high },
    DropBarMenuHoverEntry   = { bg = p.sel },
    DropBarCurrentContext   = { bold = true },

    -- dap / dap-ui
    DapBreakpoint           = { fg = p.red },
    DapBreakpointCondition  = { fg = p.orange },
    DapLogPoint             = { fg = p.blue },
    DapStopped              = { fg = p.yellow },
    DapStoppedLine          = { bg = "#3a3418" },
    DapUINormal             = { fg = p.fg, bg = bg_alt },
    DapUIVariable           = { fg = p.fg },
    DapUIScope              = { fg = p.accent },
    DapUIType               = { fg = p.syn.type },
    DapUIValue              = { fg = p.fg },
    DapUIModifiedValue      = { fg = p.orange, bold = true },
    DapUIDecoration         = { fg = p.line },
    DapUIThread             = { fg = p.green },
    DapUIStoppedThread      = { fg = p.accent },
    DapUISource             = { fg = p.purple },
    DapUILineNumber         = { fg = p.muted },
    DapUIFloatBorder        = { fg = p.line },
    DapUIWatchesEmpty       = { fg = p.muted },
    DapUIWatchesValue       = { fg = p.green },
    DapUIWatchesError       = { fg = p.red },
    DapUIBreakpointsPath    = { fg = p.accent },
    DapUIBreakpointsInfo    = { fg = p.green },
    DapUIBreakpointsCurrentLine = { fg = p.green, bold = true },
    DapUIPlayPause          = { fg = p.green },
    DapUIRestart            = { fg = p.green },
    DapUIStop               = { fg = p.red },
    DapUIStepOver           = { fg = p.accent },
    DapUIStepInto           = { fg = p.accent },
    DapUIStepOut            = { fg = p.accent },
    DapUIStepBack           = { fg = p.accent },

    -- neotest
    NeotestPassed           = { fg = p.green },
    NeotestFailed           = { fg = p.red },
    NeotestRunning          = { fg = p.yellow },
    NeotestSkipped          = { fg = p.muted },
    NeotestDir              = { fg = p.accent },
    NeotestFile             = { fg = p.teal },
    NeotestNamespace        = { fg = p.purple },
    NeotestFocused          = { bold = true },
    NeotestAdapterName      = { fg = p.purple, bold = true },
    NeotestBorder           = { fg = p.line },
    NeotestIndent           = { fg = p.muted },
    NeotestWinSelect        = { fg = p.accent, bold = true },
    NeotestMarked           = { fg = p.orange, bold = true },
    NeotestTarget           = { fg = p.red },

    -- todo-comments
    TodoBgTODO              = { fg = p.bg, bg = p.blue, bold = true },
    TodoBgFIX               = { fg = p.bg, bg = p.red, bold = true },
    TodoBgHACK              = { fg = p.bg, bg = p.orange, bold = true },
    TodoBgWARN              = { fg = p.bg, bg = p.yellow, bold = true },
    TodoBgPERF              = { fg = p.bg, bg = p.purple, bold = true },
    TodoBgNOTE              = { fg = p.bg, bg = p.teal, bold = true },
    TodoBgTEST              = { fg = p.bg, bg = p.mint, bold = true },
    TodoFgTODO              = { fg = p.blue },
    TodoFgFIX               = { fg = p.red },
    TodoFgHACK              = { fg = p.orange },
    TodoFgWARN              = { fg = p.yellow },
    TodoFgPERF              = { fg = p.purple },
    TodoFgNOTE              = { fg = p.teal },
    TodoFgTEST              = { fg = p.mint },

    -- mini.*
    MiniIndentscopeSymbol   = { fg = p.accent },
    MiniAiIndicator         = { fg = p.accent },

    -- oil
    OilDir                  = { fg = p.accent },
    OilDirIcon              = { fg = p.accent },
    OilLink                 = { fg = p.teal },
    OilFile                 = { fg = p.fg },

    -- diffview
    DiffviewNormal          = { fg = p.fg_dim, bg = bg_alt },
    DiffviewFilePanelTitle  = { fg = p.accent, bold = true },
    DiffviewFilePanelCounter = { fg = p.purple, bold = true },
    DiffviewFilePanelFileName = { fg = p.fg },
    DiffviewStatusAdded     = { fg = p.green },
    DiffviewStatusModified  = { fg = p.yellow },
    DiffviewStatusDeleted   = { fg = p.red },
    DiffviewStatusRenamed   = { fg = p.blue },
    DiffviewStatusUntracked = { fg = p.fg_dim },
    DiffviewFolderSign      = { fg = p.accent },

    -- lazy / mason / fidget
    LazyNormal              = { fg = p.fg, bg = p.bg_elev },
    LazyH1                  = { fg = p.on_accent, bg = p.accent, bold = true },
    LazyH2                  = { fg = p.accent, bold = true },
    LazyButton              = { fg = p.fg_dim, bg = p.bg_high },
    LazyButtonActive        = { fg = p.on_accent, bg = p.accent, bold = true },
    LazyProgressDone        = { fg = p.green, bold = true },
    LazyProgressTodo        = { fg = p.muted },
    LazyCommit              = { fg = p.purple },
    LazyReasonPlugin        = { fg = p.purple },
    LazySpecial             = { fg = p.accent },

    MasonNormal             = { fg = p.fg, bg = p.bg_elev },
    MasonHeader             = { fg = p.on_accent, bg = p.accent, bold = true },
    MasonHeaderSecondary    = { fg = p.bg, bg = p.purple, bold = true },
    MasonHighlight          = { fg = p.accent },
    MasonHighlightBlock     = { fg = p.bg, bg = p.accent },
    MasonHighlightBlockBold = { fg = p.bg, bg = p.accent, bold = true },
    MasonMuted              = { fg = p.muted },
    MasonMutedBlock         = { fg = p.fg_dim, bg = p.bg_high },

    FidgetTask              = { fg = p.muted },
    FidgetTitle             = { fg = p.accent, bold = true },

    -- supermaven / inline AI suggestions
    SupermavenSuggestion    = { fg = p.muted, italic = true },

    -- crates.nvim
    CratesNvimLoading       = { fg = p.muted },
    CratesNvimVersion       = { fg = p.green },
    CratesNvimPreRelease    = { fg = p.orange },

    -- rainbow / ts-context
    TreesitterContext           = { bg = p.bg_high },
    TreesitterContextLineNumber = { fg = p.muted, bg = p.bg_high },
  }

  for k, v in pairs(plugins) do g[k] = v end
  for k, v in pairs(cfg.overrides or {}) do g[k] = v end

  return g
end

-- ------------------------------------------------------------------ load ---

function M.load()
  local p, mode = resolve()
  M.colors = p

  if vim.g.colors_name then vim.cmd("hi clear") end
  if vim.fn.exists("syntax_on") == 1 then vim.cmd("syntax reset") end

  vim.o.termguicolors = true
  vim.o.background = mode
  vim.g.colors_name = "vitrum"

  local set = vim.api.nvim_set_hl
  for group, spec in pairs(M.groups(p)) do
    set(0, group, spec)
  end

  -- Terminal colours, so :terminal and lazygit agree with the editor. These
  -- are the same sixteen kitty is configured with.
  local t = {
    p.bg_high, p.red, p.green, p.yellow, p.blue, p.purple, p.mint, p.fg,
    p.muted, p.red, p.green, p.yellow, p.blue, p.purple, p.mint, p.fg_hi,
  }
  for i, c in ipairs(t) do
    vim.g["terminal_color_" .. (i - 1)] = c
  end

  vim.api.nvim_exec_autocmds("ColorScheme", { pattern = "vitrum" })
end

--- Re-read the palette and reapply. Bound to :VitrumSync.
function M.sync()
  if vim.g.colors_name == "vitrum" then M.load() end
end

vim.api.nvim_create_user_command("VitrumSync", function()
  M.load()
  vim.notify("vitrum: " .. (M.colors and M.colors.mode or "?") .. ", accent " ..
    (M.colors and M.colors.accent or "?"))
end, { desc = "Re-read the desktop appearance and reload the colourscheme" })

return M
