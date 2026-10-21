# shellcheck shell=bash disable=SC1090,SC1091,SC2016,SC2034,SC2059,SC2329
# Translations (lib/i18n.sh): T follows the language picked on the first
# screen, L and the stage messages follow the device's locale.

# 0 while the stages still build their messages inline; 1 once every warn, err
# and die takes a literal template with its variable parts as arguments.
I18N_CHECK_STAGES=1

_i18n() {
  unset VITRUM_LANG VITRUM_MSG_LANG
  export VITRUM_DEVICE_LOCALE=en_US.UTF-8
  source "$VITRUM_DIR/lib/common.sh"
}

test_T_follows_the_chosen_language() {
  _i18n
  I18N_RU["Install"]="Установить"
  VITRUM_LANG=ru
  assert_eq "$(T Install)" "Установить"
  VITRUM_LANG=en
  assert_eq "$(T Install)" "Install"
}

test_args() {
  _i18n
  I18N_RU["%s free"]="свободно %s"
  VITRUM_LANG=ru
  assert_eq "$(T "%s free" 6000MB)" "свободно 6000MB"
  VITRUM_LANG=en
  assert_eq "$(T "%s free" 6000MB)" "6000MB free"
  # Without arguments a template is text, not a format.
  assert_eq "$(T "%s free")" "%s free"
  assert_eq "$(T "100% done")" "100% done"
}

test_missing_entry_falls_back_to_english() {
  _i18n
  VITRUM_LANG=ru
  assert_eq "$(T "no such entry %s" x)" "no such entry x"
}

test_L_follows_the_device_locale_only() {
  _i18n
  I18N_RU["Install"]="Установить"
  VITRUM_LANG=ru VITRUM_DEVICE_LOCALE=en_US.UTF-8
  assert_eq "$(L Install)" "Install"
  VITRUM_DEVICE_LOCALE=ru_RU.UTF-8
  assert_eq "$(L Install)" "Установить"
  VITRUM_LANG=en
  assert_eq "$(L Install)" "Установить"
  # An explicit VITRUM_MSG_LANG wins over the locale.
  VITRUM_MSG_LANG=en
  assert_eq "$(L Install)" "Install"
}

test_guess() {
  _i18n
  local loc want
  for loc in ru_RU.UTF-8:ru ru_UA:ru C:en "":en de_DE.UTF-8:en; do
    want="${loc##*:}"
    VITRUM_DEVICE_LOCALE="${loc%:*}"
    unset LC_ALL LC_MESSAGES LANG
    assert_eq "$(i18n_guess)/$(i18n_msg_lang)" "$want/$want" || { echo "for [${loc%:*}]"; return 1; }
  done
  # Without VITRUM_DEVICE_LOCALE it is read from the usual variables, with
  # LC_ALL first, as glibc does.
  unset VITRUM_DEVICE_LOCALE
  LANG=ru_RU.UTF-8
  assert_eq "$(i18n_guess)" ru
  LC_MESSAGES=en_US.UTF-8
  assert_eq "$(i18n_guess)" en
  LC_ALL=ru_RU.UTF-8
  assert_eq "$(i18n_guess)" ru
  # The screens default to the guess until a language is chosen.
  unset VITRUM_LANG
  assert_eq "$(i18n_lang)" ru
}

# common.sh replaces an ungenerated locale with a UTF-8 one that exists; the
# device's own choice must survive that, or a Russian machine whose ru_RU
# was never generated would get English messages.
test_device_locale_survives_the_utf8_fallback() {
  unset VITRUM_DEVICE_LOCALE VITRUM_MSG_LANG LC_ALL LC_CTYPE LC_MESSAGES
  export LANG=ru_RU.UTF-8
  printf() {
    if [[ "$1" == '\u2713' && "${LC_ALL:-}" != C.UTF-8 ]]; then builtin printf '%s' '\u2713'
    else builtin printf "$@"; fi
  }
  locale() { builtin printf 'C\nC.utf8\nPOSIX\n'; }
  source "$VITRUM_DIR/lib/common.sh"
  assert_eq "$LC_ALL" C.UTF-8
  assert_eq "$VITRUM_DEVICE_LOCALE" ru_RU.UTF-8
  assert_eq "$(i18n_msg_lang)" ru
}

test_warn_formats_and_records() {
  _i18n
  local out
  out="$(warn "only %sMB free in %s" 512 '$HOME' 2>&1)"
  assert_contains "$out" 'only 512MB free in $HOME'
  warn "only %sMB free in %s" 512 '$HOME' 2>/dev/null
  assert_eq "${VITRUM_WARNINGS[-1]}" 'only 512MB free in $HOME'
  # One argument is printed as it is, a % sign included.
  warn "50% of the disk" 2>/dev/null
  assert_eq "${VITRUM_WARNINGS[-1]}" "50% of the disk"
  err "could not install %s" /x 2>/dev/null
  assert_eq "${VITRUM_ERRORS[-1]}" "could not install /x"
  out="$( (die "missing source file: %s" /y) 2>&1)" && return 1
  assert_contains "$out" "missing source file: /y"
}

test_stage_messages_in_russian() {
  _i18n
  I18N_RU["could not install %s"]="не удалось установить %s"
  VITRUM_DEVICE_LOCALE=ru_RU.UTF-8
  warn "could not install %s" /x 2>/dev/null
  assert_eq "${VITRUM_WARNINGS[-1]}" "не удалось установить /x"
  VITRUM_DEVICE_LOCALE=en_US.UTF-8
  warn "could not install %s" /x 2>/dev/null
  assert_eq "${VITRUM_WARNINGS[-1]}" "could not install /x"
}

# _i18n_first_arg <text after the command> — the first argument's literal
# value in _ARG and the characters it took in _ARG_LEN; 1 when it is not a
# literal (it expands something). A double-quoted string is unescaped the way
# bash would.
_i18n_first_arg() {
  local s="$1" c i
  _ARG="" _ARG_LEN=0
  case "${s:0:1}" in
    "'")
      [[ "${s:1}" == *"'"* ]] || return 1
      _ARG="${s:1}"; _ARG="${_ARG%%\'*}"
      _ARG_LEN=$(( ${#_ARG} + 2 ))
      ;;
    '"')
      for (( i = 1; i < ${#s}; i++ )); do
        c="${s:i:1}"
        if [[ "$c" == "\\" ]]; then
          i=$((i + 1)); c="${s:i:1}"
          case "$c" in '"'|'$'|'`'|"\\") _ARG+="$c" ;; *) _ARG+="\\$c" ;; esac
        elif [[ "$c" == '"' ]]; then
          _ARG_LEN=$((i + 1)); return 0
        elif [[ "$c" == '$' || "$c" == '`' ]]; then
          return 1
        else
          _ARG+="$c"
        fi
      done
      return 1
      ;;
    '$'|'`'|"\\"|'') return 1 ;;
    *)
      _ARG="${s%%[[:space:];|&)]*}"
      [[ "$_ARG" == *'$'* ]] && return 1
      _ARG_LEN=${#_ARG}
      ;;
  esac
}

# _i18n_count_s <text> — how many %s it has.
_i18n_count_s() { local t="${1//%%/}" n=0; while [[ "$t" == *%s* ]]; do t="${t#*%s}"; n=$((n + 1)); done; printf '%s' "$n"; }

# _i18n_calls <names> <line> — the first argument of every call to one of
# <names> (a regex alternation) on the line, one per line, or a lone ! for
# one that is not a literal. Only a command position counts: the start of a
# line, or after an operator, a brace, a subshell or a keyword, so
# `_chk "x" warn "y"`, which passes warn as a word, is not a call.
_i18n_calls() {
  local re="(^|[;&|{(!)]|\\\$\\(|(^|[[:space:]])(then|else|do))[[:space:]]*($1)[[:space:]]+(.*)"
  local rest="$2"
  [[ "$rest" =~ ^[[:space:]]*# ]] && return 0
  while [[ "$rest" =~ $re ]]; do
    rest="${BASH_REMATCH[5]}"
    # The helpers hand their own arguments on; that is not a message.
    if [[ "$rest" == '"$@"'* ]]; then rest="${rest:4}"; continue; fi
    _i18n_first_arg "$rest" || { printf '!\n'; return 0; }
    printf '%s\n' "$_ARG"
    rest="${rest:_ARG_LEN}"
  done
}

test_every_template_has_russian() {
  _i18n
  local names='T|L'
  [[ "$I18N_CHECK_STAGES" == 1 ]] && names='T|L|warn|err|die'
  local f n line key val problems=()
  for f in "$VITRUM_DIR"/install.sh "$VITRUM_DIR"/lib/*.sh "$VITRUM_DIR"/lib/stages/*.sh "$VITRUM_DIR"/lib/backend/*.sh \
           "$VITRUM_DIR"/lib/screens/*.sh; do
    [[ -e "$f" ]] || continue
    n=0
    while IFS= read -r line || [[ -n "$line" ]]; do
      n=$((n + 1))
      while IFS= read -r key; do
        [[ -n "$key" ]] || continue
        if [[ "$key" == '!' ]]; then
          problems+=("${f#"$VITRUM_DIR"/}:$n: not a literal template: $line")
        elif [[ -z "${I18N_RU[$key]+x}" ]]; then
          problems+=("${f#"$VITRUM_DIR"/}:$n: no Russian for [$key]")
        else
          val="${I18N_RU[$key]}"
          [[ "$(_i18n_count_s "$key")" == "$(_i18n_count_s "$val")" ]] \
            || problems+=("${f#"$VITRUM_DIR"/}:$n: %s count differs: [$key] [$val]")
        fi
      done < <(_i18n_calls "$names" "$line")
    done < "$f"
  done
  # A template is a printf format with arguments and plain text without, so
  # the only directives either side may hold are %s and %%: anything else (a
  # %d, a bare % before a space) misprints in one of the two forms. A
  # backslash would be read as an escape by printf in one form and not the
  # other, so neither side has one.
  for key in "${!I18N_RU[@]}"; do
    for val in "$key" "${I18N_RU[$key]}"; do
      if [[ "${val//\%[s%]/}" == *%* ]]; then problems+=("a % other than %s or %% in [$val]")
      elif [[ "$val" == *\\* ]]; then problems+=("a backslash in [$val]")
      fi
    done
  done
  if (( ${#problems[@]} )); then printf '%s\n' "${problems[@]}"; return 1; fi
}

# The scanner itself, on lines it must and must not take for calls.
test_template_scanner() {
  _i18n_first_arg "'a \$HOME b' x"; assert_eq "$_ARG/$_ARG_LEN" 'a $HOME b/11'
  _i18n_first_arg '"say \"hi\" to \$HOME" x'; assert_eq "$_ARG/$_ARG_LEN" 'say "hi" to $HOME/22'
  _i18n_first_arg 'aborted; exit'; assert_eq "$_ARG/$_ARG_LEN" aborted/7
  ! _i18n_first_arg '"only ${free}MB"' || return 1
  ! _i18n_first_arg '"$(pkg_msg)"' || return 1
  assert_eq "$(_i18n_count_s 'a %s b %% c %s')" 2
  local w='warn|err|die'
  assert_eq "$(_i18n_calls "$w" '  cp a b || die "copy failed: %s" "$a"')" "copy failed: %s"
  assert_eq "$(_i18n_calls "$w" '  have x || { warn '"'"'x is missing; see %s'"'"' "$y"; return 0; }')" "x is missing; see %s"
  assert_eq "$(_i18n_calls "$w" '    *) die "unknown kind %s" "$k" ;;')" "unknown kind %s"
  assert_eq "$(_i18n_calls "$w" '  if a; then warn "one"; else err "two"; fi')" $'one\ntwo'
  assert_eq "$(_i18n_calls "$w" '  warn "only ${free_mb}MB free"')" '!'
  assert_eq "$(_i18n_calls "$w" '  printf "%s" "$(L "$@")"; warn "$@"')" ""
  assert_eq "$(_i18n_calls "$w" '  _chk "compositor" warn "built from other revisions"')" ""
  assert_eq "$(_i18n_calls "$w" '  # die "in a comment"')" ""
  assert_eq "$(_i18n_calls 'T|L' '  x="$(T "Install")"')" "Install"
}
