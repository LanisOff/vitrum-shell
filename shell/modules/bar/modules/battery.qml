import QtQuick
import ".."
import qs.services
import qs.theme
import "../../../lib/bar.js" as BarLib
// The laptop battery (Power, from UPower), only where there is one: the glyph
// by level (a bolt while it charges), the percentage beside it
// (bar.modules.battery.percent), the time until empty or full
// (bar.modules.battery.time). Hidden on the charger when full or held at a
// charge limit with bar.modules.battery.hideFull. Red when low and draining.
// Click: the Control Centre (power profile, brightness).
StatusIcon {
    shown: Power.hasBattery && !(Settings.get("bar.modules.battery.hideFull", false) && Power.full)
    icon: BarLib.batteryIcon(Power.percentage, Power.charging)
    label: BarLib.batteryLabel(Power.percentage, Settings.get("bar.modules.battery.percent", true),
                               Power.timeRemaining, Settings.get("bar.modules.battery.time", false))
    tint: (Power.low || Power.critical) && !Power.charging ? Colors.danger : Colors.text
}
