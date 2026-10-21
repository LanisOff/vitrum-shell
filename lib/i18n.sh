# shellcheck shell=bash
# ----------------------------------------------------------------- i18n -----
#
# Two languages, and two audiences for them. The screens speak the language
# picked on the first screen (VITRUM_LANG, through T). The stages' own messages
# (warn, err, die, through L) speak the device's language: they end up in logs
# and bug reports, and someone who chose Russian on a machine set to English
# should still get messages that match what the rest of the system prints.
#
# A template is the English text itself, with %s for every part that varies;
# lib/i18n/ru.sh maps it to the Russian one. A template with no entry there is
# shown in English, so a missing translation never hides a message.

[[ -n "${_VITRUM_I18N_LOADED:-}" ]] && return 0
_VITRUM_I18N_LOADED=1

declare -gA I18N_RU=()
# shellcheck source=lib/i18n/ru.sh
source "$VITRUM_DIR/lib/i18n/ru.sh"

# The device's locale as the user set it. install.sh records it in
# VITRUM_DEVICE_LOCALE before common.sh can swap an ungenerated locale for one
# that exists; without that, the usual variables are read the way glibc does,
# LC_ALL first.
i18n_device_locale() {
  printf '%s\n' "${VITRUM_DEVICE_LOCALE:-${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}}"
}

# i18n_guess — ru for a Russian device (ru_RU, ru_UA…, generated or not), en
# for everything else, C and an unset locale included.
i18n_guess() {
  if [[ "$(i18n_device_locale)" == ru_* ]]; then printf 'ru\n'; else printf 'en\n'; fi
}

# i18n_lang — the screens' language: the one chosen, or the guess until then.
i18n_lang() {
  case "${VITRUM_LANG:-}" in
    en|ru) printf '%s\n' "$VITRUM_LANG" ;;
    *)     i18n_guess ;;
  esac
}

# i18n_msg_lang — the stage messages' language. VITRUM_MSG_LANG overrides it
# when set; otherwise it is read from the device's locale on every call, so a
# caller that changes VITRUM_DEVICE_LOCALE is followed at once.
i18n_msg_lang() {
  case "${VITRUM_MSG_LANG:-}" in
    en|ru) printf '%s\n' "$VITRUM_MSG_LANG" ;;
    *)     i18n_guess ;;
  esac
}

# _i18n_say <lang> <template> [args...] — the template in that language,
# formatted with the arguments. With none it is printed as it stands, so a
# message that happens to contain a % sign comes out whole.
_i18n_say() {
  local lang="$1" tpl="${2:-}"
  shift 2 || shift $#
  if [[ "$lang" == ru && -n "$tpl" && -n "${I18N_RU[$tpl]+x}" ]]; then
    tpl="${I18N_RU[$tpl]}"
  fi
  if (( $# )); then
    # shellcheck disable=SC2059  # the template is the format, by design
    printf -- "$tpl" "$@"
  else
    printf '%s' "$tpl"
  fi
}

# T <template> [args...] — a string on a screen, in the language chosen there.
T() { _i18n_say "$(i18n_lang)" "$@"; }

# L <template> [args...] — a stage message, in the device's language.
L() { _i18n_say "$(i18n_msg_lang)" "$@"; }
