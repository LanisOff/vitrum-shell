# niri patches

niri gets built from a pinned commit of main with these patches on top (see
`lib/stages/30-niri.sh`): `patches/niri/*.patch`, applied with `git apply` in
file name order. To change niri further, add a patch there.

What's there now:

- `0001-nvidia-color-range.patch`: NVIDIA's driver takes the planes' COLOR_RANGE
  as the range of the whole output and sends limited range unless told otherwise,
  so monitor modes came out with grey blacks. It's set from the mode now.
- `0002-glass.patch`: vitrum's glass, `liquid-glass { }` in `background-effect`.
  A program of its own (`shaders/glass.frag`): a slab of glass with a rounded
  edge that bends the view inward, a thin highlight from a close light, a soft
  edge glow in the backdrop's own hue, vibrance and a faint sheen in the body.
  With `inner-rim`, small pieces stay bevelled islands. Also `blur-amount`, how
  much of niri's blur a rule uses, which makes the surface's blur chain shorter.
  The design is in
  `docs/superpowers/specs/2026-11-01-own-glass-design.md`.
- `0003-shaped-glass.patch` adds `shape-fillet`. With it, a surface's glass takes
  the shape of its blur region instead of its geometry: each rectangle becomes
  its own rounded piece with its own rim, and pieces that touch melt into one
  with concave fillets. The bar uses it, so every island is a separate lens and
  an open panel hangs off its island like a drop.
- `0004-shaped-glass-over-windows.patch`: the same on the framebuffer path, where
  the glass bends what's really behind it, windows included.
- `0005-glass-while-opening.patch`: while a window's open animation runs, niri
  draws the tile into an offscreen buffer, where its background effect has
  nothing behind it, and kitty showed plain translucent for half a second before
  its glass appeared. The effect is now drawn in place, at the animation's scale
  (not with a custom open shader, which transforms the window its own way).

The patches come as a series and later ones build on earlier ones. A change to
any patch rebuilds niri on the next install:

```bash
./install.sh --only niri --fresh
```
