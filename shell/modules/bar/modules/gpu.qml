import QtQuick
import ".."
import qs.services
Stat { icon: "gpu"; value: Math.round(SysInfo.gpuUsage * 100) + "%"; alert: SysInfo.gpuTemp > 85; shown: SysInfo.gpuAvailable }
