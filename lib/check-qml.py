#!/usr/bin/env python3
"""
Check the QML before installing it.

Quickshell reports a bad shell.qml by refusing to start, which on a desktop
whose menu bar, Dock and launcher are all inside that shell means a grey screen
and no way to ask what went wrong. Every class of mistake below has cost a whole
session at least once:

  1. unbalanced braces                   — a parse error, nothing loads
  2. a type used without its import      — "IpcHandler is not a type"
  3. an Item property on a window root   — "Cannot assign to non-existent
                                            property opacity", which makes the
                                            type unavailable and cascades all
                                            the way up to shell.qml
  4. a property our own components do not have

None of this replaces actually running Quickshell. It catches the mistakes that
are cheap to make and expensive to discover, at the only moment when discovering
them is free.

    python3 lib/check-qml.py shell apps
"""

import os
import re
import sys

# ---------------------------------------------------------------- knowledge --

MODULE_TYPES = {
    "QtQuick": """Item Rectangle Text TextInput TextEdit Image AnimatedImage MouseArea Row
      Column Grid Flow ListView GridView PathView Repeater Loader Component Timer QtObject
      Connections Binding Gradient GradientStop Behavior NumberAnimation ColorAnimation
      RotationAnimation SequentialAnimation ParallelAnimation PropertyAnimation
      PauseAnimation PropertyAction ScriptAction State Transition AnchorChanges
      PropertyChanges Flickable Canvas Shortcut FocusScope DragHandler TapHandler
      HoverHandler WheelHandler PinchHandler FontLoader SystemPalette ListModel ListElement
      DelegateModel Instantiator Translate Rotation Scale BorderImage Flipable
      SmoothedAnimation SpringAnimation Animator OpacityAnimator ScaleAnimator
      RotationAnimator XAnimator YAnimator""".split(),
    "QtQuick.Effects": ["MultiEffect"],
    "QtQuick.Shapes": ["Shape", "ShapePath", "PathLine", "PathArc", "PathCubic", "PathSvg"],
    "QtQuick.Layouts": ["RowLayout", "ColumnLayout", "GridLayout", "StackLayout", "Layout"],
    "Quickshell": """ShellRoot PanelWindow FloatingWindow PopupWindow Variants Scope Singleton
      Quickshell Region QsWindow LazyLoader PersistentProperties Retainable SystemClock
      ElapsedTimer Transformer ExclusionMode ObjectModel ObjectRepeater ScriptModel
      DesktopEntries DesktopEntry QsMenuAnchor QsMenuOpener QsMenuHandle
      EnvironmentVariables""".split(),
    "Quickshell.Io": """Process StdioCollector SplitParser FileView Socket SocketServer
      DataStreamParser IpcHandler JsonAdapter FileViewError DataStream""".split(),
    "Quickshell.Wayland": """WlrLayershell WlrLayer WlrKeyboardFocus WlSessionLock
      WlSessionLockSurface ScreencopyView Toplevel ToplevelManager""".split(),
    "Quickshell.Widgets": """ClippingRectangle ClippingWrapperRectangle WrapperItem
      WrapperMouseArea IconImage MarginWrapperManager""".split(),
    "Quickshell.Services.UPower": ["UPower", "UPowerDevice", "UPowerDeviceState"],
    "Quickshell.Services.Pipewire": ["Pipewire", "PwNode", "PwNodeLinkTracker",
                                     "PwObjectTracker", "PwNodeAudio"],
    "Quickshell.Services.Mpris": ["Mpris", "MprisPlayer", "MprisPlaybackState", "MprisLoopState"],
    "Quickshell.Services.Notifications": ["NotificationServer", "Notification",
                                          "NotificationAction", "NotificationUrgency",
                                          "NotificationCloseReason"],
    "Quickshell.Services.SystemTray": ["SystemTray", "SystemTrayItem", "SystemTrayStatus"],
}
OWNER = {}
for _mod, _types in MODULE_TYPES.items():
    for _t in _types:
        OWNER.setdefault(_t, _mod)

# Properties that exist on Item and on nothing that is a window or a bare
# object. Assigning one at the root of a PanelWindow is fatal.
ITEM_ONLY = {"opacity", "scale", "rotation", "transform", "clip", "antialiasing", "smooth",
             "z", "states", "transitions", "layer", "focus", "activeFocus", "enabled",
             "childrenRect", "baselineOffset", "containmentMask"}
WINDOWISH = {"PanelWindow", "FloatingWindow", "WlSessionLockSurface", "PopupWindow"}
OBJECTISH = {"ShellRoot", "Singleton", "Scope", "QtObject", "WlSessionLock", "Variants"}

ITEM = set("""x y z width height implicitWidth implicitHeight anchors opacity visible enabled
clip rotation scale transform transformOrigin smooth antialiasing focus activeFocus
states transitions state layer parent children data resources baselineOffset
childrenRect containmentMask objectName""".split())
BASES = {
    "Item": ITEM,
    "Rectangle": ITEM | {"color", "radius", "border", "gradient"},
    "Text": ITEM | {"text", "font", "color", "style", "styleColor", "horizontalAlignment",
                    "elide", "verticalAlignment", "wrapMode", "lineHeight", "maximumLineCount",
                    "textFormat", "renderType", "padding", "topPadding", "bottomPadding",
                    "leftPadding", "rightPadding", "contentWidth", "contentHeight", "lineHeightMode",
                    "fontSizeMode", "minimumPixelSize", "linkColor", "baseUrl"},
    "TextInput": ITEM | {"text", "font", "color", "echoMode", "passwordCharacter",
                         "selectByMouse", "readOnly", "cursorVisible", "maximumLength",
                         "horizontalAlignment", "verticalAlignment", "selectionColor",
                         "selectedTextColor", "validator", "wrapMode"},
    "Image": ITEM | {"source", "fillMode", "sourceSize", "asynchronous", "cache", "mipmap",
                     "status"},
    "MouseArea": ITEM | {"hoverEnabled", "acceptedButtons", "cursorShape",
                         "propagateComposedEvents", "preventStealing", "pressed",
                         "containsMouse", "containsPress", "drag"},
    "Row": ITEM | {"spacing", "layoutDirection", "padding"},
    "Column": ITEM | {"spacing", "padding"},
    "Grid": ITEM | {"spacing", "rows", "columns", "rowSpacing", "columnSpacing", "flow"},
    "Flow": ITEM | {"spacing", "flow", "layoutDirection"},
    "Flickable": ITEM | {"contentWidth", "contentHeight", "contentX", "contentY",
                         "boundsBehavior", "flickableDirection", "interactive",
                         "topMargin", "bottomMargin"},
    "ListView": ITEM | {"model", "delegate", "orientation", "spacing", "currentIndex",
                        "currentItem", "highlight", "boundsBehavior", "cacheBuffer",
                        "section", "header", "footer", "snapMode", "interactive", "count",
                        "reuseItems", "keyNavigationEnabled"},
    "Canvas": ITEM | {"contextType", "renderStrategy", "renderTarget", "available",
                      "canvasSize", "tileSize"},
    "Loader": ITEM | {"source", "sourceComponent", "active", "asynchronous", "item", "status"},
    "Repeater": ITEM | {"model", "delegate", "count"},
    "PanelWindow": {"color", "visible", "screen", "anchors", "mask", "exclusiveZone",
                    "aboveWindows", "focusable", "margins", "implicitWidth", "implicitHeight",
                    "width", "height", "data"},
    "FloatingWindow": {"color", "visible", "title", "minimumSize", "maximumSize",
                       "implicitWidth", "implicitHeight", "width", "height", "data", "screen"},
}
NOT_A_PROPERTY = {"id", "property", "readonly", "required", "signal", "function", "component",
                  "default", "import", "pragma", "on", "as"}


# ------------------------------------------------------------------- lexing --

def strip_comments_and_strings(text):
    """Blank out strings and comments so nothing inside them is ever parsed.

    Regex literals are recognised too: a `/` in a value position starts one, and
    a `/` inside a character class does not end it.
    """
    out = []
    i, n, prev = 0, len(text), ""
    while i < n:
        c = text[i]
        if c in "\"'`":
            quote = c
            i += 1
            while i < n and text[i] != quote:
                if text[i] == "\\":
                    i += 1
                if i < n and text[i] == "\n":
                    out.append("\n")
                i += 1
            i += 1
            out.append("S")
            prev = "S"
            continue
        if text.startswith("//", i):
            while i < n and text[i] != "\n":
                i += 1
            continue
        if text.startswith("/*", i):
            j = text.find("*/", i + 2)
            chunk = text[i:(j + 2 if j >= 0 else n)]
            out.append("\n" * chunk.count("\n"))
            i = j + 2 if j >= 0 else n
            continue
        if c == "/" and prev in "(,=:[!&|?{;+":
            j, closed, in_class = i + 1, False, False
            while j < n and text[j] != "\n":
                if text[j] == "\\":
                    j += 2
                    continue
                if text[j] == "[":
                    in_class = True
                elif text[j] == "]":
                    in_class = False
                elif text[j] == "/" and not in_class:
                    closed = True
                    break
                j += 1
            if closed:
                i = j + 1
                out.append("R")
                prev = "R"
                continue
        out.append(c)
        if not c.isspace():
            prev = c
        i += 1
    return "".join(out)


def read_qml(path, report):
    """Read one file, or report why it could not be read. Never raise.

    A checker that dies with a traceback is worse than no checker: it stops the
    install, and the traceback says which line of Python gave up rather than
    which file is at fault. That is exactly what happened the first time a QML
    file arrived not encoded as UTF-8 — a copy onto a USB stick had mangled one
    character, and the error named `check-qml.py:354` and nothing else.
    """
    try:
        data = open(path, "rb").read()
    except OSError as e:
        report(path, 1, "cannot be read: %s" % e.strerror)
        return None
    try:
        return data.decode("utf-8")
    except UnicodeDecodeError as e:
        line = data[:e.start].count(b"\n") + 1
        near = data[max(0, e.start - 24):e.start + 24]
        report(path, line,
               "not valid UTF-8 — byte 0x%02x at offset %d, near %r.\n"
               "      QML must be UTF-8. This is almost always a damaged copy "
               "rather than an edit;\n"
               "      restore the file (git checkout -- %s) or copy the "
               "repository again."
               % (data[e.start], e.start, near.decode("utf-8", "replace"), path))
        return None


def qml_files(roots):
    """Every .qml file, and nothing that merely looks like one.

    `._Foo.qml` is not QML. macOS writes one of those beside every file it
    copies onto a filesystem that cannot hold an extended attribute — a USB
    stick, most often — and they are binary AppleDouble metadata that happens
    to end in .qml. Reading them as source produced a screenful of "not valid
    UTF-8" that named ninety-four files, none of which was actually wrong.

    Dotfiles in general are not sources here, so the rule is the simple one.

    Symlinked directories are followed (the apps reach shared code that way),
    and each real file is yielded once, under the first root that reaches it.
    """
    seen = set()
    for root in roots:
        for dirpath, dirs, names in os.walk(root, followlinks=True):
            dirs[:] = [d for d in dirs if not d.startswith(".")]
            for name in sorted(names):
                if name.endswith(".qml") and not name.startswith("."):
                    path = os.path.join(dirpath, name)
                    real = os.path.realpath(path)
                    if real in seen:
                        continue
                    seen.add(real)
                    yield path


# ------------------------------------------------------------------- checks --

def check_braces(path, clean, report):
    stack, line = [], 1
    pairs = {")": "(", "]": "[", "}": "{"}
    for ch in clean:
        if ch == "\n":
            line += 1
        elif ch in "([{":
            stack.append((ch, line))
        elif ch in ")]}":
            if not stack or stack[-1][0] != pairs[ch]:
                report(path, line, "unbalanced %s" % ch)
                return False
            stack.pop()
    if stack:
        report(path, stack[0][1], "unclosed %s" % stack[0][0])
        return False
    return True


def reachable_dirs(path, raw, root):
    """Directories whose types this file can use: its own, every `import qs.<dir>`
    (relative to the config root), and every relative `import "<dir>"`."""
    here = os.path.dirname(os.path.abspath(path))
    dirs = {os.path.realpath(here)}
    # realpath: the apps reach the shell's directories through symlinks.
    for mod in re.findall(r"^\s*import\s+qs\.([\w.]+)", raw, re.M):
        dirs.add(os.path.realpath(os.path.join(root, *mod.split("."))))
    for rel in re.findall(r'^\s*import\s+"([^"]+)"', raw, re.M):
        if not rel.endswith(".js"):
            dirs.add(os.path.realpath(os.path.join(here, rel)))
    return dirs


def check_repo_imports(path, raw, clean, root, defined_in, report):
    """A type the repo defines in another directory needs that directory imported."""
    used = set(re.findall(r"(?:^|[\s:\[{(,])([A-Z]\w*)\s*\{", clean))
    inline = set(re.findall(r"\bcomponent\s+([A-Z]\w*)\s*:", clean))
    dirs = reachable_dirs(path, raw, root)
    for t in sorted(used - inline):
        homes = defined_in.get(t)
        if not homes or homes & dirs:
            continue
        home = sorted(homes)[0]
        rel = os.path.relpath(home, os.path.realpath(root))
        hint = "import qs.%s" % rel.replace(os.sep, ".") if not rel.startswith("..") else 'import "%s"' % os.path.relpath(home, os.path.realpath(os.path.dirname(os.path.abspath(path))))
        report(path, line_of(clean, t), "%s needs `%s`" % (t, hint))


def check_imports(path, raw, clean, local, report):
    imports = set(re.findall(r"^\s*import\s+([\w.]+)", raw, re.M))
    has_qtquick = any(i == "QtQuick" or i.startswith("QtQuick.") for i in imports)
    used = set(re.findall(r"(?:^|[\s:\[{(,])([A-Z]\w*)\s*\{", clean))
    used |= set(re.findall(r"\b([A-Z]\w*)\.[a-zA-Z_]", clean))
    for t in sorted(used):
        if t in local:
            continue
        mod = OWNER.get(t)
        if not mod or mod in imports:
            continue
        if mod == "QtQuick" and has_qtquick:
            continue
        report(path, line_of(clean, t), "%s needs `import %s`" % (t, mod))


def line_of(clean, token):
    m = re.search(r"\b%s\b" % re.escape(token), clean)
    return clean[:m.start()].count("\n") + 1 if m else 1


def root_type(clean):
    m = re.search(r"^\s*([A-Z]\w*)\s*\{", clean, re.M)
    return m.group(1) if m else None


def check_window_root(path, clean, report):
    rt = root_type(clean)
    if rt not in WINDOWISH and rt not in OBJECTISH:
        return
    depth, line = 0, 1
    for raw_line in clean.split("\n"):
        text = raw_line.strip()
        if depth == 1:
            m = re.match(r"([A-Za-z_]\w*)\s*:(?!:)", text)
            if m and m.group(1) in ITEM_ONLY:
                report(path, line,
                       "`%s` on a %s root — windows are not Items, this is fatal"
                       % (m.group(1), rt))
            b = re.match(r"Behavior\s+on\s+(\w+)", text)
            if b and b.group(1) in ITEM_ONLY:
                report(path, line,
                       "`Behavior on %s` on a %s root — windows are not Items"
                       % (b.group(1), rt))
        depth += raw_line.count("{") - raw_line.count("}")
        line += 1


def collect_types(cleaned, paths):
    """Every type this repo defines, and what it inherits from.

    Works from text already decoded by read_qml rather than opening the files
    again — one guarded read per file, and no second place that can throw.
    """
    # Inline components belong to their file: four panes each with their own
    # `component Chip_` are four types, not one (the last one read won).
    root_of, declared, inline = {}, {}, {}

    def decls(body):
        props = set(re.findall(
            r"\b(?:readonly\s+|required\s+|default\s+)*property\s+(?:alias\s+)?[\w.<>]+\s+(\w+)",
            body))
        sigs = set(re.findall(r"\bsignal\s+(\w+)", body))
        fns = set(re.findall(r"\bfunction\s+(\w+)", body))
        out = props | sigs | fns
        out |= {"on" + x[0].upper() + x[1:] for x in sigs}
        out |= {"on" + x[0].upper() + x[1:] + "Changed" for x in props}
        return out

    for path in paths:
        clean = cleaned[path][1]
        stem = os.path.splitext(os.path.basename(path))[0]
        root_of.setdefault(stem, root_type(clean) or "Item")
        declared.setdefault(stem, set())
        declared[stem] |= decls(clean)
        for m in re.finditer(r"\bcomponent\s+([A-Z]\w*)\s*:\s*([\w.]+)\s*\{", clean):
            name, base = m.group(1), m.group(2)
            i, depth, start = m.end(), 1, m.end()
            while i < len(clean) and depth:
                if clean[i] == "{":
                    depth += 1
                elif clean[i] == "}":
                    depth -= 1
                i += 1
            inline.setdefault(path, {})[name] = (base.split(".")[-1], decls(clean[start:i - 1]))
    return root_of, declared, inline


def allowed_props(t, root_of, declared, seen=None):
    """The properties a use of our type `t` may set — or None when its chain
    ends in a Qt type this checker has no list for (then nothing is checked:
    guessing Item's properties flagged e.g. a NumberAnimation's duration)."""
    seen = seen or set()
    if t in seen:
        return set()
    seen.add(t)
    out = set(declared.get(t, set()))
    base = root_of.get(t)
    if base in BASES:
        out |= BASES[base]
    elif base and base != t and base in root_of:
        inherited = allowed_props(base, root_of, declared, seen)
        if inherited is None:
            return None
        out |= inherited
    elif base in (None, "Item"):
        out |= ITEM
    else:
        return None
    return out


def check_our_properties(path, clean, root_of, declared, report):
    known = set(root_of)
    for m in re.finditer(r"(?:^|[\s:\[{(,])((?:\w+\.)?[A-Z]\w*)\s*\{", clean):
        t = m.group(1).split(".")[-1]
        if t not in known:
            continue
        i, depth, start = m.end(), 1, m.end()
        while i < len(clean) and depth:
            if clean[i] == "{":
                depth += 1
            elif clean[i] == "}":
                depth -= 1
            i += 1
        ok = allowed_props(t, root_of, declared)
        if ok is None:
            continue
        # Properties this object declares itself are settable too.
        body = clean[start:i - 1]
        ok = ok | set(re.findall(r"^\s*(?:readonly\s+|required\s+|default\s+)*property\s+[\w<>.]+\s+(\w+)", body, re.M))
        # A change handler is allowed wherever its property is.
        ok = ok | {"on" + p[0].upper() + p[1:] + "Changed" for p in ok if p and p[0].islower()}
        line = clean[:start].count("\n") + 1
        depth2 = 0
        for raw_line in clean[start:i - 1].split("\n"):
            text = raw_line.strip()
            if depth2 == 0:
                a = re.match(r"([A-Za-z_]\w*)\s*:(?!:)", text)
                if a and a.group(1) not in NOT_A_PROPERTY and a.group(1) not in ok:
                    report(path, line, "%s has no property `%s`" % (t, a.group(1)))
            depth2 += raw_line.count("{") - raw_line.count("}")
            line += 1


# --------------------------------------------------------------------- main --

def root_for(path, roots):
    """The config root a file belongs to (what `qs.` imports are relative to)."""
    a = os.path.abspath(path)
    best = ""
    for r in roots:
        r = os.path.abspath(r)
        if (a == r or a.startswith(r + os.sep)) and len(r) > len(best):
            best = r
    return best or os.path.dirname(a)


def main(argv):
    roots = argv[1:] or ["shell", "apps"]
    paths = [p for p in qml_files(roots)]
    if not paths:
        print("check-qml: nothing to check in %s" % ", ".join(roots), file=sys.stderr)
        return 0

    problems = []

    def report(path, line, message):
        problems.append("%s:%s: %s" % (path, line, message))

    cleaned = {}
    local = set()
    defined_in = {}        # type name → directories that define it (one file per type)
    for path in paths:
        raw = read_qml(path, report)
        if raw is None:
            continue
        clean = strip_comments_and_strings(raw)
        cleaned[path] = (raw, clean)
        local.add(os.path.splitext(os.path.basename(path))[0])
        defined_in.setdefault(os.path.splitext(os.path.basename(path))[0], set()).add(os.path.realpath(os.path.dirname(os.path.abspath(path))))
        local |= set(re.findall(r"\bcomponent\s+([A-Z]\w*)\s*:", clean))

    parseable = []
    for path in cleaned:
        raw, clean = cleaned[path]
        if check_braces(path, clean, report):
            parseable.append(path)

    root_of, declared, inline = collect_types(cleaned, parseable)

    for path in parseable:
        raw, clean = cleaned[path]
        check_imports(path, raw, clean, local, report)
        check_repo_imports(path, raw, clean, root_for(path, roots), defined_in, report)
        check_window_root(path, clean, report)
        own_root, own_decl = dict(root_of), dict(declared)
        for name, (base, decl) in inline.get(path, {}).items():
            own_root[name], own_decl[name] = base, decl
        check_our_properties(path, clean, own_root, own_decl, report)

    if problems:
        print("check-qml: %d problem(s) in %d file(s):" % (len(problems), len(paths)))
        for p in problems:
            print("  " + p)
        return 1

    print("check-qml: %d files, no problems" % len(paths))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
