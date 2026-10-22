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
pam = [c for c in DATA["cross"] if c["name"] == "Rua Pamplona"][0]["pts"]
pp = [tuple(q["p"]) for q in pam]
YJ = road(404.0, 0)
for a, b in zip(pp, pp[1:]):
    L = math.dist(a, b)
    if L < 0.1:
        continue
    dx, dz = (b[0] - a[0]) / L, (b[1] - a[1]) / L
    nx, nz = -dz, dx
    ya = YJ + 0.0
    q = [(a[0] + nx * 5.5, a[1] + nz * 5.5), (b[0] + nx * 5.5, b[1] + nz * 5.5), (b[0] - nx * 5.5, b[1] - nz * 5.5), (a[0] - nx * 5.5, a[1] - nz * 5.5)]
    if min(math.dist(a, pp[5]), math.dist(b, pp[5])) > 40:
        continue
    k.poly("asphalt", [(x, max(street_y(x, z), YJ - 0.6) + 0.05, z) for x, z in q], [(x / 4, z / 4) for x, z in q], "floor")
for side in (1, -1):
    a, b = (RW, SW) if side > 0 else (-SW, -RW)
    strip(k, "sidewalk", S0, S1, a, b, walk, step=6.0, tile=(2.0, 2.0))
    vwall(k, "curb", S0, S1, side * RW, lambda s: road(s, 0), lambda s: walk(s, 0), step=6.0, tile=(1, 1), col=None)
    twall(k, "curb", S0, side * RW, side * SW, road(S0, 0), walk(S0, 0), col=None)
    twall(k, "curb", S1, side * RW, side * SW, road(S1, 0), walk(S1, 0), col=None)
for s in range(int(S0) + 6, 300, 6):
    strip(k, "paint_white", s, s + 3, 0.35, 0.5, lambda s_, t: road(s_, 0) + 0.02, step=3, col=None)
for off in (-0.12, 0.12):
    strip(k, "paint_yellow", 300.0, S1, off - 0.06, off + 0.06, lambda s_, t: road(s_, 0) + 0.02, step=6, col=None)
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
        sbox(k, "hedge", s_e + w / 2, RT - 1.0, WY(s_e), (1.6, 1.3, w), col=None)
    fs = s_e + w
vwall(k, "stone", fs, S1, RT, lambda s: WY(s) - 0.2, lambda s: WY(s) + 0.6, step=6.0, tile=(2.0, 1.0))
vwall(k, "cut__fence_bars", fs, S1, RT, lambda s: WY(s) + 0.6, lambda s: WY(s) + 2.4, step=6.0, tile=(3.0, 1.8), vfix=(0, 1))
strip(k, "grass", 147.0, S1, RT - 12.0, RT, lambda s, t: WY(s) + 0.05, step=12.0, tile=(4, 4), col=None)
for i, s in enumerate(range(150, 405, 7)):
    sbox(k, "hedge", s, RT - 1.0 - (i % 3) * 0.3, WY(s), (1.4, 1.0 + (i % 4) * 0.35, 3.0 + (i % 2)), col=None)

trees = [(160, 6.6, "sibi", 1.3), (176, 6.8, "ficus", 1.5), (196, 6.6, "sibi", 1.4), (214, 6.8, "ficus", 1.6), (246, 6.6, "sibi", 1.3), (276, 6.8, "ficus", 1.4),
         (296, 7.0, "ficus", 1.9), (322, 6.8, "ficus", 1.6), (352, 6.6, "sibi", 1.3), (378, 6.8, "ficus", 1.5),
         (168, -6.8, "ficus", 1.5), (190, -6.6, "sibi", 1.3), (226, -6.8, "ficus", 1.5), (258, -6.6, "sibi", 1.4), (288, -6.8, "ficus", 1.6), (312, -7.0, "ficus", 1.8),
         (338, -6.8, "sibi", 1.4), (364, -6.8, "ficus", 1.6), (398, -6.6, "sibi", 1.3)]
for i, (s, t, kind, sz) in enumerate(trees):
    x, z = frame(s, t)
    y = walk(s, 0)
    sbox(k, "soil", s, t, y - 0.1, (1.2, 0.13, 1.6), col=None)
    k.tree((x, y, z), sz, kind, seed=100 + i * 13, crown=(6.0 if kind == "ficus" else 5.0) * sz)
for s in (186.0, 206.0):
    sbox(k, "planter", s, 6.0, walk(s, 0), (1.6, 1.0, 2.6), top="soil")

for s in (171.0, 236.0, 301.0, 366.0):
    x, z = frame(s, -SW + 0.6)
    y = walk(s, 0)
    k.tube("curb", (x, y, z), (x, y + 9.0, z), 0.16, 0.11, 6, 4.0)
    q = frame(s, -SW + 3.2)
    k.beam("metal_grey", (x, y + 8.6, z), (q[0], y + 9.0, q[1]), 0.05, 4)
    k.box("lamp", (q[0], y + 8.8, q[1]), (0.5, 0.18, 0.7), yaw_of(s), col=None)

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
json.dump({"range": [137, 420], "replaced": right + low + [127, 128, 133], "lamps": [list(P(s, -SW + 3.2, 8.5)) for s in (171.0, 236.0, 301.0, 366.0)], "tris": tris}, open(os.path.join(OUTDIR, "rc_rua.json"), "w"))
