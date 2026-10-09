import { load, eq, ok } from "./lib.mjs";
const n = load("notifs.js");

// A live notification as Quickshell hands it over: actions are objects with
// methods (QObjects) that die with the notification.
const action = (id, text) => ({ identifier: id, text, invoke() {} });
const live = { id: 7, appName: "Telegram", appIcon: "telegram", summary: "Anna", body: "hi", image: "",
               urgency: 1, actions: [action("default", ""), action("reply", "Reply")], dismiss() {} };
const r = n.record(live, new Date(2026, 9, 2, 12, 0));

// Nothing in a history record may point at the live object: models copy
// records into QVariants, and a dangling QObject there crashes Quickshell.
eq(JSON.stringify(JSON.parse(JSON.stringify(r))), JSON.stringify(r), "record is plain data");
eq(r.notification, undefined, "no live notification in the record");
eq(r.actions.length, 2, "actions kept");
eq(r.actions[1].identifier, "reply", "action id");
eq(r.actions[1].text, "Reply", "action text");
eq(typeof r.actions[1].invoke, "undefined", "action is data, not the object");
eq(r.appName, "Telegram", "app");
eq(r.read, false, "unread");
eq(r.time, new Date(2026, 9, 2, 12, 0).getTime(), "time as a number");
eq(n.record({ id: 1 }, new Date(0)).appName, "Notification", "missing app name");
eq(n.record({ id: 1, actions: null }, new Date(0)).actions.length, 0, "no actions");

// Apps that take a reply in the notification (Telegram, KDE Connect).
{
  const rr = n.record({ id: 4, appName: "Telegram", hasInlineReply: true, inlineReplyPlaceholder: "Reply to Anna" }, new Date(0));
  eq(rr.canReply, true, "can reply");
  eq(rr.replyPlaceholder, "Reply to Anna", "placeholder");
  eq(n.record({ id: 5 }, new Date(0)).canReply, false, "most cannot");
}
