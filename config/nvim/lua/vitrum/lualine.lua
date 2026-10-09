-- ===========================================================================
--  vitrum — the lualine theme: the accent for normal mode, a hue per other
--  mode, the palette's surfaces for the rest.
-- ===========================================================================

local M = {}

--- Build a lualine theme table from the currently loaded vitrum palette.
--- Call it again after :VitrumSync; lualine caches whatever it was given.
function M.build()
  local vitrum = require("vitrum")
  local p = vitrum.colors
  if not p then
    -- colors/vitrum.lua has not run yet — load so we never hand lualine nils.
    vitrum.load()
    p = vitrum.colors
  end

  local function mode(colour)
    return {
      a = { fg = p.on_accent, bg = colour, gui = "bold" },
      b = { fg = p.fg, bg = p.bg_high },
      c = { fg = p.fg_dim, bg = p.bg_elev },
    }
  end

  return {
    normal   = mode(p.accent),
    insert   = mode(p.green),
    visual   = mode(p.purple),
    replace  = mode(p.red),
    command  = mode(p.orange),
    terminal = mode(p.teal),
    inactive = {
      a = { fg = p.muted, bg = p.bg_alt },
      b = { fg = p.muted, bg = p.bg_alt },
      c = { fg = p.muted, bg = p.bg_alt },
    },
  }
end

return M
