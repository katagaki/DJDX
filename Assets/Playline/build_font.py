import importlib.util
import math
import sys
from pathlib import Path
from shapely import affinity
from shapely.geometry import LineString, Point, Polygon, box
from shapely.ops import unary_union
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen

_spec = importlib.util.spec_from_file_location(
    "radarline", Path(__file__).resolve().parent.parent / "Radarline" / "build_font.py")
radar = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(radar)

CAP, SIDE = radar.CAP, radar.SIDE
MID = 350


def line(points, width):
    return LineString(points).buffer(width / 2, cap_style=2, join_style=2)


def outline(shape, width):
    return shape.difference(shape.buffer(-width, join_style=2))


def mirror(shape, width):
    return affinity.scale(shape, xfact=-1, origin=(width / 2, 0))


def symbols(s, w, base):
    hv, hh = s * radar.VERTICAL / 2, s * radar.HORIZONTAL / 2
    thin, dot = s * 0.78, s * 1.08
    L, I = w * 0.84, hv * 2
    l, r, c, b, t, m = hv, L - hv, L / 2, hh, CAP - hh, 362
    cap = box(0, 0, L, CAP)
    bar = (350 + w * 0.3) * 0.62
    out = {}

    out["exclam"] = (unary_union([box(0, dot + s * 0.9, I, CAP), box(0, 0, I, dot)]), I, True)
    hook = radar.strokes([[(l, t - s * 1.15), (l, t), (r, t), (r, m), (c, m), (c, dot + s * 0.9 + hh)]], hv, hh)
    out["question"] = (unary_union([hook.intersection(cap), box(c - hv, 0, c + hv, dot)]), L, True)
    out["numbersign"] = (unary_union([
        box(L * 0.3 - thin / 2, 30, L * 0.3 + thin / 2, CAP - 30),
        box(L * 0.7 - thin / 2, 30, L * 0.7 + thin / 2, CAP - 30),
        box(0, 250 - thin / 2, L, 250 + thin / 2), box(0, 450 - thin / 2, L, 450 + thin / 2),
    ]), L, False)
    out["dollar"] = (unary_union([base["S"][0], box(c - thin / 2, -80, c + thin / 2, CAP + 80)]), L, False)
    k = L * 0.2
    amp = radar.strokes([[(r - k, m), (r - k, t), (l + k * 0.5, t), (l + k * 0.5, m)],
                         [(r, m), (l, m), (l, b), (r - k, b), (r - k, m)]], hv, hh)
    out["ampersand"] = (amp.intersection(cap), L, False)
    radius = min(L * 0.42, 210)
    spokes = [line([(radius + radius * math.cos(math.radians(a)), 470 + radius * math.sin(math.radians(a))),
                    (radius - radius * math.cos(math.radians(a)), 470 - radius * math.sin(math.radians(a)))], thin)
              for a in (90, 30, 150)]
    out["asterisk"] = (unary_union(spokes), radius * 2, False)
    out["underscore"] = (box(0, -130, L, -130 + hh * 2), L, False)
    tick = thin * 1.1
    out["quotesingle"] = (box(0, CAP - 230, tick, CAP), tick, False)
    out["quotedbl"] = (unary_union([box(0, CAP - 230, tick, CAP), box(tick * 1.9, CAP - 230, tick * 2.9, CAP)]),
                       tick * 2.9, False)
    aw, ah = thin * 0.45, thin * 0.36
    rung = (CAP - ah * 8) / 3
    low, high = ah * 3 + rung, ah * 5 + rung * 2
    spiral = radar.strokes([[(w - aw, ah), (aw, ah), (aw, CAP - ah), (w - aw, CAP - ah), (w - aw, low),
                             (w * 0.42, low), (w * 0.42, high), (w - aw, high)]], aw, ah)
    out["at"] = (spiral.intersection(box(0, 0, w, CAP)), w, False)
    out["equal"] = (unary_union([box(0, MID + 110 - hh, bar, MID + 110 + hh),
                                 box(0, MID - 110 - hh, bar, MID - 110 + hh)]), bar, False)
    chevron = line([(bar, MID + 230), (thin * 0.7, MID), (bar, MID - 230)], thin).intersection(box(0, 0, bar, CAP))
    out["less"] = (chevron, bar, False)
    out["greater"] = (mirror(chevron, bar), bar, False)
    out["bracketleft"] = base["parenleft"]
    out["bracketright"] = base["parenright"]
    tw = bar * 1.3
    out["asciitilde"] = (radar.strokes([[(thin / 2, 300), (thin / 2, 420), (tw / 2, 420), (tw / 2, 300),
                                         (tw - thin / 2, 300), (tw - thin / 2, 420)]], thin / 2, thin / 2), tw, False)
    out["semicolon"] = (unary_union([box(0, 420, dot, 420 + dot), base["comma"][0]]), dot, False)
    out["asciicircum"] = (line([(0, 400), (bar / 2, CAP - thin * 0.6), (bar, 400)], thin)
                          .intersection(box(0, 400, bar, CAP)), bar, False)
    out["bar"] = (box(0, -60, tick, CAP + 60), tick, False)
    slash, slash_width, _ = base["slash"]
    out["backslash"] = (mirror(slash, slash_width), slash_width, False)

    R = 370
    cx = R * math.cos(math.radians(18))
    star = Polygon([(cx + (R if i % 2 == 0 else R * 0.45) * math.cos(math.radians(90 + 36 * i)),
                     330 + (R if i % 2 == 0 else R * 0.45) * math.sin(math.radians(90 + 36 * i)))
                    for i in range(10)])
    out["blackstar"] = (star, cx * 2, False)
    out["whitestar"] = (outline(star, thin * 0.6), cx * 2, False)

    hw, hd = 230, 170
    flag = lambda x: Polygon([(x, CAP), (x + 200, CAP - 160), (x + 200, CAP - 160 - thin * 1.4), (x, CAP - thin * 1.4)])
    out["eighthnote"] = (unary_union([box(0, 0, hw, hd), box(hw - thin, hd / 2, hw, CAP), flag(hw)]), hw + 200, False)
    gap = 340
    out["beamednotes"] = (unary_union([
        box(0, 0, hw, hd), box(hw - thin, hd / 2, hw, CAP),
        box(gap, 0, gap + hw, hd), box(gap + hw - thin, hd / 2, gap + hw, CAP),
        box(hw - thin, CAP - thin * 1.5, gap + hw, CAP),
    ]), gap + hw, False)

    H = 680
    heart = Polygon([(H / 2, 20), (0, 380), (0, 590), (H * 0.13, 700), (H * 0.37, 700), (H / 2, 590),
                     (H * 0.63, 700), (H * 0.87, 700), (H, 590), (H, 380)])
    out["blackheart"] = (heart, H, False)
    out["whiteheart"] = (outline(heart, thin * 0.85), H, False)

    D = 330
    diamond = Polygon([(D, 10), (D * 2, MID), (D, CAP - 10), (0, MID)])
    out["blackdiamond"] = (diamond, D * 2, False)
    out["whitediamond"] = (outline(diamond, thin * 0.85), D * 2, False)
    circle = Point(D, MID).buffer(D, quad_segs=6)
    out["blackcircle"] = (circle, D * 2, False)
    out["whitecircle"] = (outline(circle, thin * 0.85), D * 2, False)
    out["bullseye"] = (unary_union([outline(circle, thin * 0.85), Point(D, MID).buffer(D * 0.42, quad_segs=6)]),
                       D * 2, False)
    triangle = Polygon([(0, 40), (D * 2, 40), (D, CAP - 40)])
    flipped = affinity.scale(triangle, yfact=-1, origin=(D, MID))
    out["blackuptriangle"] = (triangle, D * 2, False)
    out["whiteuptriangle"] = (outline(triangle, thin * 0.85), D * 2, False)
    out["blackdowntriangle"] = (flipped, D * 2, False)
    out["whitedowntriangle"] = (outline(flipped, thin * 0.85), D * 2, False)
    square = box(0, MID - 310, 620, MID + 310)
    out["blacksquare"] = (square, 620, True)
    out["whitesquare"] = (outline(square, thin * 0.85), 620, True)

    X = 620
    dots = [box(px - dot / 2, py - dot / 2, px + dot / 2, py + dot / 2)
            for px, py in ((X / 2, MID + 250), (X / 2, MID - 250), (dot / 2, MID), (X - dot / 2, MID))]
    cross = unary_union([line([(0, MID + 310), (X, MID - 310)], thin), line([(0, MID - 310), (X, MID + 310)], thin)])
    out["referencemark"] = (unary_union([cross.intersection(box(0, MID - 310, X, MID + 310))] + dots), X, False)

    A = 640
    arrow = unary_union([box(0, MID - hh, A - 120, MID + hh), Polygon([(A - 240, MID + 230), (A, MID), (A - 240, MID - 230)])])
    out["arrowright"] = (arrow, A, False)
    out["arrowleft"] = (mirror(arrow, A), A, False)
    upright = affinity.translate(affinity.rotate(arrow, 90, origin=(A / 2, MID)), xoff=230 - A / 2)
    out["arrowup"] = (upright, 460, False)
    out["arrowdown"] = (affinity.scale(upright, yfact=-1, origin=(230, MID)), 460, False)

    out["middledot"] = (box(0, MID - dot / 2, dot, MID + dot / 2), dot, False)
    out["longbar"] = (box(0, MID - hh, L, MID + hh), L, False)
    return out


SYMBOLS = {
    0x21: "exclam", 0x22: "quotedbl", 0x23: "numbersign", 0x24: "dollar", 0x26: "ampersand", 0x27: "quotesingle",
    0x2A: "asterisk", 0x3B: "semicolon", 0x3C: "less", 0x3D: "equal", 0x3E: "greater", 0x3F: "question",
    0x40: "at", 0x5B: "bracketleft", 0x5C: "backslash", 0x5D: "bracketright", 0x5E: "asciicircum",
    0x5F: "underscore", 0x7C: "bar", 0x7E: "asciitilde",
    0x2018: "quotesingle", 0x2019: "quotesingle", 0x201C: "quotedbl", 0x201D: "quotedbl",
    0x2190: "arrowleft", 0x2191: "arrowup", 0x2192: "arrowright", 0x2193: "arrowdown",
    0x25A0: "blacksquare", 0x25A1: "whitesquare", 0x25B2: "blackuptriangle", 0x25B3: "whiteuptriangle",
    0x25BC: "blackdowntriangle", 0x25BD: "whitedowntriangle", 0x25C6: "blackdiamond", 0x25C7: "whitediamond",
    0x25CB: "whitecircle", 0x25CE: "bullseye", 0x25CF: "blackcircle",
    0x2605: "blackstar", 0x2606: "whitestar", 0x2B50: "whitestar", 0x2729: "whitestar",
    0x2661: "whiteheart", 0x2665: "blackheart", 0x2764: "blackheart",
    0x266A: "eighthnote", 0x266B: "beamednotes", 0x266C: "beamednotes",
    0x203B: "referencemark", 0x00B7: "middledot", 0x2022: "middledot", 0x30FB: "middledot",
    0x30FC: "longbar", 0x2015: "longbar", 0x301C: "asciitilde", 0x3000: "space",
}
TEXT_PRESENTATION = [0x2B50, 0x2605, 0x2606, 0x2729, 0x2661, 0x2665, 0x2764, 0x266A, 0x266B, 0x25A0, 0x25A1, 0x25CF]


def character_map():
    cmap = dict(radar.CMAP)
    cmap.update(SYMBOLS)
    for code in range(0x21, 0x7F):
        if code in cmap:
            cmap[code + 0xFEE0] = cmap[code]
    return cmap


def build(weight, width, path):
    s, r = radar.WEIGHTS[weight]
    w = radar.WIDTHS[width]
    shapes = radar.glyphs(s, w)
    extra = symbols(s, w, shapes)
    reused = {"bracketleft": "parenleft", "bracketright": "parenright"}
    for name, shape in extra.items():
        if name not in reused:
            shapes[name] = shape
    cmap = {code: reused.get(name, name) for code, name in character_map().items()}
    order = [".notdef", "space"] + list(shapes)
    glyf = {".notdef": TTGlyphPen(None).glyph(), "space": TTGlyphPen(None).glyph()}
    metrics = {".notdef": (round(w + SIDE * 2), 0), "space": (round(w * 0.45), 0)}
    for name, (geom, adv, notch) in shapes.items():
        glyf[name] = radar.draw(geom, SIDE, r, name not in ("slash", "backslash"), notch)
        metrics[name] = (round(adv + SIDE * 2), round(geom.bounds[0] + SIDE))
    style = f"{width} {weight}".strip()
    fb = FontBuilder(1000, isTTF=True)
    fb.setupGlyphOrder(order)
    fb.setupCharacterMap(cmap, uvs=[(code, 0xFE0E, None) for code in TEXT_PRESENTATION])
    fb.setupGlyf(glyf)
    fb.setupHorizontalMetrics(metrics)
    fb.setupHorizontalHeader(ascent=850, descent=-150)
    fb.setupNameTable({"familyName": "Playline", "styleName": style,
                       "psName": "Playline-" + style.replace(" ", ""), "fullName": "Playline " + style,
                       "version": "Version 1.000"})
    fb.setupOS2(sTypoAscender=850, sTypoDescender=-150, sTypoLineGap=0, usWinAscent=850, usWinDescent=150,
                sCapHeight=CAP, sxHeight=CAP,
                usWeightClass={"Regular": 400, "Medium": 500, "Bold": 700, "Heavy": 800}[weight],
                usWidthClass={"Condensed": 3, "": 5, "Expanded": 7}[width])
    fb.setupPost()
    fb.save(path)


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    for width in radar.WIDTHS:
        for weight in radar.WEIGHTS:
            build(weight, width, f"{out}/Playline-{(width + weight)}.ttf")
