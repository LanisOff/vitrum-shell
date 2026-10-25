import { load, eq } from "./lib.mjs";
const c = load("clip.js");
const j = JSON.stringify;

const list = c.parseList("12\thello world\n11\t[[ binary data 2 MiB png 1920x1080 ]]\nbad line\n\n10\tline\twith tab\n");
eq(list.length, 3, "three entries, junk skipped");
eq(list[0].id, "12", "id");
eq(list[1].isImage, true, "a picture");
eq(list[0].isImage, false, "text");
eq(list[2].preview, "line\twith tab", "the preview keeps later tabs");
eq(c.parseList("1\ta\n2\tb\n3\tc", 2).length, 2, "limit");
eq(j(c.parseList("")), "[]", "nothing");
eq(j(c.imageInfo("[[ binary data 2 MiB png 1920x1080 ]]")), j({ type: "PNG", size: "2 MiB", w: 1920, h: 1080 }), "image info");
eq(c.imageInfo("[[ binary data 31 KiB jpg ]]").type, "JPEG", "jpg is JPEG, no size given");
eq(c.imageInfo("hello"), null, "text has none");
eq(c.oneLine("  a\n\tb   c "), "a b c", "one line");
