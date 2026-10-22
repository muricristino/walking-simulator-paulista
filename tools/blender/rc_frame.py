import json, math, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
LAT0, LON0 = -23.5614, -46.6559


def xy(lat, lon):
    return ((lon - LON0) * 111320 * math.cos(math.radians(LAT0)), (lat - LAT0) * 110540)


def make(src0, src1, dst0, dst1, refl):
    a = math.atan2(dst1[1] - dst0[1], dst1[0] - dst0[0]) - math.atan2(refl * (src1[1] - src0[1]), src1[0] - src0[0])
    c, s = math.cos(a), math.sin(a)

    def f(p):
        x, y = p[0] - src0[0], refl * (p[1] - src0[1])
        return (dst0[0] + c * x - s * y, dst0[1] + s * x + c * y)

    return f, a, refl


def solve(area_json):
    rc = json.load(open(os.path.join(ROOT, "assets/osm/rioclaro.json")))
    ae = json.load(open(area_json))["elements"]
    src = []
    for e in ae:
        if e.get("tags", {}).get("name") == "Alameda Rio Claro":
            src += [xy(p["lat"], p["lon"]) for p in e["geometry"]]
    dst = [tuple(s["p"]) for s in rc["street"]]
    D = math.dist(dst[0], dst[-1])
    best = None
    for i, a in enumerate(src):
        for j, b in enumerate(src):
            if i == j or abs(math.dist(a, b) - D) > 0.1:
                continue
            for refl in (1.0, -1.0):
                f, ang, r = make(a, b, dst[0], dst[-1], refl)
                err = sum(min(math.dist(f(p), q) for p in src) for q in dst)
                if best is None or err < best[0]:
                    best = (err, f, ang, r)
    return best


if __name__ == "__main__":
    err, f, ang, refl = solve(sys.argv[1])
    pts = json.load(open(sys.argv[2]))
    out = {"err": err, "angle": ang, "refl": refl, "points": []}
    for p in pts:
        g = f(xy(p["lat"], p["lon"]))
        h = math.radians(p["h"])
        ahead = xy(p["lat"] + math.cos(h) * 1e-4, p["lon"] + math.sin(h) * 1e-4 / math.cos(math.radians(LAT0)) * 110540 / 111320 * 1)
        g2 = f(ahead)
        d = (g2[0] - g[0], g2[1] - g[1])
        n = math.hypot(*d)
        out["points"].append({"m": p["m"], "p": [round(g[0], 2), round(g[1], 2)], "dir": [round(d[0] / n, 4), round(d[1] / n, 4)]})
    json.dump(out, open(sys.argv[3], "w"), indent=1)
    print(json.dumps(out, indent=1))
