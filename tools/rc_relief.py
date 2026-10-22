import json, math, sys

path = sys.argv[1]
d = json.load(open(path))
st = d["street"]


def interp(pts, x):
    for a, b in zip(pts, pts[1:]):
        if min(a[0], b[0]) <= x <= max(a[0], b[0]) and a[0] != b[0]:
            t = (x - a[0]) / (b[0] - a[0])
            return a[1] + (b[1] - a[1]) * t
    return pts[0][1] if abs(x - pts[0][0]) < abs(x - pts[-1][0]) else pts[-1][1]


old = [(s["p"][0], s["y"]) for s in st]
far = interp(old, -200.0)


def target(x):
    if x >= -34.0:
        return 0.0
    if x <= -200.0:
        return interp(old, x)
    t = (-34.0 - x) / 166.0
    return far * t * t * (3 - 2 * t)


def seg_dist(q, a, b):
    ab = (b[0] - a[0], b[1] - a[1])
    L2 = max(ab[0] ** 2 + ab[1] ** 2, 1e-6)
    t = max(0.0, min(1.0, ((q[0] - a[0]) * ab[0] + (q[1] - a[1]) * ab[1]) / L2))
    p = (a[0] + ab[0] * t, a[1] + ab[1] * t)
    return math.dist(q, p), p


def nearest(q):
    best = (1e9, None)
    for a, b in zip(st, st[1:]):
        r = seg_dist(q, a["p"], b["p"])
        if r[0] < best[0]:
            best = r
    return best


dense = [st[0]]
for a, b in zip(st, st[1:]):
    L = math.dist(a["p"], b["p"])
    n = max(1, int(L / 8.0)) if a["p"][0] > -200 and b["p"][0] < -30 else 1
    for i in range(1, n):
        t = i / n
        dense.append({"p": [round(a["p"][0] + (b["p"][0] - a["p"][0]) * t, 2), round(a["p"][1] + (b["p"][1] - a["p"][1]) * t, 2)], "y": 0.0, "w": a["w"] if a["w"] == b["w"] else b["w"]})
    dense.append(b)
oldf = lambda q: interp(old, q[0])


def delta(q):
    dist, p = nearest(q)
    fade = max(0.0, 1.0 - dist / 70.0)
    return (target(p[0]) - oldf(p)) * fade


g = d["grid"]
h = g["h"]
for j in range(g["nz"]):
    for i in range(g["nx"]):
        q = (g["x0"] + i * g["step"], g["z0"] + j * g["step"])
        h[j * g["nx"] + i] = round(h[j * g["nx"] + i] + delta(q), 2)
for b in d["buildings"]:
    c = (sum(p[0] for p in b["p"]) / len(b["p"]), sum(p[1] for p in b["p"]) / len(b["p"]))
    b["y"] = round(b["y"] + delta(c), 2)
for c in d["cross"]:
    for q in c["pts"]:
        q["y"] = round(q["y"] + delta(q["p"]), 2)
for s in dense:
    s["y"] = round(target(s["p"][0]), 2)
d["street"] = dense
json.dump(d, open(path, "w"), ensure_ascii=False)
print([(s["p"][0], s["y"], s["w"]) for s in dense])
