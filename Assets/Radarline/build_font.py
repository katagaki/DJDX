import math
import sys
from shapely.geometry import LineString, Polygon, box
from shapely.geometry.polygon import orient
from shapely.ops import unary_union
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen

CAP = 700
SIDE = 70
WEIGHTS = {"Regular": (96, 96), "Medium": (118, 104), "Bold": (142, 112), "Heavy": (168, 120)}
WIDTHS = {"Condensed": 760, "": 940, "Expanded": 1160}
VERTICAL, HORIZONTAL = 1.32, 0.86
NOTCH = 1.05


def strokes(paths, hv, hh, diagonals=()):
    shapes = []
    for pts in paths:
        for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
            shapes.append(box(min(x0, x1) - hv, min(y0, y1) - hh, max(x0, x1) + hv, max(y0, y1) + hh))
    for (x0, y0), (x1, y1), *ends in diagonals:
        ends = ends[0] if ends else "pq"
        length = math.dist((x0, y0), (x1, y1))
        ux, uy = (x1 - x0) / length * hv * 1.6, (y1 - y0) / length * hv * 1.6
        if "p" in ends:
            x0, y0 = x0 - ux, y0 - uy
        if "q" in ends:
            x1, y1 = x1 + ux, y1 + uy
        shapes.append(LineString([(x0, y0), (x1, y1)]).buffer(hv, cap_style=2))
    return unary_union(shapes)


def glyphs(s, w):
    hv, hh = s * VERTICAL / 2, s * HORIZONTAL / 2
    thin = s * 0.78
    dot = s * 1.08

    def frame(width):
        return dict(l=hv, r=width - hv, c=width / 2, b=hh, t=CAP - hh, m=362)

    def make(width, paths, diagonals=(), notch=True, clip=True):
        g = strokes(paths, hv, hh, diagonals)
        if clip:
            g = g.intersection(box(0, 0, width, CAP))
        return g, width, notch

    out = {}
    W, L, I = w, w * 0.84, hv * 2
    f = frame(W)
    l, r, c, b, t, m = f["l"], f["r"], f["c"], f["b"], f["t"], f["m"]
    out["zero"] = make(W, [[(l, b), (l, t), (r, t), (r, b), (l, b)]])
    out["one"] = make(W, [[(c - W * 0.12, t), (c + W * 0.06, t), (c + W * 0.06, b)]])
    out["two"] = make(W, [[(l, t), (r, t), (r, m), (l, m), (l, b), (r, b)]])
    out["three"] = make(W, [[(l, t), (r, t), (r, b), (l, b)], [(l + W * 0.2, m), (r, m)]])
    out["four"] = make(W, [[(l, t), (l, 250), (r, 250)], [(r, t), (r, b)]])
    out["five"] = make(W, [[(r, t), (l, t), (l, m), (r, m), (r, b), (l, b)]])
    out["six"] = make(W, [[(r, t), (l, t), (l, b), (r, b), (r, m), (l, m)]])
    out["seven"] = make(W, [[(l, t - s * 1.15), (l, t), (r, t), (r, b)]])
    out["eight"] = make(W, [[(l, b), (l, t), (r, t), (r, b), (l, b)], [(l, m), (r, m)]])
    out["nine"] = make(W, [[(l, b), (r, b), (r, t), (l, t), (l, m), (r, m)]])

    def letter(width, fn, notch=True):
        f = frame(width)
        paths, diagonals = fn(**f)
        return make(width, paths, diagonals, notch)

    M, Wd = L * 1.3, L * 1.3
    letters = {
        "A": (L, lambda l, r, c, b, t, m: ([[(l, b), (l, t), (r, t), (r, b)], [(l, m), (r, m)]], [])),
        "B": (L, lambda l, r, c, b, t, m: ([[(l, b), (l, t), (r - L * 0.1, t), (r - L * 0.1, m)],
                                            [(l, m), (r, m), (r, b), (l, b)]], [])),
        "C": (L, lambda l, r, c, b, t, m: ([[(r, t), (l, t), (l, b), (r, b)]], [])),
        "D": (L, lambda l, r, c, b, t, m: ([[(l, b), (l, t), (r - L * 0.14, t)], [(l, b), (r - L * 0.14, b)],
                                            [(r, t - L * 0.14), (r, b + L * 0.14)]],
                                           [((r - L * 0.14, t), (r, t - L * 0.14), ""), ((r, b + L * 0.14), (r - L * 0.14, b), "")])),
        "E": (L, lambda l, r, c, b, t, m: ([[(r, t), (l, t), (l, b), (r, b)], [(l, m), (r - L * 0.1, m)]], [])),
        "F": (L, lambda l, r, c, b, t, m: ([[(r, t), (l, t), (l, b)], [(l, m), (r - L * 0.1, m)]], [])),
        "G": (L, lambda l, r, c, b, t, m: ([[(r, t), (l, t), (l, b), (r, b), (r, m - 40), (c + L * 0.04, m - 40)]], [])),
        "H": (L, lambda l, r, c, b, t, m: ([[(l, t), (l, b)], [(r, t), (r, b)], [(l, m), (r, m)]], [])),
        "I": (I, lambda l, r, c, b, t, m: ([[(c, t), (c, b)]], [])),
        "J": (L, lambda l, r, c, b, t, m: ([[(r, t), (r, b), (l, b), (l, b + 200)]], [])),
        "K": (L, lambda l, r, c, b, t, m: ([[(l, t), (l, b)]],
                                           [((l + hv * 0.4, m), (r, CAP), "q"), ((l + L * 0.18, m + 60), (r, 0), "q")])),
        "L": (L, lambda l, r, c, b, t, m: ([[(l, t), (l, b), (r, b)]], [])),
        "M": (M, lambda l, r, c, b, t, m: ([[(l, b), (l, t), (r, t), (r, b)], [(c, t), (c, b + 160)]], [])),
        "N": (L, lambda l, r, c, b, t, m: ([[(l, b), (l, t)], [(r, t), (r, b)]], [((l, CAP), (r, 0))])),
        "O": (L, lambda l, r, c, b, t, m: ([[(l, b), (l, t), (r, t), (r, b), (l, b)]], [])),
        "P": (L, lambda l, r, c, b, t, m: ([[(l, b), (l, t), (r, t), (r, m), (l, m)]], [])),
        "Q": (L, lambda l, r, c, b, t, m: ([[(l, b), (l, t), (r, t), (r, b), (l, b)]], [((c + L * 0.06, 230), (r, 0), "q")])),
        "R": (L, lambda l, r, c, b, t, m: ([[(l, b), (l, t), (r, t), (r, m), (l, m)]], [((c - L * 0.04, m), (r, 0), "q")])),
        "S": (L, lambda l, r, c, b, t, m: ([[(r, t), (l, t), (l, m), (r, m), (r, b), (l, b)]], [])),
        "T": (L, lambda l, r, c, b, t, m: ([[(-hv, t), (L + hv, t)], [(c, t), (c, b)]], [])),
        "U": (L, lambda l, r, c, b, t, m: ([[(l, t), (l, b), (r, b), (r, t)]], [])),
        "V": (L, lambda l, r, c, b, t, m: ([[(l, t), (l, m)], [(r, t), (r, m)]], [((l, m), (c, 0), "q"), ((r, m), (c, 0), "q")])),
        "W": (Wd, lambda l, r, c, b, t, m: ([[(l, t), (l, b), (r, b), (r, t)], [(c, b), (c, t - 160)]], [])),
        "X": (L, lambda l, r, c, b, t, m: ([], [((l, CAP), (r, 0)), ((r, CAP), (l, 0))])),
        "Y": (L, lambda l, r, c, b, t, m: ([[(l, t), (l, m), (r, m), (r, t)], [(c, m), (c, b)]], [])),
        "Z": (L, lambda l, r, c, b, t, m: ([[(l, t), (r, t)], [(l, b), (r, b)]], [((r, t), (l, b))])),
    }
    for name, (width, fn) in letters.items():
        out[name] = letter(width, fn)

    pr = hv * 2 + s * 0.7
    out["parenleft"] = make(pr, [[(pr - hv, t), (l, t), (l, b), (pr - hv, b)]], clip=False)
    out["parenright"] = make(pr, [[(hv, t), (pr - hv, t), (pr - hv, b), (hv, b)]], clip=False, notch=False)
    out["period"] = (box(0, 0, dot, dot), dot, False)
    out["comma"] = (Polygon([(0, dot), (dot, dot), (dot, -10), (dot * 0.35, -150), (0, -150), (dot * 0.4, 0), (0, 0)]), dot, False)
    out["colon"] = (unary_union([box(0, 40, dot, 40 + dot), box(0, 420, dot, 420 + dot)]), dot, False)
    p = 350 + w * 0.3
    bar = p * 0.62
    out["hyphen"] = (box(0, 350 - hh, bar, 350 + hh), bar, False)
    out["plus"] = (unary_union([box(0, 350 - hh, bar, 350 + hh), box(bar / 2 - hh, 350 - bar / 2, bar / 2 + hh, 350 + bar / 2)]), bar, False)
    lean = p * 0.42
    out["slash"] = (Polygon([(0, -60), (thin * 1.1, -60), (lean + thin * 1.1, CAP + 60), (lean, CAP + 60)]), lean + thin * 1.1, False)
    rw, rh, pw = p * 0.5, 300, p * 1.36
    ring = lambda x, y: box(x, y, x + rw, y + rh).difference(box(x + thin, y + thin, x + rw - thin, y + rh - thin))
    d0, d1, dt = pw * 0.26, pw * 0.74, thin * 1.05
    out["percent"] = (unary_union([
        ring(0, CAP - rh), ring(pw - rw, 0),
        Polygon([(d0 - dt / 2, 0), (d0 + dt / 2, 0), (d1 + dt / 2, CAP), (d1 - dt / 2, CAP)]),
    ]), pw, False)
    return out


def contour(pen, ring, bounds, r, notch):
    pts = list(ring.coords)[:-1]
    n = len(pts)
    x0, y0, x1, y1 = bounds
    limit = min(r, 0.4 * min(x1 - x0, y1 - y0))

    def axis(p, q):
        return abs(p[0] - q[0]) < 0.01 or abs(p[1] - q[1]) < 0.01

    def kind(i):
        v = pts[i]
        on_x0, on_x1 = abs(v[0] - x0) < 0.01, abs(v[0] - x1) < 0.01
        on_y0, on_y1 = abs(v[1] - y0) < 0.01, abs(v[1] - y1) < 0.01
        if not ((on_x0 or on_x1) and (on_y0 or on_y1)):
            return None
        if not (axis(v, pts[i - 1]) and axis(v, pts[(i + 1) % n])):
            return None
        return "notch" if notch and on_x0 and on_y1 else "round"

    kinds = [kind(i) for i in range(n)]
    ops = []
    for i, v in enumerate(pts):
        if kinds[i] is None:
            ops.append((v,))
            continue
        size = limit * (NOTCH * 1.6 if kinds[i] == "notch" else 1)
        ends = []
        for j in ((i - 1) % n, (i + 1) % n):
            q = pts[j]
            d = math.dist(v, q)
            size = min(size, d / 2 if kinds[j] else d)
            ends.append((q, d))
        (p, dp), (q, dq) = ends
        a = (v[0] + (p[0] - v[0]) / dp * size, v[1] + (p[1] - v[1]) / dp * size)
        z = (v[0] + (q[0] - v[0]) / dq * size, v[1] + (q[1] - v[1]) / dq * size)
        ops.append((a,))
        ops.append((z,) if kinds[i] == "notch" else (v, z))
    rnd = lambda p: (round(p[0]), round(p[1]))
    pen.moveTo(rnd(ops[0][0]))
    for op in ops[1:]:
        if len(op) == 1:
            pen.lineTo(rnd(op[0]))
        else:
            pen.qCurveTo(rnd(op[0]), rnd(op[1]))
    pen.closePath()


def draw(geom, dx, r, edge, notch):
    pen = TTGlyphPen(None)
    polys = [geom] if geom.geom_type == "Polygon" else [g for g in geom.geoms if g.geom_type == "Polygon"]
    for poly in polys:
        poly = orient(poly.simplify(0.5), sign=-1.0)
        shifted = Polygon([(x + dx, y) for x, y in poly.exterior.coords],
                          [[(x + dx, y) for x, y in hole.coords] for hole in poly.interiors])
        bounds = (geom.bounds[0] + dx, geom.bounds[1], geom.bounds[2] + dx, geom.bounds[3])
        contour(pen, shifted.exterior, bounds, r if edge else 0, notch)
        for hole in shifted.interiors:
            contour(pen, hole, shifted.bounds, 0, False)
    return pen.glyph()


CMAP = {
    0x20: "space", 0xA0: "space", 0x25: "percent", 0x28: "parenleft", 0x29: "parenright", 0x2B: "plus", 0x2C: "comma",
    0x2D: "hyphen", 0x2212: "hyphen", 0x2E: "period", 0x2F: "slash", 0x3A: "colon",
}
for i, name in enumerate("zero one two three four five six seven eight nine".split()):
    CMAP[0x30 + i] = name
for i in range(26):
    CMAP[0x41 + i] = chr(0x41 + i)
    CMAP[0x61 + i] = chr(0x41 + i)


def build(weight, width, path):
    s, r = WEIGHTS[weight]
    w = WIDTHS[width]
    shapes = glyphs(s, w)
    order = [".notdef", "space"] + list(shapes)
    glyf = {".notdef": TTGlyphPen(None).glyph(), "space": TTGlyphPen(None).glyph()}
    metrics = {".notdef": (round(w + SIDE * 2), 0), "space": (round(w * 0.45), 0)}
    for name, (geom, adv, notch) in shapes.items():
        glyf[name] = draw(geom, SIDE, r, name != "slash", notch)
        metrics[name] = (round(adv + SIDE * 2), round(geom.bounds[0] + SIDE))
    style = f"{width} {weight}".strip()
    fb = FontBuilder(1000, isTTF=True)
    fb.setupGlyphOrder(order)
    fb.setupCharacterMap(CMAP)
    fb.setupGlyf(glyf)
    fb.setupHorizontalMetrics(metrics)
    fb.setupHorizontalHeader(ascent=850, descent=-150)
    fb.setupNameTable({"familyName": "Radarline", "styleName": style,
                       "psName": "Radarline-" + style.replace(" ", ""), "fullName": "Radarline " + style,
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
            build(weight, width, f"{out}/Radarline-{(width + weight)}.ttf")
