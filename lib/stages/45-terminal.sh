#!/usr/bin/env bash
# Stage: terminal — kitty, fish, Starship, tmux, Neovim, fastfetch, GTK colours.
#
# Everything is rendered by vitrum-theme from the desktop's palette: the
# templates in config/ are installed next to it, and the first run (--all)
# also writes the base configs (backed up first). From then on every palette
# or light/dark change re-renders only the colour files, and running kitty
# and tmux pick them up.

TERM_TEMPLATES="$VITRUM_STATE/templates"

stage_terminal() {
  stage "Terminal"
  _terminal_templates
  _terminal_legacy
  _terminal_logo
  _terminal_render
  _terminal_fish
  _terminal_fastfetch
  if [[ "$WANT_TMUX" == "1" ]]; then _terminal_tmux; else dim "tmux: not selected"; fi
  if [[ "$WANT_NVIM" == "1" ]]; then _terminal_nvim; else dim "neovim: not selected"; fi
  stage_done
}

# ------------------------------------------------------------- templates ----

_terminal_templates() {
  step "installing templates"
  local sub
  for sub in kitty fish starship tmux fastfetch gtk-3.0 gtk-4.0 MangoHud; do
    [[ -d "$VITRUM_DIR/config/$sub" ]] && install_tree "$VITRUM_DIR/config/$sub" "$TERM_TEMPLATES/$sub"
  done
}

# niri-tahoe's renderer and its commands; vitrum-theme does all of it now.
_terminal_legacy() {
  local f
  for f in "$HOME"/.local/bin/niri-tahoe-{theme-sync,palette,logo,report} \
           "$VITRUM_STATE/theme-sync.py" "$VITRUM_STATE/palette.py"; do
    [[ -e "$f" ]] || continue
    backup_path "$f"
    run rm -f "$f"
  done
}

# fastfetch shows the vitrum mark.
_terminal_logo() {
  [[ "$DRY_RUN" == "1" ]] && return 0
  local out="$VITRUM_STATE/fastfetch/logo.png"
  mkdir -p "$(dirname "$out")"
  if have rsvg-convert; then rsvg-convert -w 256 -h 256 "$VITRUM_DIR/assets/vitrum-mark.svg" -o "$out" 2>/dev/null
  elif have magick; then magick -background none -density 300 "$VITRUM_DIR/assets/vitrum-mark.svg" -resize 256x256 "$out" 2>/dev/null
  fi
  [[ -s "$out" ]] || dim "no logo for fastfetch (no rsvg-convert/ImageMagick) — it falls back to text"
}

# Every file the render writes, base or colours: backed up once, then written.
_terminal_render() {
  step "rendering the terminal theme"
  local dest
  for dest in kitty/kitty.conf kitty/vitrum-colors.conf fish/config.fish fish/conf.d/00-vitrum-colors.fish \
              fish/conf.d/10-vitrum-abbr.fish fish/functions/fish_greeting.fish starship.toml \
              tmux/tmux.conf tmux/keys.conf tmux/vitrum.conf tmux/tmux-nerd-font-window-name.yml fastfetch/config.jsonc \
              gtk-3.0/gtk.css gtk-3.0/vitrum.css gtk-4.0/gtk.css gtk-4.0/vitrum.css Kvantum/vitrum kdeglobals; do
    backup_path "$XDG_CONFIG_HOME/$dest"
  done
  if [[ "$DRY_RUN" == "1" ]]; then dim "would run vitrum-theme --all"; return 0; fi
  local tool="$HOME/.local/bin/vitrum-theme"
  [[ -x "$tool" ]] || tool="vitrum-theme"
  "$tool" --all --quiet --templates "$TERM_TEMPLATES" || warn "vitrum-theme failed — run it again by hand to see why"
  # Base configs you edited are kept; a newer vitrum version waits beside them.
  local newer
  newer="$(cd "$XDG_CONFIG_HOME" 2>/dev/null && find . -maxdepth 3 -name '*.vitrum-new' 2>/dev/null | sed 's|^\./||' | sort || true)"
  if [[ -n "$newer" ]]; then
    info "kept your edited configs; the newer vitrum versions are beside them:"
    while IFS= read -r f; do dim "  ~/.config/$f"; done <<<"$newer"
  fi
}

_terminal_fastfetch() {
  step "fastfetch"
  have fastfetch || { warn "fastfetch is missing — ./install.sh --only packages installs it"; return 0; }
}

# ------------------------------------------------------------------ fish ----

_terminal_fish() {
  step "fish"
  have fish || { warn "fish is missing — ./install.sh --only packages installs it"; return 0; }

  # Abbreviations are a plain copy: no colours in them, nothing to render.

  # The one file this project promises never to touch again.
  local local_conf="$XDG_CONFIG_HOME/fish/conf.d/99-local.fish"
  if [[ ! -f "$local_conf" ]]; then
    write_file "$local_conf" <<'EOF'
# Yours. The installer creates this once and never writes it again — put
# personal abbreviations, exports and functions here so an update cannot
# take them away.
EOF
  else
    dim "keeping your 99-local.fish"
  fi

  # tmux autostart is a marker file rather than a config edit, so turning it
  # off later is `rm`, and config.fish stays byte-identical either way.
  local marker="$VITRUM_PREFIX/tmux-autostart"
  if [[ "$WANT_TMUX" == "1" && "$WANT_TMUX_AUTOSTART" == "1" ]]; then
    if [[ "$DRY_RUN" == "1" ]]; then
      dim "would enable tmux autostart"
    else
      mkdir -p "$VITRUM_PREFIX"
      : > "$marker"
      ok "tmux starts with every interactive fish"
    fi
  else
    [[ "$DRY_RUN" == "1" ]] || rm -f "$marker"
  fi

  if [[ "${WANT_FISH:-1}" == "1" ]]; then _terminal_default_shell; else dim "login shell: left as it is (--no-fish)"; fi
}

# Offer to make fish the login shell. Never silently: changing someone's login
# shell without asking is the kind of thing that ends a session badly.
_terminal_default_shell() {
  local fish_path
  fish_path="$(command -v fish 2>/dev/null || true)"
  [[ -n "$fish_path" ]] || return 0

  local current="${SHELL:-}"
  [[ "$current" == "$fish_path" ]] && { ok "fish is already your login shell"; return 0; }

  if [[ "$DRY_RUN" == "1" ]]; then dim "would offer to set fish as the login shell"; return 0; fi

  if confirm "make fish your login shell? (currently ${current:-unknown})" y; then
    grep -qxF "$fish_path" /etc/shells 2>/dev/null \
      || printf '%s\n' "$fish_path" | sudo tee -a /etc/shells >/dev/null

    # Through sudo rather than bare chsh, and with nothing suppressed.
    #
    # chsh authenticates through PAM and asks for your password on stderr. Send
    # that to /dev/null and the prompt vanishes while chsh goes on waiting for
    # an answer — which reads as the installer having hung. The preflight stage
    # already holds a warm sudo timestamp, so this route asks for nothing.
    local user="${USER:-$(id -un)}"
    step "setting the login shell (no password needed, sudo is already warm)"
    if run_ok sudo chsh -s "$fish_path" "$user"; then
      ok "login shell set to fish (takes effect next login)"
    elif run_ok chsh -s "$fish_path"; then
      ok "login shell set to fish (takes effect next login)"
    else
      warn "could not change the login shell"
      info "do it later with: chsh -s $fish_path"
    fi
  else
    info "left as $current — kitty is configured to launch fish regardless"
  fi
}

# ------------------------------------------------------------------ tmux ----

_terminal_tmux() {
  step "tmux"
  have tmux || { warn "tmux is missing — ./install.sh --only packages installs it"; return 0; }

  # The status scripts are plain files; only the two configs are rendered.
  install_file "$VITRUM_DIR/config/tmux/scripts/git.sh"     "$XDG_CONFIG_HOME/tmux/scripts/git.sh"     0755
  install_file "$VITRUM_DIR/config/tmux/scripts/battery.sh" "$XDG_CONFIG_HOME/tmux/scripts/battery.sh" 0755

  # tmux still reads ~/.tmux.conf on some setups and people's muscle memory
  # points there; make it a one-line redirect rather than a second copy.
  if [[ -e "$HOME/.tmux.conf" && ! -L "$HOME/.tmux.conf" ]]; then
    backup_path "$HOME/.tmux.conf"
  fi
  write_file "$HOME/.tmux.conf" <<'EOF'
# The real configuration lives in ~/.config/tmux/tmux.conf, which is where
# tmux 3.1+ looks first. This file exists so older habits still work.
source-file ~/.config/tmux/tmux.conf
EOF

  _terminal_tpm
}

_terminal_tpm() {
  local tpm="$HOME/.tmux/plugins/tpm"
  if [[ -d "$tpm/.git" ]]; then
    step "updating tpm"
    run_ok git -C "$tpm" pull --ff-only --quiet || warn "could not update tpm"
  else
    step "cloning tpm"
    run_ok git clone --depth 1 --quiet https://github.com/tmux-plugins/tpm "$tpm" \
      || { warn "could not clone tpm (offline?) — tmux works without plugins; re-run --only terminal later"; return 0; }
  fi

  if [[ "$DRY_RUN" == "1" ]]; then dim "would install tmux plugins"; return 0; fi

  # install_plugins wants a server to talk to. Start a throwaway one on its own
  # socket so this never disturbs a session the user is sitting in.
  step "installing tmux plugins (this clones a dozen repositories)"
  local sock="vitrum-install"
  tmux -L "$sock" -f "$XDG_CONFIG_HOME/tmux/tmux.conf" \
       new-session -d -s setup 'sleep 300' >/dev/null 2>&1 || true
  if tmux -L "$sock" has-session >/dev/null 2>&1; then
    "$tpm/bin/install_plugins" >/dev/null 2>&1 || warn "some tmux plugins did not install"
    tmux -L "$sock" kill-server >/dev/null 2>&1 || true
    ok "tmux plugins installed"
  else
    warn "could not start a temporary tmux; press prefix + I inside tmux to install plugins"
  fi
}

# ---------------------------------------------------------------- neovim ----

_terminal_nvim() {
  step "neovim"
  have nvim || { warn "nvim is missing — ./install.sh --only packages installs it"; return 0; }

  # lua/plugins/local/ is yours: lazy imports it, the installer never deletes
  # it, so a personal plugin survives every update.
  install_tree_keep "$VITRUM_DIR/config/nvim" "$XDG_CONFIG_HOME/nvim" \
      "lua/plugins/local/" "lazy-lock.json"

  local localdir="$XDG_CONFIG_HOME/nvim/lua/plugins/local"
  if [[ ! -f "$localdir/init.lua" ]]; then
    write_file "$localdir/init.lua" <<'EOF'
-- Yours. lazy.nvim imports this directory and the installer never overwrites
-- it, so anything you add here survives an update.
--
--   return {
--     { "folke/zen-mode.nvim", cmd = "ZenMode" },
--   }
return {}
EOF
  else
    dim "keeping your lua/plugins/local"
  fi

  if [[ "$DRY_RUN" == "1" ]]; then dim "would bootstrap lazy.nvim"; return 0; fi

  step "syncing plugins (headless, a minute or two)"
  # Errors here are not fatal: a missing treesitter parser or a network hiccup
  # should not fail the whole desktop install, and :Lazy sync fixes it later.
  if [[ "$DRY_RUN" == "1" ]]; then
    dim "would run: nvim --headless +Lazy! sync"
  elif nvim --headless "+Lazy! sync" +qa >/dev/null 2>&1; then
    ok "neovim plugins installed"
  else
    warn "nvim --headless '+Lazy! sync' did not finish cleanly; run :Lazy sync in Neovim"
  fi
}
