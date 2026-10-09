.pragma library
// A notification as the history keeps it: plain data only. Models copy these
// records into QVariants; a QObject in there (the notification, its actions)
// dangles once the sender closes it, and Quickshell crashes on the next
// delegate. The live object stays in Notifs' own map, keyed by id.

function record(n, now) {
    return {
        id: n.id,
        appName: n.appName || "Notification",
        appIcon: n.appIcon || "",
        summary: n.summary || "",
        body: n.body || "",
        image: n.image || "",
        urgency: n.urgency === undefined ? 1 : Number(n.urgency),
        actions: (n.actions || []).map(a => ({ identifier: String(a.identifier || ""), text: String(a.text || "") })),
        canReply: !!n.hasInlineReply,
        replyPlaceholder: n.inlineReplyPlaceholder ? String(n.inlineReplyPlaceholder) : "",
        time: (now instanceof Date ? now : new Date()).getTime(),
        read: false
    };
}
