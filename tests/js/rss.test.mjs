import { load, eq, ok } from "./lib.mjs";
const r = load("rss.js");
const j = JSON.stringify;

// Text: CDATA, markup and character references.
eq(r.decode("Tom &amp; Jerry &lt;3 &#39;x&#39; &#x2014; &hellip; &bogus;"), "Tom & Jerry <3 'x' — … &bogus;", "references decoded, unknown kept");
eq(r.text("<![CDATA[ Rust <b>1.90</b> is out ]]>"), "Rust 1.90 is out", "CDATA unwrapped, its markup dropped");
eq(r.text("A &lt;b&gt;bold&lt;/b&gt; claim"), "A bold claim", "escaped markup dropped too");
eq(r.text("a &lt; b and c &gt; d"), "a < b and c > d", "a lone < is text, not a tag");
eq(r.text("  two\n   lines  "), "two lines", "whitespace folded");

// Dates: RFC 822 (RSS) and ISO 8601 (Atom, dc:date).
eq(r.parseDate("Sun, 25 Oct 2026 12:37:54 +0000"), Date.UTC(2026, 9, 25, 12, 37, 54), "RFC 822, +0000");
eq(r.parseDate("Sun, 25 Oct 2026 12:37:54 GMT"), Date.UTC(2026, 9, 25, 12, 37, 54), "RFC 822, GMT");
eq(r.parseDate("25 Oct 26 08:00 EDT"), Date.UTC(2026, 9, 25, 12, 0, 0), "two-digit year, a US zone, no weekday or seconds");
eq(r.parseDate("Sun, 25 Oct 2026 15:37:54 +0300"), Date.UTC(2026, 9, 25, 12, 37, 54), "an offset");
eq(r.parseDate("2026-10-25T09:52:12-04:00"), Date.UTC(2026, 9, 25, 13, 52, 12), "ISO with an offset");
eq(r.parseDate("2026-10-25T13:52:12.250Z"), Date.UTC(2026, 9, 25, 13, 52, 12), "ISO, Z and fractions");
eq(r.parseDate("2026-10-25"), Date.UTC(2026, 9, 25), "a date alone");
eq(r.parseDate("yesterday"), 0, "unreadable → 0");
eq(r.parseDate(""), 0, "none → 0");

// Sources: the feed's title, cut at its first separator, or the host.
eq(r.shortSource("Ars Technica - All content", "https://feeds.arstechnica.com/x"), "Ars Technica", "title before ' - '");
eq(r.shortSource("Hacker News: Front Page", ""), "Hacker News", "title before ': '");
eq(r.shortSource("", "https://www.example.org/feed.xml"), "example.org", "no title: the host, without www");
ok(r.shortSource("A really very long feed title that goes on and on", "").length <= 28, "a long title is cut");

// RSS 2.0.
const rss = `<?xml version="1.0"?><rss version="2.0"><channel><title>Hacker News</title><link>https://news.ycombinator.com/</link>
<item><title>First &amp; best</title><link>https://a.example/1</link><pubDate>Sun, 25 Oct 2026 12:00:00 +0000</pubDate></item>
<item><title><![CDATA[Second]]></title><guid>https://a.example/2</guid><pubDate>Sun, 25 Oct 2026 11:00:00 +0000</pubDate></item>
<item><title>Third</title><guid isPermaLink="false">tag:x,2026:3</guid></item>
<item><title></title><link>https://a.example/empty</link></item>
</channel></rss>`;
const f = r.parseFeed(rss, "https://news.ycombinator.com/rss");
eq(f.source, "Hacker News", "RSS: the channel's title");
eq(f.items.length, 3, "RSS: items with a title");
eq(f.items[0].title, "First & best", "RSS: title decoded");
eq(f.items[0].link, "https://a.example/1", "RSS: link");
eq(f.items[1].link, "https://a.example/2", "RSS: a permalink guid stands in for the link");
eq(f.items[2].link, "", "RSS: a guid that is no permalink is no link");
eq(f.items[0].time, Date.UTC(2026, 9, 25, 12), "RSS: pubDate");
eq(f.items[2].time, 0, "RSS: no date");
eq(f.error, "", "RSS: no error");
// An image block's title after the channel's does not take its place, and <items> is not an <item>.
const rdf = `<rdf:RDF xmlns:rdf="x" xmlns:dc="y"><channel><title>Slashdot</title><items><rdf:Seq><rdf:li resource="https://s/1"/></rdf:Seq></items></channel>
<image><title>Slashdot logo</title></image>
<item rdf:about="https://s/1"><title>One</title><link>https://s/1</link><dc:date>2026-10-25T10:00:00+00:00</dc:date></item></rdf:RDF>`;
const g = r.parseFeed(rdf, "https://rss.slashdot.org/");
eq(g.source, "Slashdot", "RDF: the channel's title");
eq(g.items.length, 1, "RDF: <items> is not an item");
eq(g.items[0].time, Date.UTC(2026, 9, 25, 10), "RDF: dc:date");

// Atom.
const atom = `<?xml version="1.0"?><feed xmlns="http://www.w3.org/2005/Atom"><title type="text">The Verge</title>
<link rel="alternate" href="https://www.theverge.com"/><link rel="self" href="https://www.theverge.com/rss/index.xml"/>
<entry><author><name>Someone</name></author><title type="html"><![CDATA[Phones, again]]></title>
<link rel="replies" href="https://www.theverge.com/1#comments"/><link rel="alternate" type="text/html" href="https://www.theverge.com/1"/>
<updated>2026-10-25T09:52:12-04:00</updated><published>2026-10-25T09:25:32-04:00</published></entry>
<entry><title>Bare link</title><link href='https://www.theverge.com/2?a=1&amp;b=2'/><published>2026-10-24T00:00:00Z</published></entry>
</feed>`;
const a = r.parseFeed(atom, "https://www.theverge.com/rss/index.xml");
eq(a.source, "The Verge", "Atom: the feed's title");
eq(a.items.length, 2, "Atom: entries");
eq(a.items[0].title, "Phones, again", "Atom: CDATA title");
eq(a.items[0].link, "https://www.theverge.com/1", "Atom: the alternate link, not replies");
eq(a.items[1].link, "https://www.theverge.com/2?a=1&b=2", "Atom: a link with no rel; its & decoded");
eq(a.items[0].time, Date.UTC(2026, 9, 25, 13, 52, 12), "Atom: updated first");
eq(a.items[1].time, Date.UTC(2026, 9, 24), "Atom: else published");

// Not a feed.
eq(r.parseFeed("<html><body>Blocked</body></html>", "https://x.example/").error, "Not a feed", "an HTML page is no feed");
eq(r.parseFeed("", "https://x.example/").error, "Empty reply", "nothing came");
eq(r.parseFeed("<rss><channel><title>T</title></channel></rss>", "").error, "No headlines", "a feed with no items");
eq(r.parseFeed(`<rss><channel><item><title>x</title><link>javascript:alert(1)</link></item></channel></rss>`, "").items[0].link, "", "only http(s) links open");

// The fetcher's output: SEP url, then the body.
const out = r.SEP + "https://a/\n<rss>A</rss>\n" + r.SEP + "https://b/\n" + r.SEP + "https://c/\n<feed/>";
eq(j(r.splitFeeds(out).map(x => x.url)), j(["https://a/", "https://b/", "https://c/"]), "split: every feed, in order");
eq(r.splitFeeds(out)[0].body, "<rss>A</rss>\n", "split: the body");
eq(r.splitFeeds(out)[1].body, "", "split: a feed that failed is empty");
eq(r.splitFeeds("").length, 0, "split: nothing");

// Merge: newest first, undated after in feed order, duplicates once, limited.
const m = r.merge([
  { items: [{ title: "a1", link: "https://a/1", time: 100 }, { title: "a2", link: "https://a/2", time: 0 }, { title: "dup", link: "https://x/same", time: 50 }] },
  { items: [{ title: "b1", link: "https://b/1", time: 300 }, { title: "dup again", link: "https://X/same", time: 60 }, { title: "b3", link: "", time: 0 }] }
], 0);
eq(j(m.map(x => x.title)), j(["b1", "a1", "dup", "a2", "b3"]), "merge: by time, undated last in feed order, a link once");
eq(r.merge([{ items: m }], 2).length, 2, "merge: limit");
eq(r.merge([null, { items: null }], 5).length, 0, "merge: missing feeds");

// Age.
const now = Date.UTC(2026, 9, 25, 12);
eq(r.age(now - 20000, now), "now", "age: under a minute");
eq(r.age(now - 12 * 60000, now), "12m", "age: minutes");
eq(r.age(now - 3 * 3600000, now), "3h", "age: hours");
eq(r.age(now - 2 * 86400000, now), "2d", "age: days");
eq(r.age(now - 30 * 86400000, now), "4w", "age: weeks");
eq(r.age(now + 60000, now), "now", "age: a clock ahead is now");
eq(r.age(0, now), "", "age: unknown");

// URLs from the option.
eq(j(r.urls([" https://a/feed ", "ftp://x", "", "https://a/feed", "http://b/rss", "https://bad url", 7])), j(["https://a/feed", "http://b/rss"]), "urls: http(s), trimmed, once");
eq(r.urls(Array.from({ length: 15 }, (_, i) => "https://f/" + i)).length, 10, "urls: ten at most");
