import QtQuick
import ".."
import qs.services
Stat { icon: "cpu"; value: Math.round(SysInfo.cpuUsage * 100) + "%"; alert: SysInfo.cpuUsage > 0.9 }
