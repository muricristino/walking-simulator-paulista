import math, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rc_lib import *

k = Kit()
S0, S1 = 143.5, 407.0
RW = 4.4
SW = 8.2
CURB = 0.17


def road(s, t):
    return gy(s, 0.0) + 0.03


def walk(s, t):
    return gy(s, 0.0) + CURB


strip(k, "asphalt", 133.5, 404.0, -RW, RW, road, step=6.0, tile=(4.0, 4.0))
strip(k, "asphalt", 404.0, 411.5, -RW, RW, lambda s, t: gy(s, 0.0), step=2.5, tile=(4.0, 4.0))


def cross_street(name, J, half, lim, skip_road, skip_walk, walk_sides, walkw=3.0):
    pts = [tuple(q["p"]) for q in [c for c in DATA["cross"] if c["name"] == name][0]["pts"]]
    cum = [0.0]
    for a, b in zip(pts, pts[1:]):
        cum.append(cum[-1] + math.dist(a, b))

    def at(u):
        u = min(max(u, 0.0), cum[-1] - 0.01)
        i = 0
        while i < len(pts) - 2 and cum[i + 1] < u:
            i += 1
        L = max(cum[i + 1] - cum[i], 0.001)
        f = (u - cum[i]) / L
        a, b = pts[i], pts[i + 1]
        return (a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f), ((b[0] - a[0]) / L, (b[1] - a[1]) / L)

    best = None
    for i in range(int(cum[-1] * 2)):
        p, _ = at(i / 2)
        d = math.dist(p, J)
        if best is None or d < best[0]:
            best = (d, i / 2)
    u0 = best[1]
    out = []
    u = max(0.0, u0 - lim)
    while u < min(cum[-1], u0 + lim) - 0.5:
        ub = min(u + 4.0, cum[-1], u0 + lim)
        (pa, da), (pb, db) = at(u), at(ub)
        na, nb = (-da[1], da[0]), (-db[1], db[0])
        mid = abs((u + ub) / 2 - u0)

        def q(p, n, o, lift):
            x, z = p[0] + n[0] * o, p[1] + n[1] * o
            return (x, street_y(x, z) + lift, z)

        if mid > skip_road:
            k.poly("asphalt", [q(pa, na, -half, 0.03), q(pb, nb, -half, 0.03), q(pb, nb, half, 0.03), q(pa, na, half, 0.03)], [(u / 4, -half / 4), (ub / 4, -half / 4), (ub / 4, half / 4), (u / 4, half / 4)], "floor")
        for sd in walk_sides:
            sk = skip_walk[0] if sd > 0 else skip_walk[1]
            if mid > sk:
                o0, o1 = sd * half, sd * (half + walkw)
                k.poly("sidewalk", [q(pa, na, o0, CURB), q(pb, nb, o0, CURB), q(pb, nb, o1, CURB), q(pa, na, o1, CURB)], [(u / 2, o0 / 2), (ub / 2, o0 / 2), (ub / 2, o1 / 2), (u / 2, o1 / 2)], "floor")
                k.poly("curb", [q(pa, na, o0, 0.03), q(pb, nb, o0, 0.03), q(pb, nb, o0, CURB), q(pa, na, o0, CURB)], [(0, 0), (1, 0), (1, 1), (0, 1)])
                out.append((pa, na, o1, sd))
        u = ub
    return out, at, u0


sc_edge, sc_at, sc_u0 = cross_street("Rua São Carlos do Pinhal", frame(138.6, 0), 4.8, 70.0, 4.4, (10.5, 10.5), (1, -1))
JP = frame(414.0, 0)
pm_pts = [tuple(q["p"]) for q in [c for c in DATA["cross"] if c["name"] == "Rua Pamplona"][0]["pts"]]
probe = frame(395.0, 0)
pm_edge, pm_at, pm_u0 = cross_street("Rua Pamplona", JP, 5.5, 150.0, 0.0, (9.5, 9.5), (1, -1), 3.5)
p0, d0 = pm_at(pm_u0)
rio_side = 1 if ((probe[0] - p0[0]) * -d0[1] + (probe[1] - p0[1]) * d0[0]) > 0 else -1
for idx, tex in ((112, "res_white"), (114, "res_cream"), (119, "res_beige"), (109, "res_white"), (110, "res_grey")):
    b = DATA["buildings"][idx]
    pts = [tuple(p) for p in b["p"]]
    cx = sum(p[0] for p in pts) / len(pts)
    cz = sum(p[1] for p in pts) / len(pts)
    tower(k, pts, street_y(cx, cz) - 0.5, b["h"], tex, tile=(8.0, 12.0) if tex != "res_grey" else (9.0, 12.0))
def inside(q, poly):
    c = False
    n = len(poly)
    for i in range(n):
        a, b = poly[i], poly[(i + 1) % n]
        if (a[1] > q[1]) != (b[1] > q[1]) and q[0] < (b[0] - a[0]) * (q[1] - a[1]) / (b[1] - a[1] + 1e-9) + a[0]:
            c = not c
    return c


def rio_dist(q):
    best = 1e9
    for a, b in zip(ST, ST[1:]):
        ax, az = a["p"]
        bx, bz = b["p"]
        abx, abz = bx - ax, bz - az
        t = min(max(((q[0] - ax) * abx + (q[1] - az) * abz) / max(abx * abx + abz * abz, 0.001), 0.0), 1.0)
        best = min(best, math.hypot(q[0] - ax - abx * t, q[1] - az - abz * t))
    return best


right = [83, 58, 57, 81, 84, 87, 77, 72, 75, 62, 60, 69, 56, 68, 53, 12, 13]
MINE = set(right + [112, 114, 119, 109, 110, 0, 4, 19, 21, 22, 26, 28, 30, 32, 36, 37, 44, 47])
POLYS = [[tuple(p) for p in DATA["buildings"][i]["p"]] for i in MINE]
for (a0, a1, b0, b1) in ((146.0, 172.0, 15.0, 30.0), (178.0, 214.0, 20.0, 34.0), (222.0, 262.0, 26.0, 40.0), (130.0, 137.0, 8.0, 40.0)):
    POLYS.append([frame(a0, b0), frame(a1, b0), frame(a1, b1), frame(a0, b1)])
LOWS = [(i, [tuple(p) for p in b["p"]]) for i, b in enumerate(DATA["buildings"]) if i not in MINE and b["h"] < 40.0]
filled_over = set()


def fill(at, u0, lim, half, walkw, sides, seed):
    r = random.Random(seed)
    for sd in sides:
        u = u0 - lim + 10
        while u < u0 + lim - 10:
            w = r.uniform(16, 24)
            p, d = at(u)
            n = (-d[1], d[0])
            off0 = half + walkw + r.uniform(3, 5.5)
            dep = r.uniform(16, 22)
            corners = []
            for (du, dn) in ((-w / 2, off0), (w / 2, off0), (w / 2, off0 + dep), (-w / 2, off0 + dep)):
                corners.append((p[0] + d[0] * du + n[0] * dn * sd, p[1] + d[1] * du + n[1] * dn * sd))
            probes = corners + [((corners[0][0] + corners[2][0]) / 2, (corners[0][1] + corners[2][1]) / 2)]
            ok = all(rio_dist(q) > 28 for q in probes) and not any(inside(q, pl) for q in probes for pl in POLYS) and not any(inside(c, probes[:4]) for pl in POLYS for c in pl)
            if ok:
                for i, pl in LOWS:
                    if any(inside(q, pl) for q in probes) or any(inside(c, probes[:4]) for c in pl):
                        filled_over.add(i)
                POLYS.append(corners)
                cx, cz = probes[4]
                y0 = street_y(cx, cz) - 0.4
                tower(k, corners, y0, r.choice([28.0, 36.0, 44.0, 52.0, 60.0]), r.choice(texs), tile=(8.0, 12.0))
                fa = (p[0] + d[0] * (-w / 2) + n[0] * (half + walkw + 0.1) * sd, p[1] + d[1] * (-w / 2) + n[1] * (half + walkw + 0.1) * sd)
                fb = (p[0] + d[0] * (w / 2) + n[0] * (half + walkw + 0.1) * sd, p[1] + d[1] * (w / 2) + n[1] * (half + walkw + 0.1) * sd)
                yy = street_y(*fa) + CURB
                k.wall("stone", fa, fb, yy - 0.2, yy + 0.6, tile=(2.0, 1.0))
                k.wall("cut__fence_bars", fa, fb, yy + 0.6, yy + 2.4, vfix=(0, 1), tile=(3.0, 1.8))
                for j in range(int(w / 2.2)):
                    f = (j + 0.5) / int(w / 2.2)
                    bx = fa[0] + (fb[0] - fa[0]) * f + n[0] * sd * 1.6
                    bz = fa[1] + (fb[1] - fa[1]) * f + n[1] * sd * 1.6
                    k.leafball("leaves_core", "cut__leaves_ficus" if j % 3 else "cut__leaves_light", (bx, yy + 0.8, bz), (1.0, 0.9, 1.0), 5, 1.0, r)
                if r.random() < 0.5:
                    gx, gz = p[0] + n[0] * (half + walkw + 2.2) * sd, p[1] + n[1] * (half + walkw + 2.2) * sd
                    k.box("guarita", (gx, yy, gz), (3.0, 2.7, 3.0), math.atan2(d[0], d[1]), top="white", uvfit=True)
            u += w + r.uniform(2, 5)


texs = ["res_white", "res_beige", "res_cream", "res_grey"]
fill(pm_at, pm_u0, 150.0, 5.5, 3.5, (1, -1), 71)
fill(sc_at, sc_u0, 70.0, 4.8, 3.0, (1, -1), 72)
far = [e for e in pm_edge if e[3] == -rio_side]
for i, (p, n, o, sd) in enumerate(far[::2]):
    x, z = p[0] + n[0] * (o + sd * 0.9), p[1] + n[1] * (o + sd * 0.9)
    k.leafball("leaves_core", "cut__leaves_ficus", (x, street_y(x, z) + 0.9, z), (1.1, 0.8, 1.1), 5, 1.0, random.Random(i))
for i, (p, n, o, sd) in enumerate(far[1::5]):
    x, z = p[0] + n[0] * (o - sd * 1.2), p[1] + n[1] * (o - sd * 1.2)
    k.tree((x, street_y(x, z) + CURB, z), 1.2, "sibi" if i % 2 else "ficus", seed=300 + i, crown=5.5)
for i, (p, n, o, sd) in enumerate(pm_edge[::4]):
    if i % 2:
        continue
    x, z = p[0] + n[0] * sd * 6.3, p[1] + n[1] * sd * 6.3
    k.tree((x, street_y(x, z) + CURB, z), 1.1, ("sibi", "ficus", "plane")[i % 3], seed=400 + i, crown=5.0)
for side in (1, -1):
    a, b = (RW, SW) if side > 0 else (-SW, -RW)
    strip(k, "sidewalk", S0, S1, a, b, walk, step=6.0, tile=(2.0, 2.0))
    vwall(k, "curb", S0, S1, side * RW, lambda s: road(s, 0), lambda s: walk(s, 0), step=6.0, tile=(1, 1), col=None)
    twall(k, "curb", S0, side * RW, side * SW, road(S0, 0), walk(S0, 0), col=None)
    twall(k, "curb", S1, side * RW, side * SW, road(S1, 0), walk(S1, 0), col=None)
for s in range(int(S0) + 6, 300, 6):
    strip(k, "paint_white", s, s + 3, 0.35, 0.5, lambda s_, t: road(s_, 0) + 0.02, step=3, col=None)
for off in (-0.12, 0.12):
    strip(k, "paint_yellow", 300.0, 403.0, off - 0.06, off + 0.06, lambda s_, t: road(s_, 0) + 0.02, step=6, col=None)
for s0 in (145.0, 302.0):
    for i in range(9):
        t0 = -RW + 0.4 + i * 0.95
        strip(k, "paint_white", s0, s0 + 3.2, t0, t0 + 0.5, lambda s_, t: road(s_, 0) + 0.02, step=4, col=None)
strip(k, "paint_white", 150.0, 150.25, -RW, 0, lambda s_, t: road(s_, 0) + 0.02, step=1, col=None)

WALL = SW + 0.1
WY = lambda s: walk(s, 0)
gates = [(232.0, 241.0), (262.0, 270.0), (308.0, 318.0), (331.0, 343.0), (356.0, 366.0)]
segs = []
s = 168.0
for g0, g1 in gates:
    segs.append((s, g0))
    s = g1
segs.append((s, 380.0))
for i, (a, b) in enumerate(segs):
    vwall(k, "wall_graffiti" if i % 2 == 0 else "wall_graffiti2", a, b, WALL, lambda s: WY(s) - 0.3, lambda s: WY(s) + 2.7, step=6.0, tile=(6.0, 3.0))
    vwall(k, "curb", a, b, WALL + 0.3, lambda s: WY(s) + 2.7, lambda s: WY(s) + 2.75, step=6.0, col=None)
for g0, g1 in gates:
    vwall(k, "gate_black", g0, g1, WALL + 0.2, lambda s: WY(s) - 0.2, lambda s: WY(s) + 3.0, step=4.0, tile=(4.0, 3.2))
    for sp in (g0, g1):
        sbox(k, "stone" if g0 > 300 else "panel_dark", sp, WALL + 0.2, WY(sp) - 0.2, (0.8, 3.4, 0.8))
vwall(k, "cut__fence_bars", 150.0, 168.0, WALL, lambda s: WY(s) + 0.6, lambda s: WY(s) + 2.2, step=6.0, tile=(3.0, 1.6), vfix=(0, 1))
vwall(k, "wall_graffiti2", 150.0, 168.0, WALL, lambda s: WY(s) - 0.3, lambda s: WY(s) + 0.6, step=6.0, tile=(6.0, 3.0))
twall(k, "wall_graffiti", 150.0, WALL, WALL + 30, WY(150) - 0.3, WY(150) + 0.8)

YL = gy(200, 0) + 0.8
strip(k, "grass", 148.0, 380.0, WALL + 0.3, WALL + 70, lambda s, t: YL - 0.4, step=12.0, tile=(4, 4), col=None)


def casarao(s0, s1, t0, t1, floors, y0, roof=True):
    a = [frame(s0, t0), frame(s1, t0), frame(s1, t1), frame(s0, t1)]
    h = floors * 4.2
    k.prism("casarao", a, y0, y0 + h, tile=(16.0, 8.4))
    k.prism("curb", a, y0 + h, y0 + h + 0.4, col=None, tile=(4, 0.4))
    if roof:
        m0, m1 = frame(s0 + 2, (t0 + t1) / 2), frame(s1 - 2, (t0 + t1) / 2)
        ry = y0 + h + 0.4
        rh = 2.6
        k.quad("roof_tile", (a[0][0], ry, a[0][1]), (a[1][0], ry, a[1][1]), (m1[0], ry + rh, m1[1]), (m0[0], ry + rh, m0[1]), 0, 0, (s1 - s0) / 3, 2)
        k.quad("roof_tile", (a[2][0], ry, a[2][1]), (a[3][0], ry, a[3][1]), (m0[0], ry + rh, m0[1]), (m1[0], ry + rh, m1[1]), 0, 0, (s1 - s0) / 3, 2)
        k.poly("roof_tile", [(a[1][0], ry, a[1][1]), (a[2][0], ry, a[2][1]), (m1[0], ry + rh, m1[1])], [(0, 0), (1, 0), (0.5, 1)])
        k.poly("roof_tile", [(a[3][0], ry, a[3][1]), (a[0][0], ry, a[0][1]), (m0[0], ry + rh, m0[1])], [(0, 0), (1, 0), (0.5, 1)])


casarao(146.0, 172.0, 15.0, 30.0, 3, YL - 0.6)
casarao(178.0, 214.0, 20.0, 34.0, 3, YL - 0.6)
casarao(222.0, 262.0, 26.0, 40.0, 2, YL - 0.6)
casarao(268.0, 290.0, 16.0, 30.0, 3, YL - 0.6)
casarao(300.0, 330.0, 22.0, 40.0, 2, YL - 0.6)
k.prism("panel_dark", [frame(240, 50), frame(285, 50), frame(285, 80), frame(240, 80)], YL - 0.6, YL + 17, top="panel_dark", tile=(6, 2.5))

CH0, CH1 = 383.0, 396.0
cy = gy(390, 0) + 0.5
ch = [frame(CH0, 12.0), frame(CH1, 12.0), frame(CH1, 30.0), frame(CH0, 30.0)]
k.prism("church", ch, cy, cy + 9.0, tile=(4, 4))
mf0, mf1 = frame(CH0, 21.0), frame(CH1, 21.0)
for e, (p0, p1) in enumerate(((ch[0], ch[3]), (ch[1], ch[2]))):
    pass
k.quad("roof_tile", (ch[0][0], cy + 9, ch[0][1]), (ch[1][0], cy + 9, ch[1][1]), (mf1[0], cy + 13, mf1[1]), (mf0[0], cy + 13, mf0[1]), 0, 0, 4, 2)
k.quad("roof_tile", (ch[3][0], cy + 9, ch[3][1]), (ch[2][0], cy + 9, ch[2][1]), (mf1[0], cy + 13, mf1[1]), (mf0[0], cy + 13, mf0[1]), 0, 0, 4, 2)
for (p0, p1, mf) in ((ch[0], ch[3], mf0), (ch[1], ch[2], mf1)):
    k.poly("church", [(p0[0], cy + 9, p0[1]), (p1[0], cy + 9, p1[1]), (mf[0], cy + 13, mf[1])], [(0, 0), (4, 0), (2, 1)])
cr = frame((CH0 + CH1) / 2, 12.0)
k.beam("white", (cr[0], cy + 13, cr[1]), (cr[0], cy + 15.5, cr[1]), 0.08, 4)
a, b = frame((CH0 + CH1) / 2 - 0.6, 12.0), frame((CH0 + CH1) / 2 + 0.6, 12.0)
k.beam("white", (a[0], cy + 14.8, a[1]), (b[0], cy + 14.8, b[1]), 0.08, 4)
sbox(k, "glass_dark", 389.5, 12.0, cy + 2.5, (0.1, 3.0, 2.0), col=None)
for i in range(5):
    sbox(k, "granite", 389.5, 9.0 + i * 0.6, WY(389) + i * 0.1 - 0.1, (0.6, 0.2 + i * 0.1, 4.0))
vwall(k, "cut__fence_bars", 380.0, 405.0, WALL, lambda s: WY(s), lambda s: WY(s) + 2.0, step=5.0, tile=(3.0, 2.0), vfix=(0, 1))

def inv_t(p):
    best = None
    for s10 in range(1300, 4150, 5):
        sv = s10 / 10
        fx, fz = frame(sv)
        d = math.hypot(p[0] - fx, p[1] - fz)
        if best is None or d < best[0]:
            best = (d, sv, fx, fz)
    d, sv, fx, fz = best
    lx, lz = frame(sv, 1.0)
    return (p[0] - fx) * (lx - fx) + (p[1] - fz) * (lz - fz)


texs = ["res_white", "res_beige", "res_cream", "res_grey"]
right = [83, 58, 57, 81, 84, 87, 77, 72, 75, 62, 60, 69, 56, 68, 53, 12, 13]
for i, idx in enumerate(right):
    b = DATA["buildings"][idx]
    pts = [tuple(p) for p in b["p"]]
    cx = sum(p[0] for p in pts) / len(pts)
    cz = sum(p[1] for p in pts) / len(pts)
    y0 = street_y(cx, cz) - 0.5
    if idx in (12, 13):
        tower(k, pts, y0, max(b["h"], 22.0), "facade_green", tile=(8.0, 8.0), lobby="glass_dark", lobby_h=3.5)
        for e in range(len(pts)):
            pa, pb = pts[e], pts[(e + 1) % len(pts)]
            L = math.dist(pa, pb)
            for j in range(int(L / 3.0)):
                f = (j + 0.5) / int(L / 3.0)
                q = (pa[0] + (pb[0] - pa[0]) * f, pa[1] + (pb[1] - pa[1]) * f)
                k.leafball("leaves_core", "cut__leaves_ficus", (q[0], y0 + 1.2, q[1]), (1.3, 1.1, 1.3), 5, 1.1, random.Random(idx * 100 + e * 10 + j))
        continue
    tower(k, pts, y0, b["h"], texs[(idx * 7) % 4], tile=(8.0, 12.0) if texs[(idx * 7) % 4] != "res_grey" else (9.0, 12.0))
low = [88, 85, 54, 86, 73, 82, 71, 51, 55, 63, 64, 67, 59]
for idx in low:
    b = DATA["buildings"][idx]
    pts = [tuple(p) for p in b["p"]]
    cx = sum(p[0] for p in pts) / len(pts)
    cz = sum(p[1] for p in pts) / len(pts)
    y0 = street_y(cx, cz) - 0.3
    if max(inv_t(p) for p in pts) > -SW - 0.5:
        continue
    k.prism("concrete_wall", pts, y0, y0 + min(b["h"], 3.2), top="grass", tile=(4.0, 3.2))

RT = -SW - 0.1
entries = [(156.0, "guarita"), (176.0, "stairs"), (199.0, "gate"), (222.0, "garden"), (246.0, "guarita"), (262.0, "gate"), (280.0, "stairs"), (296.0, "gate"), (318.0, "gate"), (338.0, "guarita"), (352.0, "gate"), (372.0, "garden"), (392.0, "guarita")]
fs = 147.0
for s_e, kind in entries:
    w = {"guarita": 5.0, "stairs": 6.0, "gate": 6.5, "garden": 3.0}[kind]
    if s_e - fs > 0.5:
        vwall(k, "stone", fs, s_e, RT, lambda s: WY(s) - 0.2, lambda s: WY(s) + 0.6, step=6.0, tile=(2.0, 1.0))
        vwall(k, "cut__fence_bars", fs, s_e, RT, lambda s: WY(s) + 0.6, lambda s: WY(s) + 2.4, step=6.0, tile=(3.0, 1.8), vfix=(0, 1))
    if kind == "gate":
        vwall(k, "gate_black", s_e, s_e + w, RT, lambda s: WY(s) - 0.2, lambda s: WY(s) + 2.8, step=4.0, tile=(4.0, 3.0))
        for sp in (s_e, s_e + w):
            sbox(k, "stone", sp, RT - 0.3, WY(sp) - 0.2, (0.8, 3.2, 0.8))
    elif kind == "guarita":
        sbox(k, "guarita", s_e + w / 2, RT - 2.0, WY(s_e) - 0.1, (3.4, 2.8, 3.0), top="white", uvfit=True)
        sbox(k, "white", s_e + w / 2, RT - 1.8, WY(s_e) + 2.7, (4.4, 0.25, 4.6), col=None)
        vwall(k, "gate_black", s_e, s_e + 1.2, RT, lambda s: WY(s), lambda s: WY(s) + 2.4, step=2, tile=(1.2, 2.4), col=None)
    elif kind == "stairs":
        for i in range(6):
            sbox(k, "granite", s_e + w / 2, RT - 0.4 - i * 0.45, WY(s_e) + i * 0.18, (0.45, 0.2, w - 1), col=None)
        vwall(k, "cut__fence_bars", s_e, s_e + w, RT - 3.0, lambda s: WY(s) + 1.0, lambda s: WY(s) + 3.0, step=6, tile=(3, 2), vfix=(0, 1))
    elif kind == "garden":
        sbush(k, s_e + w / 2, RT - 1.0, WY(s_e), w, 1.4, seed=int(s_e))
    fs = s_e + w
vwall(k, "stone", fs, S1, RT, lambda s: WY(s) - 0.2, lambda s: WY(s) + 0.6, step=6.0, tile=(2.0, 1.0))
vwall(k, "cut__fence_bars", fs, S1, RT, lambda s: WY(s) + 0.6, lambda s: WY(s) + 2.4, step=6.0, tile=(3.0, 1.8), vfix=(0, 1))
strip(k, "grass", 147.0, S1, RT - 12.0, RT, lambda s, t: WY(s) + 0.05, step=12.0, tile=(4, 4), col=None)
for i, s in enumerate(range(150, 405, 9)):
    sbush(k, s + 3.5, RT - 1.2 - (i % 3) * 0.4, WY(s), 6.0, 1.3 + (i % 4) * 0.4, seed=200 + i, light=i % 3 == 0)
for i, s in enumerate(range(160, 400, 23)):
    sbush(k, s, RT - 5.5, WY(s), 4.0, 2.8, seed=260 + i, depth=2.6)
for i, (a, b) in enumerate(segs):
    climber(k, a, b, WALL - 0.06, lambda s: WY(s) + 2.7, 2.4, seed=40 + i)
climber(k, 150.0, 168.0, WALL - 0.06, lambda s: WY(s) + 2.2, 1.6, seed=60)
sbush(k, 159.0, WALL + 1.2, WY(159), 18.0, 1.8, seed=61, depth=2.0)

trees = [(160, 6.6, "sibi", 1.3), (176, 6.8, "ficus", 1.5), (196, 6.6, "sibi", 1.4), (214, 6.8, "ficus", 1.6), (246, 6.6, "sibi", 1.3), (276, 6.8, "ficus", 1.4),
         (296, 7.0, "ficus", 1.9), (322, 6.8, "ficus", 1.6), (352, 6.6, "sibi", 1.3), (378, 6.8, "ficus", 1.5),
         (168, -6.8, "ficus", 1.5), (190, -6.6, "sibi", 1.3), (226, -6.8, "ficus", 1.5), (258, -6.6, "sibi", 1.4), (288, -6.8, "ficus", 1.6), (312, -7.0, "ficus", 1.8),
         (338, -6.8, "sibi", 1.4), (364, -6.8, "ficus", 1.6), (398, -6.6, "sibi", 1.3)]
for i, (s, t, kind, sz) in enumerate(trees):
    x, z = frame(s, t)
    y = walk(s, 0)
    sbox(k, "soil", s, t, y - 0.1, (1.2, 0.13, 1.6), col=None)
    k.tree((x, y, z), sz, kind, seed=100 + i * 13, crown=(4.9 if kind == "ficus" else 4.4) * sz, lean=lean_to(s, -0.9 if t > 0 else 0.9))
for s in (186.0, 206.0):
    sbox(k, "planter", s, 6.0, walk(s, 0), (1.6, 1.0, 2.6), top="soil")

POLES = [150.0, 171.0, 203.0, 236.0, 268.0, 301.0, 333.0, 366.0, 398.0]
tops = []
for s in POLES:
    x, z = frame(s, -SW + 0.6)
    y = walk(s, 0)
    k.tube("curb", (x, y, z), (x, y + 9.0, z), 0.16, 0.11, 6, 4.0)
    a, b = frame(s, -SW - 0.4), frame(s, -SW + 1.6)
    k.beam("curb", (a[0], y + 8.3, a[1]), (b[0], y + 8.3, b[1]), 0.06, 4)
    tops.append([(a[0], y + 8.3, a[1]), (x, y + 8.9, z), (b[0], y + 8.3, b[1]), (x, y + 7.2, z)])
    if s in (171.0, 236.0, 301.0, 366.0):
        q = frame(s, -SW + 3.2)
        k.beam("metal_grey", (x, y + 8.6, z), (q[0], y + 9.0, q[1]), 0.05, 4)
        k.box("lamp", (q[0], y + 8.8, q[1]), (0.5, 0.18, 0.7), yaw_of(s), col=None)
    k.box("metal_dark", (x, y + 6.6, z), (0.5, 0.6, 0.4), yaw_of(s), col=None)
for ta, tb in zip(tops, tops[1:]):
    for pa, pb in zip(ta, tb):
        m = ((pa[0] + pb[0]) / 2, (pa[1] + pb[1]) / 2 - 0.6, (pa[2] + pb[2]) / 2)
        k.beam("metal_dark", pa, m, 0.025, 3)
        k.beam("metal_dark", m, pb, 0.025, 3)


def plate(s, t, y, tex, along=True):
    yaw = yaw_of(s) + (0.0 if along else math.pi / 2)
    x, z = frame(s, t)
    c, sn = math.cos(yaw), math.sin(yaw)
    hw = 0.55
    a = (x - sn * hw, z - c * hw)
    b = (x + sn * hw, z + c * hw)
    k.wall(tex, a, b, y, y + 0.28, vfix=(0, 1), tile=(1.1, 1), col=None)
    k.wall(tex, b, a, y, y + 0.28, vfix=(0, 1), tile=(1.1, 1), col=None)


def post(s, t, plates, signs=()):
    x, z = frame(s, t)
    y = walk(s, 0)
    k.tube("metal_grey", (x, y, z), (x, y + 3.3, z), 0.04, 0.04, 5, 2)
    for i, (tex, along) in enumerate(plates):
        plate(s, t, y + 2.95 - i * 0.32, tex, along)
    for i, tex in enumerate(signs):
        y0 = y + 2.0 - i * 0.65
        pa, pb = frame(s - 0.06, t + 0.3), frame(s - 0.06, t - 0.3)
        k.wall(tex, pa, pb, y0, y0 + 0.6, vfix=(0, 1), tile=(0.6, 1), col=None)
        pa, pb = frame(s - 0.04, t - 0.3), frame(s - 0.04, t + 0.3)
        k.wall("steel", pa, pb, y0, y0 + 0.6, vfix=(0, 1), tile=(0.6, 1), col=None)


post(146.0, -SW + 0.5, [("placa_rioclaro", True), ("placa_saocarlos", False)], ["sign_parking"])
post(146.0, SW - 0.5, [("placa_saocarlos", False)])
post(401.0, SW - 0.5, [("placa_rioclaro", True), ("placa_pamplona", False)])
post(401.0, -SW + 0.5, [("placa_pamplona", False)])
for s in (226.0, 296.0, 336.0):
    post(s, SW - 0.6, [], ["sign_noparking"])
for s in (186.0, 252.0, 352.0):
    post(s, -SW + 0.6, [], ["sign_noparking"])

cars = [(174, -3.3, "car_white"), (182, -3.3, "car_black"), (198, -3.3, "car_silver"), (216, -3.3, "car_white"), (229, -3.3, "car_black"), (251, -3.3, "car_white"),
        (268, -3.3, "car_silver"), (284, -3.3, "car_white"), (318, -3.3, "car_red"), (330, -3.3, "car_white"), (346, -3.3, "car_silver"), (372, -3.3, "car_black"), (386, -3.3, "car_white"),
        (224, 3.3, "car_silver"), (344, 3.3, "car_red"), (360, 3.3, "car_white")]
for i, (s, t, c) in enumerate(cars):
    car(k, s, t, c, seed=i, flip=t > 0)
for i, s in enumerate((200.0, 201.2, 202.4)):
    x, z = frame(s, 3.6)
    y = road(s, 0)
    k.box("metal_dark", (x, y + 0.3, z), (1.8, 0.5, 0.4), yaw_of(s), col=None)
    k.box("car_black", (x, y + 0.7, z), (1.2, 0.35, 0.35), yaw_of(s), col=None)

tris = k.export("rc_rua")
json.dump({"range": [137, 420], "replaced": sorted(set(right + low + [127, 128, 133, 112, 114, 119, 109, 110]) | filled_over), "lamps": [list(P(s, -SW + 3.2, 8.5)) for s in (171.0, 236.0, 301.0, 366.0)], "tris": tris}, open(os.path.join(OUTDIR, "rc_rua.json"), "w"))
