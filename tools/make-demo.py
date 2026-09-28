#!/usr/bin/env python3
"""Generate assets/shelf-demo.svg, the README's looping motion graphic.

One CSS-animated SVG, no JavaScript, so GitHub plays it inside <img>.
Every animation shares one loop length, which lets tools/render-video.js
freeze any instant by setting a negative animation-delay.

Story: files an agent sends get buried in the scrollback, one command
installs herdr-shelf, and prefix+f lists every delivered file for one-click
opening.
"""

import os

LOOP = 18.0
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "shelf-demo.svg")

FONT = "'SF Mono', Menlo, Monaco, 'PingFang TC', 'Noto Sans Mono CJK TC', monospace"

AMBER = "#d7af5f"
BLUE = "#7c93f0"
INK = "#e6e7ee"
SOFT = "#c7c9d6"
MUTED = "#6f7285"
FAINT = "#5d6075"
WINDOW = "#1e1f29"

keyframes = []
# selector -> ["name 18s timing infinite", ...]. One `animation` declaration
# per element: a second rule for the same selector would replace the first.
animations = {}


def track(selector, points, prop_fn, timing="linear"):
    """Animate `selector` through (seconds, value) points over the loop.

    Values hold between points only when a point repeats them, so callers
    list both ends of every still stretch.
    """
    name = "k%d" % len(keyframes)
    points = sorted(points)
    if points[0][0] > 0:
        points.insert(0, (0.0, points[0][1]))
    if points[-1][0] < LOOP:
        points.append((LOOP, points[-1][1]))
    frames = []
    for seconds, value in points:
        frames.append("%.3f%%{%s}" % (seconds / LOOP * 100, prop_fn(value)))
    keyframes.append("@keyframes %s{%s}" % (name, "".join(frames)))
    animations.setdefault(selector, []).append(
        "%s %.1fs %s infinite" % (name, LOOP, timing)
    )


def opacity(selector, points):
    track(selector, points, lambda v: "opacity:%s" % v)


def translate(selector, points, timing="ease-in-out"):
    track(
        selector,
        points,
        lambda v: "transform:translate(%spx,%spx)" % v,
        timing,
    )


def fade(selector, on, off, duration=0.3):
    """Visible from `on` to `off`, fading `duration` at each end."""
    points = [(on, 0), (on + duration, 1), (off - duration, 1), (off, 0)]
    if on <= 0:
        points = [(0, 1), (off - duration, 1), (off, 0)]
    opacity(selector, points)


def appear(selector, at, until=LOOP, duration=0.25):
    points = [(at, 0), (at + duration, 1)]
    if until < LOOP:
        points += [(until - duration, 1), (until, 0)]
    opacity(selector, points)


def text(x, y, body, fill=INK, size=None, weight=None, anchor=None, cls=None):
    attrs = ['x="%s"' % x, 'y="%s"' % y, 'fill="%s"' % fill]
    if size:
        attrs.append('font-size="%s"' % size)
    if weight:
        attrs.append('font-weight="%s"' % weight)
    if anchor:
        attrs.append('text-anchor="%s"' % anchor)
    if cls:
        attrs.append('class="%s"' % cls)
    # Leading and doubled spaces carry layout; SVG collapses them unless
    # they are non-breaking.
    body = body.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
    stripped = body.lstrip(" ")
    body = "&#160;" * (len(body) - len(stripped)) + stripped
    body = body.replace("  ", "&#160;&#160;")
    return "<text %s>%s</text>" % (" ".join(attrs), body)


def traffic_lights(x, y, radius=6.5, gap=22):
    return "".join(
        '<circle cx="%s" cy="%s" r="%s" fill="%s"/>' % (x + i * gap, y, radius, c)
        for i, c in enumerate(("#ff5f57", "#febc2e", "#28c840"))
    )


POINTER = (
    '<path d="M0 0 l0 22 l5.5 -5 l4 9 l3.5 -1.6 l-4 -8.8 l7.4 -0.4 z" '
    'fill="#fff" stroke="#111" stroke-width="1.2" stroke-linejoin="round"/>'
)

# Newest first, as the shelf lists them: (name, parent folder, shelf icon).
FILES = [
    ("checkout-flow.mp4", "screen-recordings", "\u25b6"),
    ("customer-call.m4a", "interviews", "\u266a"),
    ("meeting-notes.md", "notes", "\u25a5"),
    ("kpi-summary.xlsx", "exports", "\u25c6"),
    ("q3-review.pdf", "reports", "\u25a4"),
    ("revenue-q3.png", "charts", "\u25a3"),
]
CHART, REPORT = 5, 4


def row_y(index):
    return 194 + 46 * index


def build():
    parts = []

    # --- Frame ---------------------------------------------------------
    parts.append('<rect width="1280" height="830" rx="18" fill="#101118"/>')
    parts.append(
        '<g filter="url(#shadow)"><rect x="40" y="24" width="1200" height="700" '
        'rx="14" fill="%s"/></g>' % WINDOW
    )
    parts.append('<g clip-path="url(#window-clip)">')
    parts.append('<rect x="40" y="24" width="1200" height="38" fill="url(#titlebar)"/>')
    parts.append(traffic_lights(64, 43))
    parts.append(text(640, 48, "herdr", fill="#9a9cab", size=13, anchor="middle"))
    parts.append('<rect x="40" y="62" width="1200" height="30" fill="#191a22"/>')
    parts.append('<rect x="52" y="67" width="120" height="22" rx="4" fill="%s"/>' % BLUE)
    parts.append(text(112, 83, "1 q3-review", fill=WINDOW, weight="bold", anchor="middle"))
    parts.append('<rect x="178" y="67" width="60" height="22" rx="4" fill="#262833"/>')
    parts.append(text(208, 83, "2", fill=MUTED, anchor="middle"))

    # Claude pane: full width before the shelf, narrow after.
    parts.append(
        '<rect class="pane-wide" x="54" y="104" width="1172" height="606" rx="6" '
        'fill="none" stroke="#3a3d52"/>'
    )
    parts.append(
        '<rect class="pane-narrow" x="54" y="104" width="920" height="606" rx="6" '
        'fill="none" stroke="#3a3d52"/>'
    )
    parts.append('<rect x="68" y="96" width="60" height="16" fill="%s"/>' % WINDOW)
    parts.append(text(74, 109, "claude", fill=MUTED, size=13))
    opacity(".pane-wide", [(10.5, 1), (10.8, 0)])
    opacity(".pane-narrow", [(10.5, 0), (10.8, 1)])

    # --- Conversation (scrolls away) -----------------------------------
    parts.append('<g clip-path="url(#chat-clip)"><g class="chat">')
    chat = [
        (140, "> 幫我準備季度回顧：圖表、報告、KPI 表都要", SOFT),
        (180, "● 做好了，營收圖、完整報告和 KPI 表：", INK),
        (212, "  SendUserFile  3 files", "#8b8ea3"),
        (326, "> 再附上會議紀錄、客戶訪談和結帳流程的錄影", SOFT),
        (366, "● 好，一併送上：", INK),
        (398, "  SendUserFile  3 files", "#8b8ea3"),
        (512, "訪談第 12 分鐘提到結帳卡關，錄影裡可以看到同一個步驟。", INK),
        (560, "> 報告第 3 頁的數字再核一次", SOFT),
        (600, "● 核對完成，更正兩處：", INK),
        (632, "  營收      100  →  112", INK),
        (660, "  新客數     38  →   45", INK),
        (708, "> 把第 4 季的預估也加進報告", SOFT),
        (748, "● 已加入，報告更新為第 2 版。", INK),
        (796, "> 等等，剛剛那張營收圖再給我看一下，在哪？", SOFT),
    ]
    for y, body, fill in chat:
        parts.append(text(80, y, body, fill=fill))
    # Sent oldest first, in two batches of three.
    sent = list(reversed(FILES))
    line_ys = [238, 262, 286, 424, 448, 472]
    for i, (name, folder, _) in enumerate(sent):
        parts.append(
            text(100, line_ys[i], "› [file] ~/q3-review/%s/%s" % (folder, name), fill=BLUE, cls="fl%d" % i)
        )
        appear(".fl%d" % i, (0.6 if i < 3 else 1.3) + 0.25 * i)
    parts.append("</g></g>")
    translate(".chat", [(4.6, (0, 0)), (5.6, (0, -360))])

    # Hover highlight on the PDF line, and the manual steps it takes to open
    # one file.
    parts.append(
        '<rect class="hover" x="94" y="246" width="440" height="22" rx="3" fill="%s" opacity="0"/>'
        % BLUE
    )
    opacity(".hover", [(3.0, 0), (3.1, 0.18), (4.4, 0.18), (4.5, 0)])
    parts.append('<g class="steps">')
    parts.append(
        '<rect x="590" y="236" width="340" height="150" rx="10" fill="#2b2c33" stroke="#44465a"/>'
    )
    steps = [
        "想打開這個檔案：",
        "1  選取路徑、複製",
        "2  打開 Finder，⌘⇧G 前往",
        "3  貼上路徑，找到檔案",
        "4  按空白鍵預覽",
    ]
    for i, body in enumerate(steps):
        parts.append(
            text(610, 264 + 26 * i, body, fill=AMBER if i == 0 else SOFT, size=14)
        )
    parts.append("</g>")
    fade(".steps", 3.2, 4.5)

    # --- Shelf -----------------------------------------------------------
    parts.append('<g class="shelf">')
    parts.append('<rect x="982" y="100" width="258" height="614" fill="%s"/>' % WINDOW)
    parts.append(
        '<rect x="986" y="104" width="240" height="606" rx="6" fill="none" stroke="%s"/>' % BLUE
    )
    parts.append('<rect x="1000" y="96" width="52" height="16" fill="%s"/>' % WINDOW)
    parts.append(text(1005, 109, "Files", fill=BLUE, size=13))
    parts.append(text(998, 136, "FILES  q3-review", fill=AMBER, weight="bold"))
    parts.append(text(998, 158, "6 file(s)", fill=FAINT))
    for i, (name, folder, icon) in enumerate(FILES):
        y = row_y(i)
        parts.append(
            '<rect class="sel%d" x="992" y="%d" width="228" height="24" fill="%s" opacity="0"/>'
            % (i, y - 17, AMBER)
        )
        parts.append('<g class="row%d">' % i)
        parts.append(text(998, y, " %s %s" % (icon, name), fill=INK))
        parts.append(text(998, y + 20, "   " + folder, fill=FAINT))
        parts.append("</g>")
        appear(".row%d" % i, 11.0 + 0.12 * i)
    parts.append(text(998, 684, "營收圖、完整報告和 KPI 表", fill="#8a8a8a"))
    parts.append('<rect x="992" y="696" width="228" height="22" fill="%s"/>' % AMBER)
    parts.append(text(998, 712, " q close  enter open  j/k", fill="#303030", size=12))
    parts.append("</g>")
    translate(".shelf", [(10.5, (270, 0)), (11.0, (0, 0))], timing="ease-out")
    opacity(".sel%d" % CHART, [(13.1, 0), (13.15, 1), (15.3, 1), (15.35, 0)])
    opacity(".sel%d" % REPORT, [(15.3, 0), (15.35, 1)])

    parts.append("</g>")  # window clip

    # --- Scene B: install ------------------------------------------------
    parts.append('<rect class="dim" x="40" y="24" width="1200" height="700" rx="14" fill="#000"/>')
    opacity(".dim", [(6.0, 0), (6.4, 0.55), (9.6, 0.55), (10.0, 0)])
    parts.append('<g class="install">')
    parts.append(
        '<g filter="url(#shadow-small)"><rect x="300" y="250" width="680" height="170" rx="12" '
        'fill="#15161d" stroke="#44465a"/></g>'
    )
    parts.append(traffic_lights(322, 272, radius=5.5, gap=18))
    parts.append(text(640, 277, "zsh", fill=MUTED, size=12, anchor="middle"))
    parts.append(text(330, 330, "$", fill="#28c840", size=18))
    command = "herdr plugin install Clementtang/herdr-shelf"
    parts.append(text(352, 330, command, fill=INK, size=18))
    # The cover slides right in character steps: a typing effect that needs
    # no per-character elements. 18px monospace advances about 10.8px.
    parts.append(
        '<g clip-path="url(#term-clip)"><rect class="typing" x="350" y="310" '
        'width="480" height="30" fill="#15161d"/></g>'
    )
    parts.append(text(330, 376, "✓ Installed clementtang.herdr-shelf", fill="#28c840", size=18, cls="done"))
    parts.append("</g>")
    fade(".install", 6.4, 9.9)
    track(
        ".typing",
        [(6.9, 0), (8.3, len(command) * 10.8 + 12)],
        lambda v: "transform:translateX(%spx)" % v,
        timing="steps(%d,end)" % len(command),
    )
    appear(".done", 8.7, 9.9)

    # --- Scene C: prefix+f, then clicks ----------------------------------
    parts.append('<g class="keycap">')
    parts.append('<rect x="440" y="560" width="200" height="54" rx="12" fill="#2b2c33" stroke="%s" stroke-width="2"/>' % AMBER)
    parts.append(text(540, 594, "prefix + f", fill=AMBER, size=22, weight="bold", anchor="middle"))
    parts.append("</g>")
    fade(".keycap", 10.1, 11.4)

    # Quick Look window: the chart image first, then the PDF report.
    parts.append('<g class="ql">')
    parts.append(
        '<g filter="url(#shadow-small)"><rect x="540" y="200" width="400" height="300" rx="12" '
        'fill="#2b2c33" stroke="#44465a"/></g>'
    )
    parts.append(traffic_lights(560, 220, radius=5.5, gap=18))
    for index in (CHART, REPORT):
        parts.append(
            text(740, 225, FILES[index][0], fill=SOFT, size=12, anchor="middle", cls="qlt%d" % index)
        )
    parts.append('<line x1="540" y1="238" x2="940" y2="238" stroke="#1d1e24"/>')

    parts.append('<g class="qlc">')
    parts.append('<rect x="556" y="248" width="368" height="238" rx="4" fill="#fbfbfd"/>')
    parts.append(text(576, 276, "Q3 營收（百萬）", fill="#2b2c33", size=13, weight="bold"))
    parts.append('<line x1="590" y1="456" x2="900" y2="456" stroke="#c9ccd6"/>')
    quarters = [("Q4", 82), ("Q1", 91), ("Q2", 100), ("Q3", 112)]
    for i, (label, value) in enumerate(quarters):
        height = value * 1.4
        x = 612 + 72 * i
        fill = BLUE if i == len(quarters) - 1 else "#c3cbf2"
        parts.append(
            '<rect class="cbar" x="%d" y="%.0f" width="44" height="%.0f" rx="3" fill="%s"/>'
            % (x, 456 - height, height, fill)
        )
        parts.append(text(x + 22, 452 - height, str(value), fill="#5d6075", size=11, anchor="middle"))
        parts.append(text(x + 22, 474, label, fill="#5d6075", size=11, anchor="middle"))
    parts.append("</g>")

    parts.append('<g class="qlp">')
    parts.append('<rect x="556" y="248" width="368" height="238" rx="4" fill="#3a3b44"/>')
    parts.append('<rect x="660" y="256" width="160" height="222" fill="#fbfbfd"/>')
    parts.append(text(674, 280, "Q3 季度回顧", fill="#2b2c33", size=12, weight="bold"))
    for i, width in enumerate((128, 112, 124, 90)):
        parts.append('<rect x="674" y="%d" width="%d" height="4" rx="2" fill="#c9ccd6"/>' % (292 + 12 * i, width))
    for i, value in enumerate((82, 91, 100, 112)):
        height = value * 0.5
        parts.append(
            '<rect x="%d" y="%.0f" width="18" height="%.0f" fill="%s"/>'
            % (684 + 28 * i, 400 - height, height, BLUE if i == 3 else "#c3cbf2")
        )
    for i, width in enumerate((128, 100, 118)):
        parts.append('<rect x="674" y="%d" width="%d" height="4" rx="2" fill="#c9ccd6"/>' % (416 + 12 * i, width))
    parts.append(text(912, 478, "1 / 8", fill="#9a9cab", size=11, anchor="end"))
    parts.append("</g>")
    parts.append("</g>")

    track(".ql", [(13.2, 0), (13.5, 1), (16.3, 1), (16.6, 0)], lambda v: "opacity:%s" % v)
    for cls in (".qlt%d" % CHART, ".qlc"):
        opacity(cls, [(15.3, 1), (15.35, 0)])
    for cls in (".qlt%d" % REPORT, ".qlp"):
        opacity(cls, [(15.3, 0), (15.35, 1)])
    track(".cbar", [(13.3, 0), (13.9, 1)], lambda v: "transform:scaleY(%s)" % v, timing="ease-out")

    # Pointer: hover in scene A, clicks in scene C.
    parts.append('<g class="pointer">%s</g>' % POINTER)
    translate(
        ".pointer",
        [
            (0.0, (760, 640)),
            (2.3, (760, 640)),
            (3.0, (420, 254)),
            (4.5, (420, 254)),
            (4.6, (860, 640)),
            (12.1, (860, 640)),
            (12.9, (1150, row_y(CHART) - 12)),
            (14.6, (1150, row_y(CHART) - 12)),
            (15.2, (1150, row_y(REPORT) - 12)),
        ],
    )
    opacity(".pointer", [(2.2, 0), (2.4, 1), (4.4, 1), (4.6, 0), (12.0, 0), (12.2, 1), (16.2, 1), (16.4, 0)])
    for index, at in ((CHART, 13.1), (REPORT, 15.3)):
        cls = "ring%d" % index
        parts.append(
            '<circle class="%s" cx="1150" cy="%d" r="14" fill="none" stroke="%s" stroke-width="2"/>'
            % (cls, row_y(index) - 12, AMBER)
        )
        opacity("." + cls, [(at - 0.01, 0), (at, 1), (at + 0.4, 0)])

    # --- Captions ------------------------------------------------------------
    captions = [
        ("cap1", "Agent 送來的圖表、報告、錄影，要看還得自己去 Finder 找", 0.2, 4.6),
        ("cap2", "對話一長，檔案就捲出畫面了", 4.6, 6.4),
        ("cap3", "一行指令安裝 herdr-shelf", 6.4, 9.9),
        ("cap4", "按 prefix+f，這個 session 送過的檔案全列在側欄", 9.9, 12.9),
        ("cap5", "點一下就開：圖片、PDF、筆記、影音都行", 12.9, 16.7),
    ]
    for cls, body, on, off in captions:
        parts.append(text(640, 782, body, fill=INK, size=22, anchor="middle", cls=cls))
        fade("." + cls, on, off)

    # --- End card (also opens the loop) ----------------------------------
    parts.append('<g class="endcard">')
    parts.append('<rect width="1280" height="830" rx="18" fill="#101118"/>')
    parts.append(text(640, 380, "herdr-shelf", fill=AMBER, size=48, weight="bold", anchor="middle"))
    parts.append(text(640, 430, "Claude Code 送出的檔案，常駐在 herdr 側欄", fill=SOFT, size=22, anchor="middle"))
    parts.append(text(640, 490, "herdr plugin install Clementtang/herdr-shelf", fill=INK, size=18, anchor="middle"))
    parts.append("</g>")
    opacity(".endcard", [(0, 1), (0.4, 0), (16.7, 0), (17.1, 1)])

    style = (
        # On the root, not on `text`: a CSS rule would beat every element's
        # font-size attribute, while an inherited value loses to it.
        "svg{font-family:%s;font-size:14px}"
        ".cbar{transform-box:fill-box;transform-origin:center bottom}"
        "%s%s"
    ) % (
        FONT,
        "".join(keyframes),
        "".join("%s{animation:%s}" % (sel, ",".join(a)) for sel, a in animations.items()),
    )

    defs = (
        "<defs>"
        '<filter id="shadow" x="-10%" y="-10%" width="120%" height="130%">'
        '<feDropShadow dx="0" dy="18" stdDeviation="22" flood-color="#000" flood-opacity="0.5"/></filter>'
        '<filter id="shadow-small" x="-20%" y="-20%" width="140%" height="150%">'
        '<feDropShadow dx="0" dy="10" stdDeviation="14" flood-color="#000" flood-opacity="0.5"/></filter>'
        '<clipPath id="window-clip"><rect x="40" y="24" width="1200" height="700" rx="14"/></clipPath>'
        '<clipPath id="term-clip"><rect x="300" y="250" width="680" height="170" rx="12"/></clipPath>'
        '<clipPath id="chat-clip"><rect x="56" y="114" width="1168" height="516"/></clipPath>'
        '<linearGradient id="titlebar" x1="0" y1="0" x2="0" y2="1">'
        '<stop offset="0" stop-color="#2d2f3b"/><stop offset="1" stop-color="#262833"/></linearGradient>'
        "</defs>"
    )

    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="1280" height="830" viewBox="0 0 1280 830">'
        "<title>herdr-shelf：Agent 送出的圖表、報告、錄影埋在對話裡，安裝後按 prefix+f 就全部列在側欄，點一下開啟</title>"
        "<style>%s</style>%s%s</svg>\n"
    ) % (style, defs, "".join(parts))


if __name__ == "__main__":
    with open(OUT, "w", encoding="utf-8") as handle:
        handle.write(build())
    print(os.path.normpath(OUT))
