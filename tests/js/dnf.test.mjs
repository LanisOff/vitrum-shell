import { load, eq } from "./lib.mjs";
const d = load("dnf.js");
const j = JSON.stringify;

// dnf5 (Fedora 41: `dnf check-update -q`, taken from a fedora:41 container,
// exit 100): no header, no blank line.
const dnf5 = [
  "xz.x86_64      1:5.8.1-4.fc41 updates",
  "xz-libs.x86_64 1:5.8.1-4.fc41 updates",
  "python3.12.x86_64 3.12.7-1.fc41 updates",
  "glibc.i686     2.40-9.fc41    updates",
  "",
].join("\n");
const installed = [
  "xz.x86_64 1:5.6.2-2.fc41",
  "xz-libs.x86_64 1:5.6.2-2.fc41",
  "python3.12.x86_64 3.12.6-1.fc41",
  "glibc.i686 2.40-3.fc41",
  "publicsuffix-list-dafsa.noarch 20250616-1.fc41",
].join("\n");

eq(j(d.splitNameArch("python3.12.x86_64")), j({ name: "python3.12", arch: "x86_64" }), "dots in the name");
eq(j(d.splitNameArch("publicsuffix-list-dafsa.noarch")), j({ name: "publicsuffix-list-dafsa", arch: "noarch" }), "noarch");
eq(d.splitNameArch("noarch"), null, "no architecture");

eq(j(d.parseUpdates(dnf5, installed)), j([
  { atom: "xz", from: "1:5.6.2-2.fc41", to: "1:5.8.1-4.fc41", kind: "update" },
  { atom: "xz-libs", from: "1:5.6.2-2.fc41", to: "1:5.8.1-4.fc41", kind: "update" },
  { atom: "python3.12", from: "3.12.6-1.fc41", to: "3.12.7-1.fc41", kind: "update" },
  { atom: "glibc.i686", from: "2.40-3.fc41", to: "2.40-9.fc41", kind: "update" },
]), "dnf5: epochs kept, the 32-bit package named apart");
eq(j(d.parseUpdates(dnf5)[0]), j({ atom: "xz", to: "1:5.8.1-4.fc41", kind: "update" }), "without the installed list, no from");

// dnf4 (Fedora 39): a blank line first, a long name wrapped onto its own line,
// and an Obsoleting section whose indented lines are what gets replaced.
const dnf4 = [
  "",
  "kernel.x86_64                          6.11.9-100.fc39                 updates",
  "texlive-collection-latexrecommended.noarch",
  "                                       11:svn65512-69.fc39             updates",
  "grub2-tools.x86_64                     1:2.06-121.fc39                 updates",
  "Obsoleting Packages",
  "grub2-tools.x86_64                     1:2.06-121.fc39                 updates",
  "    grub2-tools.x86_64                 1:2.06-100.fc39                 @anaconda",
  "python3-newname.noarch                 2.0-1.fc39                      updates",
  "    python3-oldname.noarch             1.0-3.fc39                      @fedora",
  "",
].join("\n");
eq(j(d.parseUpdates(dnf4, "kernel.x86_64 6.11.8-100.fc39\ngrub2-tools.x86_64 1:2.06-100.fc39")), j([
  { atom: "kernel", from: "6.11.8-100.fc39", to: "6.11.9-100.fc39", kind: "update" },
  { atom: "texlive-collection-latexrecommended", to: "11:svn65512-69.fc39", kind: "update" },
  { atom: "grub2-tools", from: "1:2.06-100.fc39", to: "1:2.06-121.fc39", kind: "update" },
  { atom: "python3-newname", to: "2.0-1.fc39", kind: "new" },
]), "dnf4: wrapped names joined, obsoleted packages left out, a rename is new");

// A zero epoch from rpm is left out, as dnf leaves it out.
eq(j(d.parseInstalled("bash.x86_64 0:5.2.32-1.fc41\nxz.x86_64 1:5.6.2-2.fc41")), j({ "bash.x86_64": "5.2.32-1.fc41", "xz.x86_64": "1:5.6.2-2.fc41" }), "0: dropped, 1: kept");
eq(j(d.parseUpdates("bash.x86_64 5.2.37-1.fc41 updates", "bash.x86_64 0:5.2.32-1.fc41")),
   j([{ atom: "bash", from: "5.2.32-1.fc41", to: "5.2.37-1.fc41", kind: "update" }]), "from and to read alike");

// What else dnf may print, even with -q, is not a package.
eq(d.parseUpdates("Available upgrades\nSecurity: kernel-core-6.11.9-100.fc39.x86_64 is an installed security update\n" +
                  "Last metadata expiration check: 0:01:02 ago on Mon 20 Oct 2026.").length, 0, "headers and notes");
eq(d.parseUpdates("").length, 0, "up to date");
