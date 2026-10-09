import QtQuick
import ".."
import qs.services
Stat { icon: "memory"; value: Math.round(SysInfo.memoryUsage * 100) + "%"; alert: SysInfo.memoryUsage > 0.9 }
