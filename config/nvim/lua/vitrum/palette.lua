-- ===========================================================================
--  vitrum — the palette
-- ===========================================================================
--
--  vitrum-theme renders the desktop's palette (the wallpaper's colours or a
--  preset, light or dark) into ~/.local/share/vitrum/nvim.json whenever it
--  changes; this reads it. The table below is the graphite preset, used until
--  that file exists. Do not edit by hand — it comes from the same renderer.
-- ===========================================================================

local M = {}

M.fallback = {
  dark = {
    bg = "#0e0f11",
    bg_dim = "#0a0b0d",
    bg_alt = "#1b1d21",
    bg_elev = "#24272c",
    bg_high = "#2e3238",
    sel = "#394962",
    line = "#3c4148",
    muted = "#515459",
    subtle = "#858a91",
    fg_dim = "#a3a9b1",
    fg = "#e6e8eb",
    fg2 = "#cbcfd4",
    fg_hi = "#ffffff",
    accent = "#8ab4f8",
    on_accent = "#0b1f3f",
    pill = "#24272c",
    pill_alt = "#2e3238",
    red = "#ef6f6c",
    orange = "#f0965a",
    yellow = "#e8c766",
    green = "#8fcf86",
    mint = "#7dd6c2",
    teal = "#5fc1d0",
    blue = "#6fa8f0",
    indigo = "#8f8cf2",
    purple = "#c38df0",
    pink = "#f08ab6",
    brown = "#c4a07a",
    graphite = "#9aa0a8",
    syn = {
      keyword = "#c38df0",
      string = "#8fcf86",
      number = "#f0965a",
      comment = "#858a91",
      doc = "#858a91",
      doc_keyword = "#a3a9b1",
      type = "#5fc1d0",
      class = "#7dd6c2",
      func = "#6fa8f0",
      func_other = "#8f8cf2",
      const = "#f0965a",
      const_other = "#e8c766",
      property = "#5fc1d0",
      property_other = "#e6e8eb",
      preproc = "#f08ab6",
      attribute = "#c4a07a",
      url = "#8ab4f8",
      mark = "#ffffff",
    },
  },
  light = {
    bg = "#f4f5f7",
    bg_dim = "#f7f8f9",
    bg_alt = "#ffffff",
    bg_elev = "#eef0f3",
    bg_high = "#e3e6ea",
    sel = "#a8c8f2",
    line = "#c9ced5",
    muted = "#afb2b8",
    subtle = "#7a7f86",
    fg_dim = "#5b616a",
    fg = "#1b1d21",
    fg2 = "#35383e",
    fg_hi = "#000000",
    accent = "#1a73e8",
    on_accent = "#ffffff",
    pill = "#eef0f3",
    pill_alt = "#e3e6ea",
    red = "#c8423e",
    orange = "#b8621f",
    yellow = "#8f6d00",
    green = "#2f7d32",
    mint = "#00796b",
    teal = "#00788a",
    blue = "#2a62c9",
    indigo = "#4a47c2",
    purple = "#8442b8",
    pink = "#b83776",
    brown = "#7d5a35",
    graphite = "#6b7078",
    syn = {
      keyword = "#8442b8",
      string = "#2f7d32",
      number = "#b8621f",
      comment = "#7a7f86",
      doc = "#7a7f86",
      doc_keyword = "#5b616a",
      type = "#00788a",
      class = "#00796b",
      func = "#2a62c9",
      func_other = "#4a47c2",
      const = "#b8621f",
      const_other = "#8f6d00",
      property = "#00788a",
      property_other = "#1b1d21",
      preproc = "#b83776",
      attribute = "#7d5a35",
      url = "#1a73e8",
      mark = "#000000",
    },
  },
}

function M.path()
  local base = vim.env.XDG_DATA_HOME
  if base == nil or base == "" then base = vim.env.HOME .. "/.local/share" end
  return base .. "/vitrum/nvim.json"
end

--- The current palette and scheme ("dark" or "light").
function M.current()
  local ok, data = pcall(function()
    local f = io.open(M.path(), "r")
    if not f then return nil end
    local text = f:read("*a")
    f:close()
    return vim.json.decode(text)
  end)
  if ok and type(data) == "table" and type(data.p) == "table" then
    local mode = data.background == "light" and "light" or "dark"
    return vim.deepcopy(data.p), mode
  end
  return vim.deepcopy(M.fallback.dark), "dark"
end

return M
