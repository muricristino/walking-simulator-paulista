import math, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rc_lib import *

k = Kit()
k.xmax = -30.5
S0, S1 = 21.0, 133.5
TL, TR = 8.0, -10.5
PAVE = 0.17


def ground(s, t):
    return gy(s, 0.0) + PAVE


def terrace(s):
    return gy(min(max(s, 20.0), 137.0), 0.0) + PAVE + 1.3


strip(k, "paver", S0, S1, TR, TL, ground, step=4.0, tile=(1.6, 1.6), tstep=6.2)
vwall(k, "curb", S0, S1, TR, lambda s: ground(s, 0) - 0.4, lambda s: ground(s, 0), tile=(1, 1), col=None)
twall(k, "curb", S1, TR, TL, ground(S1, 0) - 0.3, ground(S1, 0), tile=(1, 1))
strip(k, "paver", S1, S1 + 0.01, TR, TL, ground, step=1, col=None)

vwall(k, "granite", S0, 137.0, TL, lambda s: ground(s, 0) - 0.2, terrace, step=6.0, tile=(2.4, 1.2))
strip(k, "granite", S0, 137.0, TL, 12.5, lambda s, t: terrace(s), step=6.0, tile=(2.4, 2.4), col=None)
for s in range(int(S0) + 2, 137, 3):
    x, z = frame(s, TL + 0.15)
    k.box("metal_grey", (x, terrace(s), z), (0.08, 1.0, 0.08), yaw_of(s), col=None)
vwall(k, "metal_grey", S0, 137.0, TL + 0.15, lambda s: terrace(s) + 0.95, lambda s: terrace(s) + 1.02, step=6.0, col=None)
vwall(k, "glass_dark", S0, 137.0, TL + 0.15, lambda s: terrace(s) + 0.1, lambda s: terrace(s) + 0.95, step=6.0, col=None)

FLOOR = lambda s: terrace(s)
vwall(k, "storefront", S0, 137.0, 12.5, FLOOR, lambda s: FLOOR(s) + 4.6, step=4.0, tile=(8.0, 4.6), vfix=(0.0, 1.0))
for s in range(int(S0) + 4, 137, 8):
    x, z = frame(s, 12.0)
    k.box("metal_grey", (x, FLOOR(s), z), (0.5, 6.0, 0.7), yaw_of(s), col="wall")
for s0, s1 in ((84.0, 92.0),):
    for i in range(6):
        y = ground(s0, 0) + i * 0.24
        sbox(k, "granite", (s0 + s1) / 2, TL + 0.6 + (5 - i) * 0.32, y, (0.4, 0.24, s1 - s0), col="wall")
    sbox(k, "copper", s1 + 0.2, TL + 1.5, ground(s1, 0), (2.4, 1.4, 0.3))

MQ = lambda s: FLOOR(s) + 4.6
for s in range(int(S0), 137, 4):
    sa, sb = s, min(s + 4, 137)
    a0, a1 = frame(sa, 5.8), frame(sb, 5.8)
    b0, b1 = frame(sa, 12.5), frame(sb, 12.5)
    k.poly("cut__slats", [(a0[0], MQ(sa), a0[1]), (a1[0], MQ(sb), a1[1]), (b1[0], MQ(sb), b1[1]), (b0[0], MQ(sa), b0[1])], [(sa / 2.0, 0), (sb / 2.0, 0), (sb / 2.0, 3), (sa / 2.0, 3)])
vwall(k, "copper", S0, 137.0, 5.8, MQ, lambda s: MQ(s) + 1.4, step=4.0, tile=(4.0, 1.4), col=None)
strip(k, "copper", S0, 137.0, 5.8, 12.5, lambda s, t: MQ(s) + 1.4, step=4.0, col=None)
twall(k, "copper", S0, 5.8, 12.5, MQ(S0), MQ(S0) + 1.4, col=None)
twall(k, "copper", 137.0, 5.8, 12.5, MQ(137.0), MQ(137.0) + 1.4, col=None)

POD = lambda s: MQ(s) + 1.4
vwall(k, "panel_dark", S0, 137.0, 13.0, POD, lambda s: POD(s) + 7.5, step=6.0, tile=(6.0, 2.5))
strip(k, "panel_dark", S0, 137.0, 13.0, 30.0, lambda s, t: POD(s) + 7.5, step=8.0, col=None)
twall(k, "panel_dark", S0, 12.5, 30.0, FLOOR(S0), POD(S0) + 7.5, tile=(6.0, 2.5))
twall(k, "panel_dark", 137.0, 12.5, 30.0, FLOOR(137.0), POD(137.0) + 7.5, tile=(6.0, 2.5))
vwall(k, "glass_dark", S0, 137.0, 12.6, lambda s: FLOOR(s) + 4.6, POD, step=8.0)

ys = POD(60) + 7.5
for idx in (30, 0, 44):
    b = DATA["buildings"][idx]
    pts = [tuple(p) for p in b["p"]]
    k.prism("curtain", pts, ys - 2, ys - 2 + b["h"] - 10, top="panel_dark", tile=(8.0, 16.0))
b = DATA["buildings"][21]
pts21 = clip_x([tuple(p) for p in b["p"]], k.xmax)
k.prism("storefront", pts21, 0.15, 0.15 + 4.6, tile=(8.0, 4.6), vfix=(0.0, 1.0))
k.prism("copper", pts21, 4.75, 6.2, tile=(4.0, 1.4), vfix=(0.0, 1.0), col=None)
k.prism("panel_dark", pts21, 6.2, 9.5, top="panel_dark", tile=(6.0, 2.5), col=None)
b = DATA["buildings"][19]
k.prism("panel_dark", [tuple(p) for p in b["p"]], gy(120, 20) - 2, POD(120) + 7.5, top="panel_dark", tile=(6.0, 2.5))

PZ = lambda s: ground(min(s, 92.0), 0) + 0.2 + max(0.0, (s - 92.0)) / 33.0 * 2.6 if s < 125 else ground(125, 0) + 2.8 + (s - 125) * 0.02
vwall(k, "concrete_wall", 90.0, 137.0, TR, lambda s: ground(s, 0) - 0.2, PZ, step=3.0, tile=(4.0, 3.2))
vwall(k, "cut__fence_bars", 90.0, 137.0, TR, PZ, lambda s: PZ(s) + 1.6, step=6.0, tile=(4.0, 1.6), vfix=(0, 1), col="wall")
strip(k, "concrete_wall", 90.0, 137.0, TR - 30.0, TR, lambda s, t: PZ(s), step=6.0, tile=(4, 4), col=None)
twall(k, "concrete_wall", 137.0, TR - 30, TR, ground(137, 0) - 0.5, PZ(137))
for s in (95, 108, 121):
    sbox(k, "concrete_wall", s, TR + 0.8, ground(s, 0), (0.5, 0.45, 3.0))

strip(k, "paver", 18.0, 90.0, TR - 26.0, TR, lambda s, t: ground(s, 0) + 0.02, step=8.0, tile=(1.6, 1.6), col="floor")
DECK0, DECK1 = 24.0, 84.0
DT0, DT1 = -1.8, -10.3
DY = lambda s: ground(s, 0) + 0.3
strip(k, "deck", DECK0, DECK1, DT1, DT0, lambda s, t: DY(s), step=5.0, tile=(4.0, 1.0))
vwall(k, "deck", DECK0, DECK1, DT0, lambda s: ground(s, 0), DY, step=5.0, tile=(4.0, 0.3), col=None)
twall(k, "deck", DECK0, DT1, DT0, ground(DECK0, 0), DY(DECK0), col=None)
twall(k, "deck", DECK1, DT1, DT0, ground(DECK1, 0), DY(DECK1), col=None)

RF = lambda s, t: DY(s) + 4.4 + (t - DT0) * -0.06
cols = list(range(int(DECK0) + 2, int(DECK1), 10))
for s in cols:
    for t in (DT0 - 0.4, DT1 + 0.6):
        x, z = frame(s, t)
        k.box("metal_grey", (x, DY(s), z), (0.25, RF(s, t) - DY(s), 0.25), yaw_of(s), col="wall")
for s in range(int(DECK0), int(DECK1), 5):
    sa, sb = s, s + 5
    for (ta, tb) in ((DT0 + 0.5, (DT0 + DT1) / 2), ((DT0 + DT1) / 2, DT1 - 0.2)):
        pa = frame(sa, ta)
        pb = frame(sb, tb)
        k.beam("metal_dark", (pa[0], RF(sa, ta) - 0.5, pa[1]), (pb[0], RF(sb, tb) - 0.5, pb[1]), 0.05, 4)
        pa = frame(sa, tb)
        pb = frame(sb, ta)
        k.beam("metal_dark", (pa[0], RF(sa, tb) - 0.5, pa[1]), (pb[0], RF(sb, ta) - 0.5, pb[1]), 0.05, 4)
for t in (DT0 + 0.5, (DT0 + DT1) / 2, DT1 - 0.2):
    pa, pb = frame(DECK0, t), frame(DECK1, t)
    k.beam("metal_dark", (pa[0], RF(DECK0, t) - 0.5, pa[1]), (pb[0], RF(DECK1, t) - 0.5, pb[1]), 0.06, 4)
    k.beam("metal_dark", (pa[0], RF(DECK0, t), pa[1]), (pb[0], RF(DECK1, t), pb[1]), 0.06, 4)
for s in range(int(DECK0), int(DECK1) + 1, 5):
    pa, pb = frame(s, DT0 + 0.5), frame(s, DT1 - 0.2)
    k.beam("metal_dark", (pa[0], RF(s, DT0 + 0.5), pa[1]), (pb[0], RF(s, DT1 - 0.2), pb[1]), 0.05, 4)
strip(k, "canopy_roof", DECK0, DECK1, DT1 - 0.3, DT0 + 0.6, lambda s, t: RF(s, t) + 0.05, step=7.0, tile=(4.0, 4.0), col=None)
for s in (28, 34, 40, 46):
    x, z = frame(s, DT0 + 0.6)
    k.box("metal_dark", (x, RF(s, DT0) - 0.9, z), (0.6, 0.35, 0.6), yaw_of(s), col=None)

FC0, FC1 = 44.0, 82.0
vwall(k, "food_red", FC0, FC1, DT1 - 0.2, lambda s: DY(s), lambda s: DY(s) + 1.1, step=6.0, tile=(8.0, 1.1), vfix=(0, 1))
vwall(k, "storefront", FC0, FC1, DT1 - 0.6, lambda s: DY(s) + 1.1, lambda s: DY(s) + 3.0, step=6.0, tile=(8.0, 3.8), vfix=(0, 0.5), col=None)
strip(k, "white", FC0, FC1, DT1 - 0.2, DT1 + 0.5, lambda s, t: DY(s) + 1.1, step=6.0, col=None)
strip(k, "steel", FC0, FC1, DT1 - 6, DT1 - 0.2, lambda s, t: DY(s) + 3.1, step=6.0, col=None)
vwall(k, "steel", FC0, FC1, DT1 - 0.2, lambda s: DY(s) + 3.0, lambda s: DY(s) + 3.4, step=6.0, col=None)
twall(k, "food_red", FC0, DT1 - 6, DT1 - 0.2, DY(FC0), DY(FC0) + 3.1)
for s in range(int(FC0), int(FC1), 8):
    sbox(k, "white", s, DT1 - 0.4, DY(s) + 1.1, (0.15, 1.9, 0.2), col=None)
for idx in (36, 47, 22, 4):
    b = DATA["buildings"][idx]
    pts = [tuple(p) for p in b["p"]]
    y0 = ground(50, 0) - 0.5
    k.prism("glass_dark", pts, y0, y0 + 5.0, tile=(4.0, 5.0))
    k.prism("tower_dark", pts, y0 + 5.0, y0 + b["h"], top="panel_dark", tile=(16.0, 16.0), col=None)
for idx in (32, 37):
    b = DATA["buildings"][idx]
    k.prism("panel_dark", [tuple(p) for p in b["p"]], ground(60, 0) - 0.5, ground(60, 0) + b["h"], top="panel_dark", tile=(6.0, 2.5))

KS, KT = 36.0, -12.6
yk = ground(KS, 0)
sbox(k, "white", KS, KT, yk, (3.6, 2.8, 3.6), top="white")
sbox(k, "green_wall", KS, KT + 1.82, yk, (0.06, 2.4, 3.4), col=None, tile=(1.0, 1.0))
sbox(k, "green_wall", KS - 1.82, KT + 0.9, yk, (1.6, 1.0, 0.06), col=None, tile=(1.0, 1.0))
sbox(k, "glass_light", KS - 1.83, KT + 0.6, yk + 1.0, (2.2, 1.3, 0.06), col=None, uvfit=True)
sbox(k, "white", KS - 1.85, KT + 0.6, yk + 0.95, (2.4, 0.08, 0.1), col=None)
sbox(k, "white", KS - 1.85, KT + 0.6, yk + 2.3, (2.4, 0.08, 0.1), col=None)
sbox(k, "white", KS - 1.84, KT - 1.1, yk, (1.0, 2.1, 0.06), col=None)
sbox(k, "metal_dark", KS - 1.86, KT - 0.75, yk + 1.0, (0.06, 0.1, 0.02), col=None)
for tt in (KT - 0.58, KT - 1.62):
    sbox(k, "metal_grey", KS - 1.87, tt, yk, (0.05, 2.15, 0.05), col=None)
sbox(k, "metal_grey", KS - 1.87, KT - 1.1, yk + 2.1, (0.05, 0.05, 1.1), col=None)
k.box("white", (*frame(KS, KT)[:1], yk + 2.8, frame(KS, KT)[1]), (3.7, 0.1, 3.7), yaw_of(KS), col=None)
aw = [P(KS - 3.0, KT + 2.3, 2.55, yk), P(KS - 3.0, KT - 2.1, 2.55, yk), P(KS + 1.4, KT - 2.1, 3.6, yk), P(KS + 1.4, KT + 2.3, 3.6, yk)]
k.poly("white", aw, [(0, 0), (1, 0), (1, 1), (0, 1)])
k.poly("awning_pink", [aw[0], aw[1], (aw[1][0], aw[1][1] - 0.25, aw[1][2]), (aw[0][0], aw[0][1] - 0.25, aw[0][2])], [(0, 0), (1, 0), (1, 1), (0, 1)])
for tt in (KT + 2.2, KT - 2.0):
    q = frame(KS - 2.9, tt)
    k.beam("metal_grey", (q[0], yk, q[1]), (q[0], yk + 2.55, q[1]), 0.04, 4)
sbox(k, "concrete_wall", 33.0, -18.0, ground(33, 0), (3.0, 0.8, 16.0), top="soil")
sbush(k, 33.0, -18.0, ground(33, 0) + 0.8, 15.0, 1.6, seed=5, depth=2.6)
sbush(k, 36.0, KT - 2.6, ground(36, 0), 4.0, 1.3, seed=6)
sbush(k, 36.0, -21.0, ground(36, 0), 10.0, 2.4, seed=7, depth=2.4)
sbush(k, 40.0, -16.2, ground(40, 0), 9.0, 2.2, seed=11, depth=2.2)
sbush(k, 28.0, -17.0, ground(28, 0), 6.0, 1.9, seed=12, depth=2.0, light=True)
for i, (s_, t_) in enumerate(((35.5, -19.5), (44.0, -20.0))):
    x, z = frame(s_, t_)
    k.tree((x, ground(s_, 0), z), 1.0, "sibi", seed=70 + i, crown=4.6, lean=lean_to(s_, 0.4))
sbush(k, 34.0, 7.2, ground(34, 0), 24.0, 1.4, seed=8, depth=1.4)
sbush(k, 114.0, TR - 1.6, PZ(114) - 0.4, 44.0, 1.9, seed=9, depth=2.2)
sbush(k, 70.0, DT1 - 6.5, ground(70, 0), 30.0, 1.6, seed=10, depth=2.0)
x, z = frame(37.0, -20.5)
k.tube("metal_grey", (x, ground(37, 0), z), (x, ground(37, 0) + 9.0, z), 0.06, 0.05, 5, 3.0)

for s in (59.0, 60.2, 61.4):
    x, z = frame(s, 5.6)
    y = ground(s, 0)
    for side in (-0.35, 0.35):
        q = frame(s, 5.6 + side)
        k.beam("yellow", (q[0], y, q[1]), (q[0], y + 0.7, q[1]), 0.04, 4)
    a, b = frame(s, 5.25), frame(s, 5.95)
    k.beam("yellow", (a[0], y + 0.7, a[1]), (b[0], y + 0.7, b[1]), 0.04, 4)
for s in (100.0, 101.3):
    y = ground(s, 0)
    for side in (-0.35, 0.35):
        q = frame(s, TR + 2.2 + side)
        k.beam("yellow", (q[0], y, q[1]), (q[0], y + 0.7, q[1]), 0.04, 4)
    a, b = frame(s, TR + 1.85), frame(s, TR + 2.55)
    k.beam("yellow", (a[0], y + 0.7, a[1]), (b[0], y + 0.7, b[1]), 0.04, 4)

trees = [(35, 5.0, "plane", 1.15), (45, 5.0, "plane", 1.25), (66, 5.0, "plane", 1.1), (78, 5.2, "plane", 1.3), (112, 5.0, "plane", 1.2), (127, 4.6, "plane", 1.15),
         (99, -3.5, "ficus", 1.45), (117, -6.0, "ficus", 1.5), (131, -7.0, "ficus", 1.4)]
for i, (s, t, kind, sz) in enumerate(trees):
    x, z = frame(s, t)
    y = ground(s, 0)
    if kind == "plane":
        sbox(k, "curb", s, t, y - 0.1, (1.4, 0.15, 1.8), top="soil", col=None)
    k.tree((x, y, z), sz, kind, seed=i * 7 + 3, crown=(3.6 if kind == "plane" else 5.0) * sz, lean=lean_to(s, -0.5 if t > 0 else 0.6))
for i, (s, t) in enumerate([(100, -18), (112, -22), (126, -16), (106, -32), (122, -30)]):
    x, z = frame(s, t)
    k.tree((x, PZ(min(s, 136)), z), 1.7, "ficus" if i % 2 else "sibi", seed=50 + i, crown=7.5, lean=lean_to(s, 0.8))

for s, t in ((104.0, 1.0), (58.0, 1.5)):
    x, z = frame(s, t)
    y = ground(s, 0)
    k.tube("metal_grey", (x, y, z), (x, y + 10.5, z), 0.12, 0.09, 6, 4.0)
    for side in (-1, 1):
        q = frame(s + side * 1.3, t)
        k.beam("metal_grey", (x, y + 10.3, z), (q[0], y + 10.5, q[1]), 0.05, 4)
        k.box("lamp", (q[0], y + 10.25, q[1]), (0.5, 0.18, 0.7), yaw_of(s), col=None)
x, z = frame(128.0, 6.2)
y = ground(128, 0)
k.tube("metal_grey", (x, y, z), (x, y + 8, z), 0.1, 0.08, 6, 3.0)
q = frame(128.0, 3.5)
k.beam("metal_grey", (x, y + 8, z), (q[0], y + 8.6, q[1]), 0.05, 4)
k.box("lamp", (q[0], y + 8.4, q[1]), (0.6, 0.18, 0.4), yaw_of(128), col=None)

for s, t in ((120.0, -8.6),):
    sbox(k, "granite", s, t, ground(s, 0), (0.6, 0.45, 2.4))

k.clip(k.xmax)
tris = k.export("rc_calcadao")
json.dump({"range": [0, 137], "replaced": [0, 4, 19, 21, 22, 26, 28, 30, 32, 36, 37, 44, 47], "closed": [21], "clip_x": k.xmax, "lamps": [list(P(104, 1.0, 10.2)), list(P(58, 1.5, 10.2)), list(P(128, 3.5, 8.3))], "tris": tris}, open(os.path.join(OUTDIR, "rc_calcadao.json"), "w"))
