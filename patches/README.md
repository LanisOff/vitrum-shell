# niri patches

niri gets built from a pinned revision with the Niri-glass overlay on top (see
`lib/stages/30-niri.sh`). If you need to change niri beyond that, drop a
`.patch` file into `patches/niri-glass/` and the niri stage applies it with
`git apply` after the overlay, in file name order.

What's there now:

- `0001-shaped-glass.patch` adds `shape-fillet` to `liquid-glass`. With it, a
  surface's glass takes the shape of its blur region instead of its geometry:
  each rectangle becomes its own rounded piece with its own rim, and pieces
  that touch melt into one with concave fillets. The bar uses it, so every
  island is a separate lens and an open panel hangs off its island like a drop.
  The installer rebuilds niri whenever a patch changes.
- `0004-glass-while-opening.patch`: while a window's open animation runs, niri
  draws the tile into an offscreen buffer, where its background effect has
  nothing behind it — kitty showed plain translucent for half a second before
  its glass appeared. The effect is now drawn in place, at the animation's
  scale (not with a custom open shader, which transforms the window its own way).

After adding or changing one, rebuild with:

```bash
./install.sh --only niri --fresh
```
