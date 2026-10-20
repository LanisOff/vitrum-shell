#!/usr/bin/env python3
"""
Turn the fastfetch logo PNG into text kitty draws as the image, for tmux too.

fastfetch's own kitty logo (kitty-direct) places the image at the cursor. tmux
does not know the picture is there: it scrolls away from it, stays on screen
when you switch windows, and fastfetch's tmux wrapping of it leaves kitty's
escape unterminated, so kitty swallows everything printed after it until the
window is closed.

kitty's unicode placeholders are how images live inside tmux: the PNG goes to
kitty once (through tmux's passthrough), and the picture is drawn wherever a
grid of U+10EEEE cells sits on screen. Those cells are plain text to tmux, so
the image scrolls, switches windows and redraws with the pane.

Each output file is fastfetch's "raw" logo: printed as is, in a box of
<cols>x<rows> cells. One for kitty itself, one wrapped for tmux.

Usage:  kitty-logo.py <logo.png> <cols> <rows> <out.kitty> <out.tmux>
"""

from __future__ import annotations

import base64
import sys

# The placeholder cell, and the diacritics that number its row and column
# (kitty's gen/rowcolumn-diacritics.txt, the first 64).
PLACEHOLDER = "\U0010EEEE"
DIACRITICS = [
    0x0305, 0x030D, 0x030E, 0x0310, 0x0312, 0x033D, 0x033E, 0x033F,
    0x0346, 0x034A, 0x034B, 0x034C, 0x0350, 0x0351, 0x0352, 0x0357,
    0x035B, 0x0363, 0x0364, 0x0365, 0x0366, 0x0367, 0x0368, 0x0369,
    0x036A, 0x036B, 0x036C, 0x036D, 0x036E, 0x036F, 0x0483, 0x0484,
    0x0485, 0x0486, 0x0487, 0x0592, 0x0593, 0x0594, 0x0595, 0x0597,
    0x0598, 0x0599, 0x059C, 0x059D, 0x059E, 0x059F, 0x05A0, 0x05A1,
    0x05A8, 0x05A9, 0x05AB, 0x05AC, 0x05AF, 0x05C4, 0x0610, 0x0611,
    0x0612, 0x0613, 0x0614, 0x0615, 0x0616, 0x0617, 0x0657, 0x0658,
]

# The image's id, fixed so a second fastfetch replaces the picture instead of
# piling up copies. The cells carry it as a 256-colour foreground (the low
# byte, which tmux passes on unchanged) and a third diacritic (the high byte);
# an id this large stays clear of programs that number their images 1, 2, 3.
ID_LOW, ID_HIGH = 0xA7, 0x2A
IMAGE_ID = ID_HIGH << 24 | ID_LOW

CHUNK = 4096  # the protocol's limit for one piece of base64


def tmux_wrap(seq: str) -> str:
    """tmux passes a DCS tmux; ... ST on to the terminal, every ESC inside doubled."""
    return "\033Ptmux;" + seq.replace("\033", "\033\033") + "\033\\"


def transmit(png: bytes, cols: int, rows: int) -> list[str]:
    """The PNG in pieces, and a virtual placement of cols x rows cells to show it in.
    q=2: kitty answers nothing, so no reply lands in the shell's input."""
    data = base64.standard_b64encode(png).decode("ascii")
    pieces = [data[i:i + CHUNK] for i in range(0, len(data), CHUNK)] or [""]
    out = []
    for n, piece in enumerate(pieces):
        more = int(n < len(pieces) - 1)
        if n == 0:
            keys = f"a=T,U=1,i={IMAGE_ID},f=100,t=d,c={cols},r={rows},q=2,m={more}"
        else:
            keys = f"q=2,m={more}"
        out.append(f"\033_G{keys};{piece}\033\\")
    return out


def cells(cols: int, rows: int) -> str:
    """The grid. Every row ends back under its first cell, one line down
    (ESC D scrolls at the bottom of the screen), so it holds whatever the
    left padding is."""
    high = chr(DIACRITICS[ID_HIGH])
    lines = []
    for r in range(rows):
        lines.append("".join(PLACEHOLDER + chr(DIACRITICS[r]) + chr(DIACRITICS[c]) + high for c in range(cols)))
    return f"\033[38;5;{ID_LOW}m" + f"\033[{cols}D\033D".join(lines) + "\033[39m"


def main(argv: list[str]) -> int:
    if len(argv) != 6:
        print(__doc__.strip().splitlines()[-1], file=sys.stderr)
        return 2
    src, cols, rows, out_kitty, out_tmux = argv[1], int(argv[2]), int(argv[3]), argv[4], argv[5]
    if not (0 < cols <= len(DIACRITICS) and 0 < rows <= len(DIACRITICS)):
        print(f"kitty-logo: the box is at most {len(DIACRITICS)}x{len(DIACRITICS)} cells", file=sys.stderr)
        return 2
    with open(src, "rb") as f:
        png = f.read()
    seqs, grid = transmit(png, cols, rows), cells(cols, rows)
    for path, wrap in ((out_kitty, lambda s: s), (out_tmux, tmux_wrap)):
        with open(path, "w", encoding="utf-8") as f:
            f.write("".join(wrap(s) for s in seqs) + grid)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
