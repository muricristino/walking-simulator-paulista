import json, math, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rc_lib import DATA, OUTDIR, frame, gy, street_y

CURB = 0.17


def lane(name, kind, s0, s1, t, w, lift=CURB, step=4.0):
    n = max(1, int(math.ceil((s1 - s0) / step)))
    pts = []
    for i in range(n + 1):
        s = s0 + (s1 - s0) * i / n
        x, z = frame(s, t)
        pts.append([round(x, 2), round(gy(s, 0.0) + lift, 2), round(z, 2)])
    return {"name": name, "kind": kind, "width": w, "pts": pts}


def cross_lane(name, street, J, lim, off, w, step=4.0):
    pts = [tuple(q["p"]) for q in [c for c in DATA["cross"] if c["name"] == street][0]["pts"]]
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

    u0 = min((i / 2 for i in range(int(cum[-1] * 2))), key=lambda u: math.dist(at(u)[0], J))
    out = []
    u = max(0.0, u0 - lim)
    while u <= min(cum[-1], u0 + lim):
        p, d = at(u)
        x, z = p[0] - d[1] * off, p[1] + d[0] * off
        out.append([round(x, 2), round(street_y(x, z) + CURB, 2), round(z, 2)])
        u += step
    return {"name": name, "kind": "sidewalk", "width": w, "pts": out}


def pt(s, t, lift=CURB):
    x, z = frame(s, t)
    return [round(x, 2), round(gy(s, 0.0) + lift, 2), round(z, 2)]


paths = [
    lane("calcadao_a", "plaza", 18.0, 133.0, 1.5, 3.0),
    lane("calcadao_b", "plaza", 22.0, 133.0, 6.8, 1.6),
    lane("rua_left", "sidewalk", 143.5, 406.0, 5.0, 1.4),
    lane("rua_right", "sidewalk", 143.5, 406.0, -5.0, 1.4),
]
paths += [
    {"name": "sao_carlos_left", "kind": "crossing", "width": 3.0, "pts": [pt(133.0, 5.0), pt(143.5, 5.0)]},
    {"name": "sao_carlos_right", "kind": "crossing", "width": 3.0, "pts": [pt(133.0, -5.0), pt(143.5, -5.0)]},
    {"name": "zebra_146", "kind": "crossing", "width": 3.0, "pts": [pt(146.6, -5.0), pt(146.6, 5.0)]},
    {"name": "zebra_303", "kind": "crossing", "width": 3.0, "pts": [pt(303.6, -5.0), pt(303.6, 5.0)]},
]
JP = frame(414.0, 0)
paths += [cross_lane("pamplona_a", "Rua Pamplona", JP, 140.0, 7.2, 1.6), cross_lane("pamplona_b", "Rua Pamplona", JP, 140.0, -7.2, 1.6)]
json.dump({"paths": paths}, open(os.path.join(OUTDIR, "rc_walk.json"), "w"), indent=0)
print("paths", len(paths), sum(len(p["pts"]) for p in paths))
