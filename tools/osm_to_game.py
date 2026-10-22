import json, math, sys, hashlib

src = sys.argv[1:-1]
out = sys.argv[-1]
lat0, lon0 = -23.5614, -46.6559
MASP_GAME = (-43.0, -92.0)


def xy(p):
    return ((p["lon"] - lon0) * 111320 * math.cos(math.radians(lat0)), (p["lat"] - lat0) * 110540)


els = {}
for f in src:
    for e in json.load(open(f))["elements"]:
        els[(e["type"], e["id"])] = e
els = list(els.values())
roads = [e for e in els if e.get("tags", {}).get("highway") and e["tags"].get("name") == "Avenida Paulista"]
pts = [xy(p) for w in roads for p in w["geometry"]]
mx = sum(p[0] for p in pts) / len(pts)
my = sum(p[1] for p in pts) / len(pts)
sxx = sum((p[0] - mx) ** 2 for p in pts)
syy = sum((p[1] - my) ** 2 for p in pts)
sxy = sum((p[0] - mx) * (p[1] - my) for p in pts)
ang = 0.5 * math.atan2(2 * sxy, sxx - syy)
u = (math.cos(ang), math.sin(ang))
if u[0] < 0:
    u = (-u[0], -u[1])
bins = {}
for p in pts:
    a = (p[0] - mx) * u[0] + (p[1] - my) * u[1]
    bins.setdefault(int(a // 40), []).append(p)
line = []
for k in sorted(bins):
    b = bins[k]
    line.append((sum(p[0] for p in b) / len(b), sum(p[1] for p in b) / len(b)))
cum = [0.0]
for i in range(1, len(line)):
    cum.append(cum[-1] + math.dist(line[i - 1], line[i]))


def project(p):
    best = None
    for i in range(len(line) - 1):
        a, b = line[i], line[i + 1]
        dx, dy = b[0] - a[0], b[1] - a[1]
        L2 = dx * dx + dy * dy
        t = max(0.0, min(1.0, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / L2))
        q = (a[0] + dx * t, a[1] + dy * t)
        d = math.dist(p, q)
        if best is None or d < best[0]:
            L = math.sqrt(L2)
            side = (dx * (p[1] - a[1]) - dy * (p[0] - a[0])) / L
            best = (d, cum[i] + t * L, side, (dx / L, dy / L))
    return best[1], best[2], best[3]


def centroid(ps):
    return (sum(p[0] for p in ps) / len(ps), sum(p[1] for p in ps) / len(ps))


masp = None
for e in els:
    t = e.get("tags", {})
    if t.get("name") == "Museu de Arte de São Paulo":
        masp = centroid([xy(p) for p in e["geometry"]])
sM, tM, _ = project(masp)
sign = -1.0 if tM > 0 else 1.0


def level_h(t):
    try:
        if "height" in t:
            return float(str(t["height"]).split()[0].replace(",", "."))
        if "building:levels" in t:
            return float(t["building:levels"]) * 3.2 + 2
    except ValueError:
        pass
    return 9.0


specials = {
    "fiesp": xy({"lat": -23.5634874, "lon": -46.6543937}),
    "gazeta": xy({"lat": -23.5654358, "lon": -46.6512009}),
    "safra": xy({"lat": -23.5580816, "lon": -46.6598019}),
    "conjunto": xy({"lat": -23.5590234, "lon": -46.6597666}),
    "center3": xy({"lat": -23.5583853, "lon": -46.6595770}),
}
owner = {}
for k, sc in specials.items():
    best = None
    for e in els:
        t = e.get("tags", {})
        if "building" not in t or e["type"] != "way":
            continue
        poly = [xy(p) for p in e["geometry"]]
        dd = min(math.dist(sc, p) for p in poly + [centroid(poly)])
        if level_h(t) < 25:
            continue
        if best is None or dd < best[0]:
            best = (dd, e["id"])
    owner[best[1]] = k
cand = []
for e in els:
    t = e.get("tags", {})
    if "building" not in t or e["type"] != "way":
        continue
    poly = [xy(p) for p in e["geometry"]]
    c = centroid(poly)
    if math.dist(c, specials["conjunto"]) > 110:
        continue
    s0, side0, _ = project(c)
    if abs(side0) > 60:
        continue
    ss = [project(p)[0] for p in poly]
    cand.append((max(ss) - min(ss), e["id"], level_h(t)))
cand.sort(reverse=True)
owner = {i: k for i, k in owner.items() if k != "conjunto"}
for ln, i, hh in cand[:2]:
    owner[i] = "conjunto"
for e in els:
    if e.get("tags", {}).get("name") == "Edifício Luís Eulálio de Bueno Vidigal Filho":
        owner = {i: k for i, k in owner.items() if k != "fiesp"}
        owner[e["id"]] = "fiesp"
        e["tags"]["height"] = "90"
result = []
for e in els:
    t = e.get("tags", {})
    if "building" not in t or e["type"] != "way" or len(e["geometry"]) < 4:
        continue
    poly = [xy(p) for p in e["geometry"]][:-1]
    c = centroid(poly)
    s, side, d = project(c)
    rel = s - sM
    if rel < -800 or rel > 750 or abs(side) > 230 or abs(side) < 22:
        continue
    if t.get("name") == "Museu de Arte de São Paulo":
        continue
    gx = sign * side
    gz = MASP_GAME[1] - rel
    ex = (d[0], d[1])
    nx = (-d[1], d[0])
    gp = []
    for p in poly:
        a = (p[0] - c[0]) * ex[0] + (p[1] - c[1]) * ex[1]
        b = (p[0] - c[0]) * nx[0] + (p[1] - c[1]) * nx[1]
        gp.append([round(gx + sign * b, 2), round(gz - a, 2)])
    h = level_h(t)
    style = owner.get(e["id"], "")
    if style == "conjunto":
        h = max(h, 24.0)
    hh = int(hashlib.md5(str(e["id"]).encode()).hexdigest(), 16)
    result.append({"p": gp, "h": round(h, 1), "style": style, "seed": hh % 100000, "name": t.get("name", ""), "front": abs(side) < 45})
json.dump({"masp_side": sign, "buildings": result}, open(out, "w"), ensure_ascii=False)
print(len(result), "buildings", "specials", list(specials), "styled", sum(1 for r in result if r["style"]))
