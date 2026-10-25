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

// The shell's springs as (ζ, k): all critically damped, so nothing overshoots
// or bounces (dichroic glass: motion is heavy and damped).
var SPRINGS = { snappy: [1.0, 900], smooth: [1.0, 600] };

// The tint's drift under the pointer: how long it glides, and its ease, a
// damped curve with no overshoot (CSS cubic-bezier(.2, .8, .2, 1)) as Qt's
// Easing.BezierSpline control points.
var DRIFT_MS = 1200;
// The one sweep across a tint when its piece turns on.
var SWEEP_MS = 1000;
var GLIDE = [0.2, 0.8, 0.2, 1, 1, 1];

// A spring token at a speed (Motion's motion.speed): stiffness scales with
// its square, so durations scale with 1/speed.
function spring(name, speed) {
    var p = SPRINGS[name] || SPRINGS.smooth;
    return qtSpring(p[0], p[1] * speed * speed);
}
