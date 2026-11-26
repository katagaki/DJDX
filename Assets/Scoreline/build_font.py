import math
import sys
from shapely.geometry import Polygon, box
from shapely.geometry.polygon import orient
from shapely.ops import unary_union
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen

CAP = 700
SIDE = 85
WEIGHTS = {"Regular": (96, 96), "Medium": (118, 104), "Bold": (142, 112), "Heavy": (168, 120)}
WIDTHS = {"Condensed": 820, "": 1040, "Expanded": 1280}


VERTICAL, HORIZONTAL = 1.32, 0.86


def strokes(paths, hv, hh):
    boxes = []
    for pts in paths:
        for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
            boxes.append(box(min(x0, x1) - hv, min(y0, y1) - hh, max(x0, x1) + hv, max(y0, y1) + hh))
    return unary_union(boxes)


def glyphs(s, w, r):
    hv, hh = s * VERTICAL / 2, s * HORIZONTAL / 2
    l, rt, c = hv, w - hv, w / 2
    b, t, m = hh, CAP - hh, 362
    thin = s * 0.78
    dot = s * 1.08
    digits = {
        "zero": [[(l, b), (l, t), (rt, t), (rt, b), (l, b)]],
        "one": [[(c - w * 0.12, t), (c + w * 0.06, t), (c + w * 0.06, b)]],
        "two": [[(l, t), (rt, t), (rt, m), (l, m), (l, b), (rt, b)]],
        "three": [[(l, t), (rt, t), (rt, b), (l, b)], [(l + w * 0.2, m), (rt, m)]],
        "four": [[(l, t), (l, 250), (rt, 250)], [(rt, t), (rt, b)]],
        "five": [[(rt, t), (l, t), (l, m), (rt, m), (rt, b), (l, b)]],
        "six": [[(rt, t), (l, t), (l, b), (rt, b), (rt, m), (l, m)]],
        "seven": [[(l, t - s * 1.15), (l, t), (rt, t), (rt, b)]],
        "eight": [[(l, b), (l, t), (rt, t), (rt, b), (l, b)], [(l, m), (rt, m)]],
        "nine": [[(l, b), (rt, b), (rt, t), (l, t), (l, m), (rt, m)]],
    }
    out = {name: (strokes(paths, hv, hh), w) for name, paths in digits.items()}

    pr = hv * 2 + s * 0.7
    out["parenleft"] = (strokes([[(pr - hv, t), (l, t), (l, b), (pr - hv, b)]], hv, hh), pr)
    out["parenright"] = (strokes([[(hv, t), (pr - hv, t), (pr - hv, b), (hv, b)]], hv, hh), pr)
    out["period"] = (box(0, 0, dot, dot), dot)
    out["comma"] = (Polygon([(0, dot), (dot, dot), (dot, -10), (dot * 0.35, -150), (0, -150), (dot * 0.4, 0), (0, 0)]), dot)
    out["colon"] = (unary_union([box(0, 40, dot, 40 + dot), box(0, 420, dot, 420 + dot)]), dot)
    p = 350 + w * 0.3
    bar = p * 0.62
    out["hyphen"] = (box(0, 350 - hh, bar, 350 + hh), bar)
    out["plus"] = (unary_union([box(0, 350 - hh, bar, 350 + hh), box(bar / 2 - hh, 350 - bar / 2, bar / 2 + hh, 350 + bar / 2)]), bar)
    lean = p * 0.42
    out["slash"] = (Polygon([(0, -60), (thin * 1.1, -60), (lean + thin * 1.1, CAP + 60), (lean, CAP + 60)]), lean + thin * 1.1)
    rw, rh, pw = p * 0.5, 300, p * 1.36
    ring = lambda x, y: box(x, y, x + rw, y + rh).difference(box(x + thin, y + thin, x + rw - thin, y + rh - thin))
    d0, d1, dt = pw * 0.26, pw * 0.74, thin * 1.05
    out["percent"] = (unary_union([
        ring(0, CAP - rh), ring(pw - rw, 0),
        Polygon([(d0 - dt / 2, 0), (d0 + dt / 2, 0), (d1 + dt / 2, CAP), (d1 - dt / 2, CAP)]),
    ]), pw)
    return out


def contour(pen, ring, bounds, r):
    pts = list(ring.coords)[:-1]
    n = len(pts)
    x0, y0, x1, y1 = bounds
    limit = min(r, 0.4 * min(x1 - x0, y1 - y0))

    def axis(p, q):
        return abs(p[0] - q[0]) < 0.01 or abs(p[1] - q[1]) < 0.01

    def rounded(i):
        v = pts[i]
        corner = (abs(v[0] - x0) < 0.01 or abs(v[0] - x1) < 0.01) and (abs(v[1] - y0) < 0.01 or abs(v[1] - y1) < 0.01)
        return corner and axis(v, pts[i - 1]) and axis(v, pts[(i + 1) % n])

    flags = [rounded(i) for i in range(n)]
    ops = []
    for i, v in enumerate(pts):
        if not flags[i]:
            ops.append((v,))
            continue
        radius = limit
        ends = []
        for j in ((i - 1) % n, (i + 1) % n):
            q = pts[j]
            d = math.dist(v, q)
            radius = min(radius, d / 2 if flags[j] else d)
            ends.append((q, d))
        (p, dp), (q, dq) = ends
        a = (v[0] + (p[0] - v[0]) / dp * radius, v[1] + (p[1] - v[1]) / dp * radius)
        z = (v[0] + (q[0] - v[0]) / dq * radius, v[1] + (q[1] - v[1]) / dq * radius)
        ops.append((a,))
        ops.append((v, z))
    rnd = lambda p: (round(p[0]), round(p[1]))
    pen.moveTo(rnd(ops[0][0]))
    for op in ops[1:]:
        if len(op) == 1:
            pen.lineTo(rnd(op[0]))
        else:
            pen.qCurveTo(rnd(op[0]), rnd(op[1]))
    pen.closePath()


def draw(geom, dx, r, edge):
    pen = TTGlyphPen(None)
    for poly in ([geom] if geom.geom_type == "Polygon" else list(geom.geoms)):
        poly = orient(poly, sign=-1.0)
        shifted = Polygon([(x + dx, y) for x, y in poly.exterior.coords],
                          [[(x + dx, y) for x, y in hole.coords] for hole in poly.interiors])
        contour(pen, shifted.exterior, shifted.bounds, r if edge else 0)
        for hole in shifted.interiors:
            contour(pen, hole, shifted.bounds, 0)
    return pen.glyph()


CMAP = {
    0x20: "space", 0xA0: "space", 0x25: "percent", 0x28: "parenleft", 0x29: "parenright", 0x2B: "plus", 0x2C: "comma", 0x2D: "hyphen",
    0x2212: "hyphen", 0x2E: "period", 0x2F: "slash", 0x3A: "colon",
}
for i, name in enumerate("zero one two three four five six seven eight nine".split()):
    CMAP[0x30 + i] = name


def build(weight, width, path):
    s, r = WEIGHTS[weight]
    w = WIDTHS[width]
    shapes = glyphs(s, w, r)
    order = [".notdef", "space"] + list(shapes)
    glyf = {".notdef": TTGlyphPen(None).glyph(), "space": TTGlyphPen(None).glyph()}
    metrics = {".notdef": (w + SIDE * 2, 0), "space": (round(w * 0.5), 0)}
    for name, (geom, adv) in shapes.items():
        glyf[name] = draw(geom, SIDE, r, name != "slash")
        metrics[name] = (round(adv + SIDE * 2), round(geom.bounds[0] + SIDE))
    style = f"{width} {weight}".strip()
    fb = FontBuilder(1000, isTTF=True)
    fb.setupGlyphOrder(order)
    fb.setupCharacterMap(CMAP)
    fb.setupGlyf(glyf)
    fb.setupHorizontalMetrics(metrics)
    fb.setupHorizontalHeader(ascent=850, descent=-150)
    fb.setupNameTable({"familyName": "Scoreline", "styleName": style,
                       "psName": "Scoreline-" + style.replace(" ", ""), "fullName": "Scoreline " + style,
                       "version": "Version 1.000"})
    fb.setupOS2(sTypoAscender=850, sTypoDescender=-150, sTypoLineGap=0, usWinAscent=850, usWinDescent=150,
                sCapHeight=CAP, sxHeight=CAP, usWeightClass={"Regular": 400, "Medium": 500, "Bold": 700, "Heavy": 800}[weight],
                usWidthClass={"Condensed": 3, "": 5, "Expanded": 7}[width])
    fb.setupPost()
    fb.save(path)


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    for width in WIDTHS:
        for weight in WEIGHTS:
            build(weight, width, f"{out}/Scoreline-{(width + weight)}.ttf")
