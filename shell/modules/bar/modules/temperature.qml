import QtQuick
import ".."
import qs.services
Stat { show: Settings.get("bar.modules.temperature.show", "both"); icon: "temperature"; value: Math.round(SysInfo.cpuTemp) + "°"; alert: SysInfo.cpuTemp > 85; shown: SysInfo.cpuTemp > 0 }
