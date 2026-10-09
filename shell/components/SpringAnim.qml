import QtQuick
import qs.theme

// A spring with a motion token: Behavior on x { enabled: Motion.enabled; SpringAnim { token: Motion.smooth } }
SpringAnimation {
    property var token: Motion.smooth
    spring: token.spring
    damping: token.damping
    mass: token.mass
    epsilon: 0.25
}
