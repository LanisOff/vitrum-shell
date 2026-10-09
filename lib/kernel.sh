# shellcheck shell=bash
# The kernel options a vitrum desktop leans on, and which of them this kernel
# lacks. A distribution kernel has them all; a hand-built one can miss any —
# each was a separate surprise on one install (no picture, no Wi-Fi, a VPN
# that would not start, no sound). Used by the doctor stage.

# option(s)|what it is for. "A B" means any one of them will do; y and m both count.
KERNEL_WANTS=(
  "DRM_SIMPLEDRM FB_EFI|a picture before the GPU driver loads (boot splash, console)"
  "FRAMEBUFFER_CONSOLE|text on screen while booting"
  "SND_HDA_GENERIC SND_HDA_CODEC_REALTEK|sound from the onboard codec"
  "SND_USB_AUDIO|USB microphones, headsets and DACs"
  "TUN|VPN clients (Throne, OpenVPN)"
  "NF_TABLES|VPN auto-routing and firewalls"
  "NF_CONNTRACK_MARK|VPN rules that mark connections"
  "WIREGUARD|WireGuard"
  "BT|Bluetooth"
  "CFG80211|Wi-Fi"
  "FUSE_FS|AppImages, ntfs-3g, sshfs"
  "NTFS3_FS|Windows (NTFS) disks"
  "EXFAT_FS|exFAT USB sticks and SD cards"
  "INPUT_UINPUT|game controllers through Steam, KDE Connect's remote input"
  "SENSORS_K10TEMP SENSORS_CORETEMP|CPU temperature in the bar"
  "USB_VIDEO_CLASS|webcams"
)

# kernel_config — the running kernel's config on stdout, from wherever it is
# kept; nothing (status 1) when it cannot be found.
kernel_config() {
  local r="${VITRUM_ROOTFS:-}" v; v="$(uname -r)"
  if [[ -r "$r/proc/config.gz" ]]; then zcat "$r/proc/config.gz"; return; fi
  local f
  for f in "$r/boot/config-$v" "$r/lib/modules/$v/build/.config" "$r/usr/src/linux/.config"; do
    if [[ -r "$f" ]]; then cat "$f"; return; fi
  done
  return 1
}

# kernel_missing <config text> — "OPTION|what for" for every want the config lacks.
kernel_missing() {
  local config="$1" want opts why o found
  for want in "${KERNEL_WANTS[@]}"; do
    opts="${want%%|*}"; why="${want#*|}"; found=0
    for o in $opts; do
      if grep -qE "^CONFIG_${o}=(y|m)$" <<<"$config"; then found=1; break; fi
    done
    (( found )) || printf '%s|%s\n' "${opts%% *}" "$why"
  done
}
