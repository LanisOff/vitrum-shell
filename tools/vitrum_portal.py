"""What vitrum-portal decides, apart from D-Bus: cursor modes, the picker's
answer, and the streams handed back to the app."""
import json

MONITOR, WINDOW = 1, 2          # portal source types (bitmask)
CURSOR_HIDDEN, CURSOR_EMBEDDED, CURSOR_METADATA = 1, 2, 4   # portal cursor modes (bitmask)


def mutter_cursor(portal_mode, show_cursor=None):
    """Portal cursor mode (a bit) → the cursor-mode niri's Mutter API takes.
    The picker's own toggle, when there is one, wins. Unset means embedded."""
    if show_cursor is not None:
        return 1 if show_cursor else 0
    return {CURSOR_HIDDEN: 0, CURSOR_EMBEDDED: 1, CURSOR_METADATA: 2}.get(portal_mode or 0, 1)


def parse_answer(text, types=MONITOR | WINDOW, multiple=True):
    """The picker's JSON → {ok, sources, cursor}. Anything unexpected is a cancel."""
    cancel = {"ok": False, "sources": [], "cursor": None}
    try:
        data = json.loads(text)
    except (ValueError, TypeError):
        return cancel
    if not isinstance(data, dict) or not data.get("ok"):
        return cancel
    sources = []
    for s in data.get("sources") or []:
        if not isinstance(s, dict):
            continue
        if s.get("type") == "monitor" and types & MONITOR and isinstance(s.get("connector"), str) and s["connector"]:
            sources.append({"type": "monitor", "connector": s["connector"]})
        elif s.get("type") == "window" and types & WINDOW and isinstance(s.get("id"), int):
            sources.append({"type": "window", "id": s["id"]})
    if not sources:
        return cancel
    if not multiple:
        sources = sources[:1]
    cursor = data.get("cursor")
    return {"ok": True, "sources": sources, "cursor": cursor if isinstance(cursor, bool) else None}


def stream_entry(node_id, source, params):
    """One entry of Start's "streams": (PipeWire node, {source_type, position, size})."""
    props = {"source_type": MONITOR if source["type"] == "monitor" else WINDOW}
    for key in ("position", "size"):
        if key in params:
            props[key] = tuple(params[key])
    return (node_id, props)


def write_active(path, sessions):
    """Who is sharing now, for the shell: {"sessions": [{session, app}]}, written atomically."""
    import os
    tmp = str(path) + ".tmp"
    with open(tmp, "w") as f:
        json.dump({"sessions": list(sessions)}, f)
    os.replace(tmp, str(path))
