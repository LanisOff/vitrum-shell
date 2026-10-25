import { load, eq } from "./lib.mjs";
const a = load("about.js");
const j = JSON.stringify;

// Processor
eq(a.cpuShort("AMD Ryzen 5 7500F 6-Core Processor"), "Ryzen 5 7500F", "AMD desktop");
eq(a.cpuShort("AMD Ryzen 7 7840U w/ Radeon 780M Graphics"), "Ryzen 7 7840U w/ Radeon 780M Graphics", "AMD laptop keeps what is not noise");
eq(a.cpuShort("AMD Ryzen 9 5900HX with Radeon Graphics"), "Ryzen 9 5900HX", "with Radeon Graphics dropped");
eq(a.cpuShort("13th Gen Intel(R) Core(TM) i7-13700K"), "Core i7-13700K", "Intel with generation");
eq(a.cpuShort("Intel(R) Core(TM) i5-8250U CPU @ 1.60GHz"), "Core i5-8250U", "Intel with clock");
eq(a.cpuShort("Intel(R) Core(TM) Ultra 7 155H"), "Core Ultra 7 155H", "Core Ultra");
eq(a.cpuShort(""), "", "nothing");

// Graphics
const lspci = "Intel Corporation Raptor Lake-S GT1 [UHD Graphics 770] (rev 04)\nNVIDIA Corporation AD107 [GeForce RTX 4060] (rev a1)\n";
eq(a.gpuPick(lspci), "NVIDIA Corporation AD107 [GeForce RTX 4060] (rev a1)", "the discrete card over Intel");
eq(a.gpuPick(""), "", "no GPU line");
eq(a.gpuShort("NVIDIA Corporation AD107 [GeForce RTX 4060] (rev a1)"), "RTX 4060", "NVIDIA");
eq(a.gpuShort("Advanced Micro Devices, Inc. [AMD/ATI] Navi 31 [Radeon RX 7900 XTX] (rev c8)"), "RX 7900 XTX", "AMD, vendor bracket skipped");
eq(a.gpuShort("NVIDIA Corporation GA104 [GeForce RTX 3060 Ti / 3070 Ti Lite Hash Rate] (rev a1)"), "RTX 3060 Ti", "alternatives: the first");
eq(a.gpuShort("Intel Corporation Raptor Lake-S GT1 [UHD Graphics 770] (rev 04)"), "UHD Graphics 770", "Intel");
eq(a.gpuShort("Red Hat, Inc. Virtio 1.0 GPU (rev 01)"), "Red Hat, Inc. Virtio 1.0 GPU", "no brackets: the line");
eq(a.gpuVendor("NVIDIA Corporation AD107"), "NVIDIA", "vendor NVIDIA");
eq(a.gpuVendor("Advanced Micro Devices, Inc. [AMD/ATI] Navi 31"), "AMD", "vendor AMD");
eq(a.gpuVendor("Intel Corporation UHD"), "Intel", "vendor Intel");
eq(a.vram(8188), "8 GB", "VRAM from MiB");
eq(a.vram(0), "", "no VRAM");

// Sizes and the disk
eq(a.size(950000000000), "950 GB", "GB");
eq(a.size(1920000000000), "1.9 TB", "TB with a decimal");
eq(a.size(512000000), "512 MB", "MB");
eq(a.size(0), "", "zero");
eq(a.diskLine(241e9, 709e9), "241 GB used · 709 GB free", "used and free");
eq(a.diskLine(0, 0), "", "nothing known");
eq(a.diskUsage(241, 950), 241 / 950, "usage");
eq(a.diskUsage(5, 0), 0, "no size");
eq(a.diskUsage(10, 5), 1, "clamped");

// Uptime
eq(a.uptimeShort(86400 + 5 * 3600 + 120), "1d 5h", "days");
eq(a.uptimeShort(5 * 3600 + 12 * 60), "5h 12m", "hours");
eq(a.uptimeShort(720), "12m", "minutes");
eq(a.uptimeShort(0), "", "unknown");

// Memory
eq(a.memory(30.6), "31 GB", "rounded GiB");
eq(a.memory(0), "", "unknown");
eq(a.memorySub("DDR5", "6000 MT/s"), "DDR5 · 6000 MT/s", "type and speed");
eq(a.memorySub("Unknown", "4800"), "4800 MT/s", "Unknown type dropped, bare speed gets a unit");
eq(a.memorySub("", ""), "", "nothing");

// Board
eq(a.vendorShort("Micro-Star International Co., Ltd."), "MSI", "MSI");
eq(a.vendorShort("ASUSTeK COMPUTER INC."), "ASUS", "ASUS");
eq(a.vendorShort("To Be Filled By O.E.M."), "", "placeholder");
eq(a.vendorShort("Tuxedo Computers GmbH"), "Tuxedo Computers", "unknown maker: suffix trimmed");
eq(a.boardShort("MAG B650 TOMAHAWK WIFI (MS-7D75)"), "B650", "chipset");
eq(a.boardShort("ROG STRIX X670E-E GAMING WIFI"), "X670E", "chipset with E");
eq(a.boardShort("ThinkPad X1 Carbon Gen 11"), "ThinkPad X1 Carbon Gen 11", "laptop: the name");
eq(a.boardShort("Default string"), "", "placeholder");
eq(a.boardFull("Micro-Star International Co., Ltd.", "B650 GAMING PLUS WIFI (MS-7E26)"), "MSI B650 GAMING PLUS WIFI (MS-7E26)", "vendor + name");
eq(a.boardFull("LENOVO", "Lenovo ThinkPad"), "Lenovo ThinkPad", "vendor not said twice");
eq(a.boardSub("Micro-Star International Co., Ltd.", "1.30"), "MSI · firmware 1.30", "vendor and firmware");
eq(a.boardSub("", ""), "", "nothing");

// Displays
const two = [
  { name: "DP-1", width: 1920, height: 1080, refresh: 60, model: "Odyssey G40B", x: 0, y: 0, logicalWidth: 1920, logicalHeight: 1080 },
  { name: "HDMI-A-1", width: 1920, height: 1080, refresh: 60, model: "Unknown", x: 1920, y: 0, logicalWidth: 1920, logicalHeight: 1080 }
];
eq(a.displaysLine(two), "2 × 1920×1080", "same screens");
eq(a.displaysLine([{ width: 2560, height: 1440 }, { width: 1920, height: 1080 }]), "2560×1440 + 1920×1080", "mixed");
eq(a.displaysLine([{ width: 2560, height: 1440 }]), "2560×1440", "one");
eq(a.displaysLine([]), "", "none");
eq(a.displaysSub(two), "60 Hz · Odyssey G40B", "rate and the known model");
eq(a.displaysSub([{ width: 1, refresh: 144, model: "A" }, { width: 1, refresh: 60, model: "B" }]), "144 + 60 Hz · A + B", "two rates");

const l = a.layout(two, 200, 40, "HDMI-A-1");
eq(l.length, 2, "two rects");
eq(j(l.map(r => [Math.round(r.x), Math.round(r.y), Math.round(r.width), Math.round(r.height)])), j([[29, 0, 71, 40], [100, 0, 71, 40]]), "side by side, centred, proportional");
eq(j(l.map(r => r.primary)), j([false, true]), "the focused one is lit");
eq(a.layout(two, 200, 40, "")[0].primary, true, "no focus: the top left one");
const stacked = a.layout([{ name: "A", x: 0, y: 1440, logicalWidth: 1920, logicalHeight: 1080 }, { name: "B", x: 0, y: 0, logicalWidth: 2560, logicalHeight: 1440 }], 100, 100, "");
eq(stacked[1].primary, true, "top one lit");
eq(Math.round(stacked[0].y), Math.round(stacked[1].y + stacked[1].height), "stacked below");
const rowed = a.layout([{ name: "A", width: 1920, height: 1080 }, { name: "B", width: 1920, height: 1080 }], 100, 100, "");
eq(rowed[1].x > rowed[0].x, true, "no positions: in a row");
eq(a.layout([], 100, 100, "").length, 0, "none");

eq(a.subtitle("CachyOS", "26.04", "0.5.0"), "CachyOS · niri 26.04 · vitrum 0.5.0", "subtitle");
eq(a.subtitle("", "", "0.5.0"), "vitrum 0.5.0", "only what is known");
eq(a.subtitle("CachyOS", "26.04 (8ed0da4-modified)", "7bd35da"), "CachyOS · niri 26.04 · vitrum 7bd35da", "niri build hash dropped");
