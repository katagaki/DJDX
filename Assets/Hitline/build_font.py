from shapely.geometry import LineString, Polygon, box
from shapely.ops import unary_union
from shapely.geometry.polygon import orient
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen

S = 165
H = S / 2
CAP = 700
SIDE = 10
CHAMFER = 72
SLIT_Y, SLIT_H = 215, 20
SLITS = False
MID = 392.3


def glyph(width, strokes, slit=True, clip=True, extra=None, flat=None, square=False):
    l, r, c = H, width - H, width / 2
    b, t, m = H, CAP - H, MID
    env = dict(l=l, r=r, c=c, b=b, t=t, m=m, W=width)
    shapes = []
    for pts in strokes(**env):
        line = LineString(pts)
        diag = any(p[0] != q[0] and p[1] != q[1] for p, q in zip(pts, pts[1:]))
        shapes.append(line.buffer(H, cap_style=2 if diag else 3, join_style=2, mitre_limit=3))
    g = unary_union(shapes)
    if clip:
        g = g.intersection(box(0, 0, width, CAP))
    if extra:
        g = unary_union([g] + extra(**env))
    if not square:
        g = g.buffer(-CHAMFER, join_style=2).buffer(CHAMFER, join_style=3)
    if flat:
        g = unary_union([g] + flat(**env))
    if slit:
        g = g.difference(box(-50, SLIT_Y, width + 50, SLIT_Y + SLIT_H))
    return g, width


N, WD = 462, 598
G = {
    "A": (N, lambda l, r, c, b, t, m, W: [[(l, -H), (l, t), (r, t), (r, -H)], [(l, m), (r, m)]]),
    "B": (N, lambda l, r, c, b, t, m, W: []),
    "C": (N, lambda l, r, c, b, t, m, W: [[(r, t), (l, t), (l, b), (r, b)]]),
    "D": (N, lambda l, r, c, b, t, m, W: []),
    "E": (N, lambda l, r, c, b, t, m, W: [[(r, t), (l, t), (l, b), (r, b)], [(l, m), (r - 50, m)]]),
    "F": (N, lambda l, r, c, b, t, m, W: [[(r, t), (l, t), (l, -H)], [(l, m), (r - 50, m)]]),
    "G": (N, lambda l, r, c, b, t, m, W: [[(r, t), (l, t), (l, b), (r, b), (r, m - 10), (c + 60, m - 10)]]),
    "H": (N, lambda l, r, c, b, t, m, W: [[(l, CAP), (l, -H)], [(r, CAP), (r, -H)], [(l, m), (r, m)]]),
    "I": (S, lambda l, r, c, b, t, m, W: [[(c, CAP), (c, -H)]]),
    "J": (N, lambda l, r, c, b, t, m, W: [[(r, CAP), (r, b), (l, b), (l, b + 160)]]),
    "K": (N, lambda l, r, c, b, t, m, W: [[(l, CAP), (l, -H)], [(l, m), (c - 20, m), (r + 40, CAP + 40)], [(c - 20, m), (r + 40, -40)]]),
    "L": (N, lambda l, r, c, b, t, m, W: [[(l, CAP), (l, b), (r, b)]]),
    "M": (WD, lambda l, r, c, b, t, m, W: [[(l, -H), (l, t), (r, t), (r, -H)], [(c, t), (c, b + 110)]]),
    "N": (N, lambda l, r, c, b, t, m, W: [[(l, -H), (l, t), (r - 110, t), (r, t - 110), (r, -H)]]),
    "O": (N, lambda l, r, c, b, t, m, W: [[(l, b), (l, t), (r, t), (r, b), (l, b)]]),
    "P": (N, lambda l, r, c, b, t, m, W: []),
    "Q": (N, lambda l, r, c, b, t, m, W: []),
    "R": (N, lambda l, r, c, b, t, m, W: []),
    "S": (N, lambda l, r, c, b, t, m, W: [[(r, t), (l, t), (l, m), (r, m), (r, b), (l, b)]]),
    "T": (N, lambda l, r, c, b, t, m, W: [[(-H, t), (W + H, t)], [(c, t), (c, -H)]]),
    "U": (N, lambda l, r, c, b, t, m, W: [[(l, CAP), (l, b), (r, b), (r, CAP)]]),
    "V": (N, lambda l, r, c, b, t, m, W: [[(l, CAP), (l, m - 30), (c, b), (r, m - 30), (r, CAP)]]),
    "W": (WD, lambda l, r, c, b, t, m, W: [[(l, CAP), (l, b), (r, b), (r, CAP)], [(c, b), (c, t - 110)]]),
    "X": (N, lambda l, r, c, b, t, m, W: [[(l - 30, CAP + 60), (r + 30, -60)], [(r + 30, CAP + 60), (l - 30, -60)]]),
    "Y": (N, lambda l, r, c, b, t, m, W: [[(l, CAP), (l, m), (r, m), (r, CAP)], [(c, m), (c, -H)]]),
    "Z": (N, lambda l, r, c, b, t, m, W: [[(l, t), (r, t), (r, t - 40), (l, b + 40), (l, b), (r, b)]]),
    "0": (N, lambda l, r, c, b, t, m, W: [[(l, b), (l, t), (r, t), (r, b), (l, b)]]),
    "1": (254, lambda l, r, c, b, t, m, W: [[(l, t), (r, t), (r, -H)]]),
    "2": (N, lambda l, r, c, b, t, m, W: [[(l, t), (r, t), (r, m), (l, m), (l, b), (r, b)]]),
    "3": (N, lambda l, r, c, b, t, m, W: [[(l, t), (r, t), (r, b), (l, b)], [(l + 70, m), (r, m)]]),
    "4": (N, lambda l, r, c, b, t, m, W: []),
    "5": (N, lambda l, r, c, b, t, m, W: [[(r, t), (l, t), (l, m), (r - 90, m), (r, m - 90), (r, b), (l, b)]]),
    "6": (N, lambda l, r, c, b, t, m, W: []),
    "7": (N, lambda l, r, c, b, t, m, W: [[(l, t - 130), (l, t), (r, t), (r, -H)]]),
    "8": (N, lambda l, r, c, b, t, m, W: [[(l, b), (l, t), (r, t), (r, b), (l, b)], [(l, m), (r, m)]]),
    "9": (N, lambda l, r, c, b, t, m, W: []),
    "!": (S, lambda l, r, c, b, t, m, W: [[(c, CAP), (c, 300)], [(c, H), (c, H + 1)]]),
    ".": (S, lambda l, r, c, b, t, m, W: [[(c, H), (c, H + 1)]]),
    "-": (300, lambda l, r, c, b, t, m, W: [[(-H, m), (W + H, m)]]),
    "%": (N + 60, lambda l, r, c, b, t, m, W: [[(H - 20, t), (H + 60, t)], [(W - H - 60, b), (W - H + 20, b)], [(-20, -60), (W + 20, CAP + 60)]]),
}

NINE = [
    (72, 700), (390, 700), (462, 628), (462, 72), (390, 0), (80, 0), (80, 165), (297, 165),
    (297, 535), (165, 535), (165, 375), (277, 375), (277, 210), (72, 210), (0, 282), (0, 628),
]
SIX = [(462 - x, CAP - y) for x, y in NINE]

OPTIONS = {
    "A": dict(flat=lambda l, r, c, b, t, m, W: [box(l - H, 0, l + H, 120), box(r - H, 0, r + H, 120)]),
    "B": dict(square=True, flat=lambda l, r, c, b, t, m, W: [Polygon([
        (0, 700), (390, 700), (462, 628), (462, 440), (372, 350), (462, 262), (462, 72),
        (390, 0), (0, 0), (0, 525), (165, 525), (165, 375), (297, 470), (297, 545), (0, 545),
    ], [[(165, 320), (297, 225), (297, 125), (165, 125)]])]),
    "D": dict(square=True, flat=lambda l, r, c, b, t, m, W: [Polygon([
        (0, 700), (390, 700), (462, 628), (462, 72), (390, 0), (0, 0),
        (0, 525), (165, 525), (165, 165), (297, 165), (297, 545), (0, 545),
    ])]),
    "E": dict(flat=lambda l, r, c, b, t, m, W: [
        box(W - 100, t - H, W, t + H),
        box(W - 150, m - H, W - 50, m + H),
        box(W - 100, b - H, W, b + H),
    ]),
    "F": dict(flat=lambda l, r, c, b, t, m, W: [
        box(W - 100, t - H, W, t + H),
        box(W - 150, m - H, W - 50, m + H),
        box(l - H, 0, l + H, 120),
    ]),
    "G": dict(flat=lambda l, r, c, b, t, m, W: [box(c + 60 - H, m - 10 - H, c + 60 + H, m - 10 + H)]),
    "H": dict(square=True),
    "I": dict(square=True),
    "J": dict(flat=lambda l, r, c, b, t, m, W: [
        box(r - H, CAP - 120, r + H, CAP),
        box(l - H, b + 160 + H - 120, l + H, b + 160 + H),
    ]),
    "K": dict(square=True),
    "L": dict(flat=lambda l, r, c, b, t, m, W: [
        box(W - 100, b - H, W, b + H),
        box(l - H, CAP - 120, l + H, CAP),
    ]),
    "M": dict(flat=lambda l, r, c, b, t, m, W: [
        box(l - H, 0, l + H, 120),
        box(r - H, 0, r + H, 120),
        box(c - H, b + 110 - H, c + H, b + 230 - H),
    ]),
    "N": dict(flat=lambda l, r, c, b, t, m, W: [box(l - H, 0, l + H, 120), box(r - H, 0, r + H, 120)]),
    "P": dict(square=True, flat=lambda l, r, c, b, t, m, W: [Polygon([
        (0, 700), (390, 700), (462, 628), (462, 222), (390, 150), (165, 150), (165, 0), (0, 0),
        (0, 525), (165, 525), (165, 315), (297, 315), (297, 545), (0, 545),
    ])]),
    "Q": dict(square=True, flat=lambda l, r, c, b, t, m, W: [Polygon([
        (72, 700), (390, 700), (462, 628), (462, 0), (297, 0), (297, 535), (165, 535),
        (165, 275), (277, 275), (277, 110), (72, 110), (0, 182), (0, 628),
    ])]),
    "R": dict(square=True, flat=lambda l, r, c, b, t, m, W: [Polygon([
        (0, 700), (390, 700), (462, 628), (462, 440), (372, 350), (462, 262), (462, 0),
        (297, 0), (297, 225), (165, 320), (165, 0), (0, 0), (0, 525), (165, 525),
        (165, 375), (297, 470), (297, 545), (0, 545),
    ])]),
    "S": dict(flat=lambda l, r, c, b, t, m, W: [
        box(W - 100, t - H, W, t + H),
        box(0, b - H, 100, b + H),
    ]),
    "T": dict(square=True),
    "U": dict(flat=lambda l, r, c, b, t, m, W: [
        box(l - H, CAP - 120, l + H, CAP),
        box(r - H, CAP - 120, r + H, CAP),
    ]),
    "V": dict(flat=lambda l, r, c, b, t, m, W: [
        box(l - H, CAP - 120, l + H, CAP),
        box(r - H, CAP - 120, r + H, CAP),
    ]),
    "W": dict(flat=lambda l, r, c, b, t, m, W: [
        box(l - H, CAP - 120, l + H, CAP),
        box(r - H, CAP - 120, r + H, CAP),
        box(c - H, t - 110 + H - 120, c + H, t - 110 + H),
    ]),
    "X": dict(square=True),
    "Y": dict(flat=lambda l, r, c, b, t, m, W: [
        box(l - H, CAP - 120, l + H, CAP),
        box(r - H, CAP - 120, r + H, CAP),
        box(c - H, 0, c + H, 120),
    ]),
    "6": dict(square=True, flat=lambda l, r, c, b, t, m, W: [Polygon(SIX)]),
    "7": dict(flat=lambda l, r, c, b, t, m, W: [
        box(l - H, t - 130 - H, l + H, t - 10 - H),
        box(r - H, 0, r + H, 120),
    ]),
    "9": dict(square=True, flat=lambda l, r, c, b, t, m, W: [Polygon(NINE)]),
    "Z": dict(flat=lambda l, r, c, b, t, m, W: [box(0, t - H, W, t + H), box(0, b - H, W, b + H)]),
    "1": dict(square=True),
    "2": dict(flat=lambda l, r, c, b, t, m, W: [
        box(0, t - H, 100, t + H),
        box(W - 100, b - H, W, b + H),
    ]),
    "3": dict(flat=lambda l, r, c, b, t, m, W: [
        box(0, t - H, 100, t + H),
        box(l + 70 - H, m - H, l + 170 - H, m + H),
        box(0, b - H, 100, b + H),
    ]),
    "4": dict(square=True, flat=lambda l, r, c, b, t, m, W: [Polygon([
        (0, 700), (165, 700), (165, 315), (297, 315), (297, 700), (462, 700), (462, 0),
        (297, 0), (297, 150), (72, 150), (0, 222),
    ])]),
    "5": dict(flat=lambda l, r, c, b, t, m, W: [
        box(r - 100, t - H, W, t + H),
        box(0, CAP - 120, 120, CAP),
        box(0, b - H, l + 100, b + H),
    ]),
}

NAMES = {".": "period", "!": "exclam", "-": "hyphen", "%": "percent"}
for d, n in zip("0123456789", "zero one two three four five six seven eight nine".split()):
    NAMES[d] = n


def draw(geom, dx):
    pen = TTGlyphPen(None)
    polys = [geom] if geom.geom_type == "Polygon" else list(geom.geoms)
    for p in polys:
        if p.area < 1:
            continue
        p = orient(p, sign=-1.0)
        for ring in [p.exterior, *p.interiors]:
            pts = [(round(x + dx), round(y)) for x, y in list(ring.coords)[:-1]]
            pen.moveTo(pts[0])
            for pt in pts[1:]:
                pen.lineTo(pt)
            pen.closePath()
    return pen.glyph()


order = [".notdef", "space"]
glyphs, metrics, cmap = {}, {}, {32: "space"}
glyphs[".notdef"] = draw(box(0, 0, 400, CAP).difference(box(60, 60, 340, CAP - 60)), SIDE)
metrics[".notdef"] = (460, SIDE)
glyphs["space"] = TTGlyphPen(None).glyph()
metrics["space"] = (260, 0)

for ch, (w, fn) in G.items():
    name = NAMES.get(ch, ch)
    geom, width = glyph(w, fn, slit=SLITS and ch not in ".-!", **OPTIONS.get(ch, {}))
    glyphs[name] = draw(geom, SIDE)
    metrics[name] = (int(width + 2 * SIDE), SIDE)
    order.append(name)
    cmap[ord(ch)] = name
    if ch.isalpha():
        cmap[ord(ch.lower())] = name

fb = FontBuilder(1000, isTTF=True)
fb.setupGlyphOrder(order)
fb.setupCharacterMap(cmap)
fb.setupGlyf(glyphs)
fb.setupHorizontalMetrics(metrics)
fb.setupHorizontalHeader(ascent=850, descent=-150)
fb.setupNameTable({
    "familyName": "Hitline",
    "styleName": "Black",
    "uniqueFontIdentifier": "Hitline-Black",
    "fullName": "Hitline Black",
    "version": "Version 1.000",
    "psName": "Hitline-Black",
})
fb.setupOS2(sTypoAscender=850, sTypoDescender=-150, usWinAscent=850, usWinDescent=150, sCapHeight=CAP, usWeightClass=900)
fb.setupPost()
fb.save("Hitline-Black.ttf")
fb.font.flavor = "woff2"
fb.font.save("Hitline-Black.woff2")
print("built", len(order), "glyphs")
