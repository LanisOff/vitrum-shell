import { load, eq } from "./lib.mjs";
const s = load("spotlight.js");
const sym = load("symbols.js");

// Symbols by name: a word that starts with the query first, then any match.
const arrows = s.searchSymbols(sym.all, "right arrow", 50);
eq(arrows.length > 3, true, "right arrows found");
eq(arrows.every(x => x.name.includes("right") && x.name.includes("arrow")), true, "every word matches");
eq(s.searchSymbols(sym.all, "degree", 5)[0].char, "°", "degree sign first");
eq(s.searchSymbols(sym.all, "euro", 5)[0].char, "€", "euro");
eq(s.searchSymbols(sym.all, "", 5).length, 5, "nothing typed: the first few");
eq(s.searchSymbols(sym.all, "zzzz", 5).length, 0, "no match");

// Code points for the preview, whole sequences included.
eq(s.codePoints("€"), "U+20AC", "one");
eq(s.codePoints("😀"), "U+1F600", "astral");
eq(s.codePoints("👍🏽"), "U+1F44D U+1F3FD", "with a modifier");

// The web search address, the query encoded.
eq(s.webUrl("https://www.google.com/search?q=%s", "a b&c"), "https://www.google.com/search?q=a%20b%26c", "encoded");
eq(s.webUrl("", "x"), "https://www.google.com/search?q=x", "Google when unset");

// What the preview shows for a file.
eq(s.fileKind("/a/b.PNG"), "image", "image");
eq(s.fileKind("/a/notes.md"), "text", "text");
eq(s.fileKind("/a/movie.mkv"), "other", "other");
