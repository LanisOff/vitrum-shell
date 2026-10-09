.pragma library
// Motion tokens. niri springs are (damping ratio ζ, stiffness k) with unit mass:
//   a = −k·x − 2ζ√k·v
// Qt's SpringAnimation uses `spring` and `damping` scaled by 1/100 relative to
// that (its integrator multiplies both by 100), so the same physics is
//   spring = k/100, damping = 2ζ√k/100.

function qtSpring(dampingRatio, stiffness) {
    return { spring: stiffness / 100, damping: 2 * dampingRatio * Math.sqrt(stiffness) / 100, mass: 1 };
}

function scaled(ms, speed, reduce) {
    if (reduce) return 0;
    return Math.round(ms / (speed > 0 ? speed : 1));
}
