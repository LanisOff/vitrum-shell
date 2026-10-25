import QtQuick
import ".."
import qs.services
Stat { show: Settings.get("bar.modules.memory.show", "both"); icon: "memory"; value: Math.round(SysInfo.memoryUsage * 100) + "%"; alert: SysInfo.memoryUsage > 0.9 }
