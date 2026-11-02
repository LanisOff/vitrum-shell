# shellcheck shell=bash
# ------------------------------------------------------------ components ----
#
# The optional parts, in the order the choice screen shows them. Recorded in
# $VITRUM_STATE/components.json so that an update repeats the choices made at
# install time instead of asking again, and so vitrum-theme knows which files
# it is allowed to write.
#
# Each entry is id|group|default|need|var: need is the lib/packages.tsv tag the
# part installs (- for none), var the variable the stages read.

COMPONENTS=(
  "sddm|desktop|1|sddm|WANT_SDDM"
  "plymouth|desktop|0|plymouth|WANT_PLYMOUTH"
  "live_wallpaper|desktop|1|live-wallpaper|WANT_LIVE_WALLPAPER"
  "phone|desktop|0|phone|WANT_PHONE"
  # fcitx5: it then holds every layout, and niri keeps one (tools/vitrum_theme/fcitx.py).
  "input_method|desktop|0|input-method|WANT_INPUT_METHOD"
  "tmux|tools|1|tmux|WANT_TMUX"
  "games|tools|1|games|WANT_GAMES"
  # steam-theme has no packages: vitrum-steam-theme installs Millennium (the
  # AUR's, or upstream's pinned release) where Steam has none.
  "steam_theme|tools|1|steam-theme|WANT_STEAM_THEME"
  # vesktop-theme neither: vitrum-vesktop-theme themes the Vesktop that is
  # there, and none is installed for it.
  "vesktop_theme|tools|1|vesktop-theme|WANT_VESKTOP_THEME"
  "utilities|tools|1|utilities|WANT_UTILITIES"
  "cli_tools|tools|1|cli-tools|WANT_CLI_TOOLS"
  "file_manager|tools|1|file-manager|WANT_FILE_MANAGER"
  "ocr|tools|1|ocr|WANT_OCR"
  "author_nvim|extras|0|nvim|WANT_NVIM"
  "author_tmux_keys|extras|0|-|WANT_AUTHOR_TMUX_KEYS"
  "tmux_autostart|extras|0|-|WANT_TMUX_AUTOSTART"
)

# A part that only makes sense with another one ticked.
# shellcheck disable=SC2034  # read by the choice screen
declare -gA COMPONENT_REQUIRES=([tmux_autostart]=tmux [author_tmux_keys]=tmux [steam_theme]=games)

# vesktop_present — 0 when there is a Vesktop for the vesktop_theme part to
# theme: the native one (on PATH, or its config from a run), or the Flatpak
# (dev.vencord.Vesktop, installed for the system or the user, or its data).
# The shell stage and the doctor go by it; vitrum-vesktop-theme finds the
# config folder of either.
vesktop_present() {
  local id=dev.vencord.Vesktop
  command -v vesktop >/dev/null 2>&1 || [[ -d "$XDG_CONFIG_HOME/vesktop" || -d "$HOME/.var/app/$id" ||
    -d "${VITRUM_SYSROOT:-}/var/lib/flatpak/app/$id" || -d "$XDG_DATA_HOME/flatpak/app/$id" ]]
}

# One-of choices: id|var|options, the first option being the default.
PICKS=(
  "terminal|VITRUM_TERMINAL|kitty"
  "shell|VITRUM_SHELL|fish"
  "fastfetch_logo|VITRUM_FASTFETCH_LOGO|picture distro"
  # How niri gets here, where there is a choice (pick_applies).
  "niri_source|VITRUM_NIRI_SOURCE|prebuilt compile"
)

# The prompt and the shell are part of the rice, not choices (read by the stages).
# shellcheck disable=SC2034
WANT_STARSHIP=1
# shellcheck disable=SC2034
WANT_FISH=1
WANT_TMUX_KEYS="${WANT_TMUX_KEYS:-}"      # vitrum (Ctrl+a…) or default (tmux's own), from author_tmux_keys
COMPONENTS_KNOWN="${COMPONENTS_KNOWN:-}"
VITRUM_LANG_STORED="${VITRUM_LANG_STORED:-}"
COMPONENTS_MIGRATED="${COMPONENTS_MIGRATED:-}"
# Set by components_load: the file is there but could not be read (no python3,
# or not JSON), and the parts the file had ticked, whatever the flags say now.
COMPONENTS_LOAD_FAILED="${COMPONENTS_LOAD_FAILED:-}"
COMPONENTS_STORED_ON="${COMPONENTS_STORED_ON:-}"
# The picks already decided, by the file or by a flag on this run: an update
# asks about one that is neither.
COMPONENTS_PICKS_DECIDED="${COMPONENTS_PICKS_DECIDED:-}"
# Set by install.sh once the choice screens were answered.
COMPONENTS_CHOSEN="${COMPONENTS_CHOSEN:-}"
# The confirmation's answer about fish as the login shell, as the file has it
# (1, 0, or empty for none), and whether the row was answered on this run
# (LOGIN_SHELL_ANSWERED=1, set by install.sh). Only an answer is stored.
COMPONENTS_LOGIN_SHELL="${COMPONENTS_LOGIN_SHELL:-}"
LOGIN_SHELL_ANSWERED="${LOGIN_SHELL_ANSWERED:-}"

# Empty means undecided: a flag, the stored file or the defaults fill it later.
# Values from the environment are kept, so a caller can still set them.
_components_init() {
  local entry id var opts
  for entry in "${COMPONENTS[@]}"; do
    var="${entry##*|}"
    printf -v "$var" '%s' "${!var:-}"
  done
  for entry in "${PICKS[@]}"; do
    IFS='|' read -r id var opts <<<"$entry"
    printf -v "$var" '%s' "${!var:-}"
  done
}
_components_init

components_file() { printf '%s\n' "$VITRUM_STATE/components.json"; }

component_ids() {
  local entry
  for entry in "${COMPONENTS[@]}"; do printf '%s\n' "${entry%%|*}"; done
}

# component_field <id> <group|default|need|var>
component_field() {
  local entry id group def need var
  for entry in "${COMPONENTS[@]}"; do
    IFS='|' read -r id group def need var <<<"$entry"
    [[ "$id" == "$1" ]] || continue
    case "$2" in
      group)   printf '%s\n' "$group" ;;
      default) printf '%s\n' "$def" ;;
      need)    printf '%s\n' "$need" ;;
      var)     printf '%s\n' "$var" ;;
      *) return 1 ;;
    esac
    return 0
  done
  return 1
}

# component_get <id> — 1 or 0. An undecided part reads as its default, as the
# stages always treated a missing choice.
component_get() {
  local var def
  var="$(component_field "$1" var)" || return 1
  def="$(component_field "$1" default)"
  printf '%s\n' "${!var:-$def}"
}

# component_active <id> — 0 when the part is on and so is what it needs: what
# the stages go by. Flags can say --no-games --with-steam-theme, and only the
# choice screen turns the second off for them.
component_active() {
  local req="${COMPONENT_REQUIRES[$1]:-}"
  [[ "$(component_get "$1")" == 1 ]] || return 1
  [[ -z "$req" ]] || component_active "$req"
}

# component_set <id> <0|1>
component_set() {
  local var
  [[ "$2" == 0 || "$2" == 1 ]] || return 1
  var="$(component_field "$1" var)" || return 1
  printf -v "$var" '%s' "$2"
  [[ "$1" == author_tmux_keys ]] && _components_tmux_keys
  return 0
}

# The stages and vitrum-theme still speak of the keys as vitrum or default.
_components_tmux_keys() {
  if [[ "${WANT_AUTHOR_TMUX_KEYS:-}" == 1 ]]; then WANT_TMUX_KEYS=vitrum; else WANT_TMUX_KEYS=default; fi
}

# niri_prebuilt_offered — 0 on Arch and its relatives on x86_64. The prebuilt
# niri is built on Arch against its current libraries, so it can run nowhere
# else; the other distributions compile and are not asked.
niri_prebuilt_offered() { [[ "${PKG_BACKEND:-}" == pacman && "$(uname -m)" == x86_64 ]]; }

# niri_prebuilt_wanted — 0 when this run goes for the prebuilt niri. What
# compiling needs stays out of the packages then, and the time and disk space
# it would take are not counted.
niri_prebuilt_wanted() { [[ "${VITRUM_NIRI_SOURCE:-}" == prebuilt ]] && niri_prebuilt_offered; }

# pick_applies <pick> — 0 when the pick means anything on this system.
pick_applies() { [[ "$1" != niri_source ]] || niri_prebuilt_offered; }

# _pick_var <id> / _pick_options <id>
_pick_var() {
  local entry id var opts
  for entry in "${PICKS[@]}"; do
    IFS='|' read -r id var opts <<<"$entry"
    [[ "$id" == "$1" ]] && { printf '%s\n' "$var"; return 0; }
  done
  return 1
}
_pick_options() {
  local entry id var opts
  for entry in "${PICKS[@]}"; do
    IFS='|' read -r id var opts <<<"$entry"
    [[ "$id" == "$1" ]] && { printf '%s\n' "$opts"; return 0; }
  done
  return 1
}

# components_flag <flag> — 0 when it was a component flag (and is now set).
# Every part has --with-<id> and --no-<id> (dashes for underscores); the
# flags older installers took keep their meaning.
components_flag() {
  local flag="$1" id
  case "$flag" in
    --with-extras)       component_set games 1; component_set utilities 1; return 0 ;;
    --no-extras)         component_set games 0; component_set utilities 0; return 0 ;;
    --with-nvim)         component_set author_nvim 1; return 0 ;;
    --no-nvim)           component_set author_nvim 0; return 0 ;;
    --tmux-keys=vitrum)  component_set author_tmux_keys 1; return 0 ;;
    --tmux-keys=default) component_set author_tmux_keys 0; return 0 ;;
    --tmux-autostart)    component_set tmux_autostart 1; return 0 ;;
    --with-prebuilt-niri) VITRUM_NIRI_SOURCE=prebuilt COMPONENTS_PICKS_DECIDED+=" niri_source"; return 0 ;;
    --no-prebuilt-niri)   VITRUM_NIRI_SOURCE=compile COMPONENTS_PICKS_DECIDED+=" niri_source"; return 0 ;;
  esac
  [[ "$flag" == --with-input-method || "$flag" == --no-input-method ]] && COMPONENT_FLAGGED_INPUT_METHOD=1
  for id in $(component_ids); do
    case "$flag" in
      "--with-${id//_/-}") component_set "$id" 1; return 0 ;;
      "--no-${id//_/-}")   component_set "$id" 0; return 0 ;;
    esac
  done
  return 1
}

# components_load — the stored choices, into the variables still empty (a flag
# given on this run wins). 1 when there is nothing to load. A file without a
# version is the one older installers wrote; it is read the way they meant it.
# A file that is there and cannot be read sets COMPONENTS_LOAD_FAILED, so it is
# not overwritten with defaults (components_save).
components_load() {
  local f; f="$(components_file)"
  COMPONENTS_LOAD_FAILED="" COMPONENTS_STORED_ON="" COMPONENTS_LOGIN_SHELL=""
  [[ -f "$f" ]] || return 1
  have python3 || { COMPONENTS_LOAD_FAILED=1; return 1; }
  local ids picks
  ids="$(component_ids | tr '\n' ' ')"
  picks="$(printf '%s\n' "${PICKS[@]}" | cut -d'|' -f1 | tr '\n' ' ')"
  local out
  out="$(python3 - "$f" "$ids" "$picks" <<'PY' 2>/dev/null
import json, re, sys
try:
    d = json.load(open(sys.argv[1], encoding="utf-8"))
except Exception:
    raise SystemExit(1)
if not isinstance(d, dict):
    raise SystemExit(1)
ids, picks = sys.argv[2].split(), sys.argv[3].split()
word = re.compile(r"^[A-Za-z0-9_.-]+$")
if "version" not in d:
    # v1: one flat file, the extras as one part, the author's setup by other names.
    v = {k: bool(d.get(k)) for k in ("tmux", "sddm", "plymouth", "live_wallpaper", "phone", "tmux_autostart")}
    v["author_nvim"] = bool(d.get("nvim"))
    v["author_tmux_keys"] = d.get("tmux_keys") == "vitrum"
    v["games"] = v["utilities"] = bool(d.get("extras"))
    # These were always installed; ticking them keeps what is there.
    v["cli_tools"] = v["file_manager"] = v["ocr"] = True
    print("MIGRATED=1")
    # The Steam and Vesktop themes came later and change those apps
    # themselves, the input method takes the layouts over: offered, not assumed.
    print("KNOWN=" + " ".join(i for i in ids if i not in ("steam_theme", "vesktop_theme", "input_method")))
else:
    v = {k: bool(d[k]) for k in ids if k in d}
    known = d.get("known")
    if not isinstance(known, list):
        known = list(v)
    print("KNOWN=" + " ".join(k for k in known if isinstance(k, str) and k in ids))
    lang = d.get("language")
    if isinstance(lang, str) and word.match(lang):
        print("LANG=" + lang)
    for p in picks:
        if isinstance(d.get(p), str) and word.match(d[p]):
            print("pick:%s=%s" % (p, d[p]))
    if isinstance(d.get("login_shell"), bool):
        print("LOGIN_SHELL=%d" % (1 if d["login_shell"] else 0))
for k in ids:
    if k in v:
        print("%s=%d" % (k, 1 if v[k] else 0))
PY
)" || { COMPONENTS_LOAD_FAILED=1; return 1; }
  [[ -n "$out" ]] || { COMPONENTS_LOAD_FAILED=1; return 1; }
  local line key val var
  COMPONENTS_MIGRATED=""
  while IFS= read -r line; do
    key="${line%%=*}" val="${line#*=}"
    case "$key" in
      MIGRATED) COMPONENTS_MIGRATED=1 ;;
      KNOWN)    COMPONENTS_KNOWN="$val" ;;
      LANG)     VITRUM_LANG_STORED="$val" ;;
      # The confirmation's "make fish my login shell", as answered last time.
      # It is not this run's answer: install.sh decides what it means now.
      LOGIN_SHELL) COMPONENTS_LOGIN_SHELL="$val" ;;
      pick:*)
        var="$(_pick_var "${key#pick:}")" || continue
        # A value this version does not offer (a newer one wrote it) is left to the default.
        [[ " $(_pick_options "${key#pick:}") " == *" $val "* ]] || continue
        COMPONENTS_PICKS_DECIDED+=" ${key#pick:}"
        [[ -z "${!var:-}" ]] && printf -v "$var" '%s' "$val"
        ;;
      *)
        var="$(component_field "$key" var)" || continue
        [[ "$val" == 1 ]] && COMPONENTS_STORED_ON+="${COMPONENTS_STORED_ON:+ }$key"
        [[ -z "${!var:-}" ]] && printf -v "$var" '%s' "$val"
        ;;
    esac
  done <<<"$out"
  _components_tmux_keys
  return 0
}

# components_defaults — every variable still undecided takes its default.
components_defaults() {
  local entry id group def need var opts
  for entry in "${COMPONENTS[@]}"; do
    IFS='|' read -r id group def need var <<<"$entry"
    [[ -z "${!var:-}" ]] && printf -v "$var" '%s' "$def"
  done
  for entry in "${PICKS[@]}"; do
    IFS='|' read -r id var opts <<<"$entry"
    [[ -z "${!var:-}" ]] && printf -v "$var" '%s' "${opts%% *}"
  done
  _components_tmux_keys
  return 0
}

# A string for the JSON below: the picks are plain words, the language comes
# from the environment and is escaped to be safe.
_components_json_str() {
  local s="${1//\\/\\\\}"
  printf '"%s"' "${s//\"/\\\"}"
}

# components_save — the choices as components.json v2. Plain bash, so it works
# before python3 is installed. login_shell is the confirmation's answer about
# fish as the login shell (not a part), written only when the row was answered
# on this run, else as the file had it, else not at all: a default taken
# without asking (--yes, a row not shown because fish already was the login
# shell) is no answer. niri_source is written only where it applies. tmux_keys
# and extras are kept for vitrum-theme copies older than this file. The
# language is the one chosen on this run, or else the stored one: an update
# that asks nothing must not forget it.
#
# A file that could not be read is left alone unless the choice screens were
# answered on this run: otherwise this run's choices are only the defaults,
# and writing them would lose the ones in the file for good.
components_save() {
  if [[ "$DRY_RUN" == "1" ]]; then dim "would record component choices"; return 0; fi
  if [[ "${COMPONENTS_LOAD_FAILED:-}" == 1 && "${COMPONENTS_CHOSEN:-}" != 1 ]]; then
    warn 'could not read %s — it is left as it is, and this run uses the defaults' "$(components_file)"
    return 0
  fi
  mkdir -p "$VITRUM_STATE"
  local id known="" bools="" extras=false keys=default
  for id in $(component_ids); do
    known+="${known:+, }\"$id\""
    bools+="  \"$id\": $([[ "$(component_get "$id")" == 1 ]] && echo true || echo false),"$'\n'
  done
  [[ "$(component_get games)" == 1 || "$(component_get utilities)" == 1 ]] && extras=true
  [[ "$(component_get author_tmux_keys)" == 1 ]] && keys=vitrum
  local login="${COMPONENTS_LOGIN_SHELL:-}" login_line=""
  [[ "${LOGIN_SHELL_ANSWERED:-}" == 1 ]] && login="${WANT_LOGIN_SHELL:-0}"
  case "$login" in
    1) login_line='  "login_shell": true,'$'\n' ;;
    0) login_line='  "login_shell": false,'$'\n' ;;
  esac
  local niri_line=""
  pick_applies niri_source && niri_line="  \"niri_source\": $(_components_json_str "${VITRUM_NIRI_SOURCE:-}"),"$'\n'
  cat > "$(components_file)" <<EOF
{
  "version": 2,
  "language": $(_components_json_str "${VITRUM_LANG:-${VITRUM_LANG_STORED:-}}"),
  "terminal": $(_components_json_str "${VITRUM_TERMINAL:-}"),
  "shell": $(_components_json_str "${VITRUM_SHELL:-}"),
  "fastfetch_logo": $(_components_json_str "${VITRUM_FASTFETCH_LOGO:-}"),
${niri_line}${login_line}  "known": [$known],
${bools}  "tmux_keys": "$keys",
  "extras": $extras
}
EOF
}

# components_vars — every variable the choices live in, the parts' and the
# picks', one per line: what install.sh puts back when the update's short
# list is left with Esc.
components_vars() {
  local entry id var opts
  for entry in "${COMPONENTS[@]}"; do printf '%s\n' "${entry##*|}"; done
  for entry in "${PICKS[@]}"; do
    IFS='|' read -r id var opts <<<"$entry"
    printf '%s\n' "$var"
  done
}

# components_new — the parts the stored file did not know of, one per line:
# what a newer version added since the choices were made. niri_source is asked
# the same way, once, on the systems it applies to.
components_new() {
  local id
  for id in $(component_ids); do
    [[ " $COMPONENTS_KNOWN " == *" $id "* ]] || printf '%s\n' "$id"
  done
  if pick_applies niri_source && [[ " $COMPONENTS_PICKS_DECIDED " != *" niri_source "* ]]; then
    printf 'niri_source\n'
  fi
  return 0
}

# components_unticked — the known parts that are off, one per line.
components_unticked() {
  local id
  for id in $(component_ids); do
    [[ " $COMPONENTS_KNOWN " == *" $id "* && "$(component_get "$id")" == 0 ]] && printf '%s\n' "$id"
  done
  return 0
}

# Russian OCR data follows the language the stage messages use, which follows
# the device's locale (a ru_* one, generated or not; see lib/i18n.sh).
_components_ru() { [[ "$(i18n_msg_lang)" == ru ]]; }

# cjk_layouts_set — 0 when the keyboard layouts name Japanese, Korean or Chinese:
# Settings' list, or else what niri's config says. Those type nothing but Latin
# without the input method.
cjk_layouts_set() {
  local settings="$XDG_CONFIG_HOME/vitrum/settings.json" f
  if [[ -f "$settings" ]] && grep -qE '"(jp|kr|cn)"' "$settings"; then return 0; fi
  for f in "$VITRUM_PREFIX/niri/generated/input.kdl" "$VITRUM_PREFIX/niri/config.kdl"; do
    [[ -f "$f" ]] && grep -qE '^[[:space:]]*layout[[:space:]]+"([^"]*,)?(jp|kr|cn)(,[^"]*)?"' "$f" && return 0
  done
  return 1
}

# components_suggest — tick the input method on the screen for someone whose
# layouts need it and who has not decided. Only there: it stays off by default,
# so an update without a terminal never turns it on by itself.
components_suggest() {
  [[ " $COMPONENTS_KNOWN " == *" input_method "* || "${COMPONENT_FLAGGED_INPUT_METHOD:-}" == 1 ]] && return 0
  if cjk_layouts_set; then component_set input_method 1; fi
  return 0
}

# components_needs — the groups of lib/packages.tsv this run needs, one per
# line. Shared by the packages stage and the start-of-run check.
components_needs() {
  local needs=(required) id need
  niri_prebuilt_wanted || needs+=(niri-build)
  if lspci 2>/dev/null | grep -qiE '(VGA|3D).*NVIDIA'; then needs+=(nvidia); fi
  for id in $(component_ids); do
    component_active "$id" || continue
    need="$(component_field "$id" need)"
    [[ "$need" == - ]] || needs+=("$need")
  done
  if [[ "$(component_get ocr)" == 1 ]] && _components_ru; then needs+=(ocr-ru); fi
  printf '%s\n' "${needs[@]}"
}
