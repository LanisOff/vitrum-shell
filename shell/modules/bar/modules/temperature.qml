import QtQuick
import ".."
import qs.services
Stat { icon: "temperature"; value: Math.round(SysInfo.cpuTemp) + "°"; alert: SysInfo.cpuTemp > 85; shown: SysInfo.cpuTemp > 0 }
