import json, math, sys, hashlib

paulista_json, area_json, roads_json, tile_rgb, out = sys.argv[1:6]
lat0, lon0 = -23.5614, -46.6559
MASP_GAME = (-43.0, -92.0)
TZ, TX, TY = 15, 12137, 18591


def xy(p):
    return ((p["lon"] - lon0) * 111320 * math.cos(math.radians(lat0)), (p["lat"] - lat0) * 110540)


raw = open(tile_rgb, "rb").read()


def elev(lat, lon):
    n = 2 ** TZ
    px = ((lon + 180) / 360 * n - TX) * 256 - 0.5
    py = ((1 - math.asinh(math.tan(math.radians(lat))) / math.pi) / 2 * n - TY) * 256 - 0.5
    x0, y0 = int(math.floor(px)), int(math.floor(py))
    fx, fy = px - x0, py - y0

    def h(x, y):
        x = max(0, min(255, x))
        y = max(0, min(255, y))
        i = (y * 256 + x) * 3
        return raw[i] * 256 + raw[i + 1] + raw[i + 2] / 256 - 32768

    def g(x, y):
        return min(h(x + dx, y + dy) for dx in range(-3, 4) for dy in range(-3, 4))

    a = g(x0, y0) * (1 - fx) + g(x0 + 1, y0) * fx
    b = g(x0, y0 + 1) * (1 - fx) + g(x0 + 1, y0 + 1) * fx
    return a * (1 - fy) + b * fy


def unxy(x, y):
    return {"lat": y / 110540 + lat0, "lon": x / (111320 * math.cos(math.radians(lat0))) + lon0}


pe = json.load(open(paulista_json))["elements"]
roads = [e for e in pe if e.get("tags", {}).get("highway") and e["tags"].get("name") == "Avenida Paulista"]
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
line = [(sum(p[0] for p in b) / len(b), sum(p[1] for p in b) / len(b)) for k, b in sorted(bins.items())]
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
            best = (d, cum[i] + t * L, side, (dx / L, dy / L), q)
    return best


masp = None
for e in pe:
    if e.get("tags", {}).get("name") == "Museu de Arte de São Paulo":
        g = [xy(p) for p in e["geometry"]]
        masp = (sum(p[0] for p in g) / len(g), sum(p[1] for p in g) / len(g))
_, sM, tM, _, _ = project(masp)
sign = -1.0 if tM > 0 else 1.0

ae = json.load(open(area_json))["elements"]
re_ = json.load(open(roads_json))["elements"]
rc = [e for e in ae if e.get("tags", {}).get("name") == "Alameda Rio Claro"]
ped = [e for e in rc if e["tags"]["highway"] == "pedestrian"][0]
res = [e for e in rc if e["tags"]["highway"] == "residential"][0]
chain = [xy(p) for p in res["geometry"]]
pchain = [xy(p) for p in ped["geometry"]]
if project(pchain[0])[0] > project(pchain[-1])[0]:
    pchain = pchain[::-1]
if math.dist(chain[0], pchain[-1]) > math.dist(chain[-1], pchain[-1]):
    chain = chain[::-1]
start = pchain[0]
_, s0, t0, d0, q0 = project(start)
ex = d0
nx = (-d0[1], d0[0])
gx0 = 0.0
gz0 = MASP_GAME[1] - (s0 - sM)
base = elev(**unxy(*q0))


def tog(p):
    a = (p[0] - q0[0]) * ex[0] + (p[1] - q0[1]) * ex[1]
    b = (p[0] - q0[0]) * nx[0] + (p[1] - q0[1]) * nx[1]
    return [round(gx0 + sign * b, 2), round(gz0 - a, 2)]


def ey(p):
    return round(elev(**unxy(*p)) - base, 2)


seq = pchain + chain[1:]
street = [{"p": tog(p), "y": ey(p), "w": 20.0 if i < len(pchain) - 1 else 6.0} for i, p in enumerate(seq)]
cross = []
for e in re_:
    t = e.get("tags", {})
    if t.get("name") in ("Rua Pamplona", "Rua São Carlos do Pinhal"):
        g = [xy(p) for p in e["geometry"]]
        lanes = float(t.get("lanes", "2"))
        cross.append({"name": t["name"], "w": lanes * 3.2, "pts": [{"p": tog(p), "y": ey(p)} for p in g]})
blds = []
for e in ae:
    t = e.get("tags", {})
    if "building" not in t or e["type"] != "way":
        continue
    g = [xy(p) for p in e["geometry"]][:-1]
    try:
        h = float(str(t.get("height", "")).split()[0].replace(",", ".")) if "height" in t else (float(t["building:levels"]) * 3.2 + 2 if "building:levels" in t else 9.0)
    except ValueError:
        h = 9.0
    if project((sum(p[0] for p in g) / len(g), sum(p[1] for p in g) / len(g)))[0] < 26:
        continue
    ys = [ey(p) for p in g]
    hh = int(hashlib.md5(str(e["id"]).encode()).hexdigest(), 16)
    blds.append({"p": [tog(p) for p in g], "h": round(h, 1), "y": min(ys), "style": "", "seed": hh % 100000, "name": t.get("name", ""), "front": True})
pois = []
for e in ae:
    t = e.get("tags", {})
    if ("shop" in t or "amenity" in t) and "name" in t:
        c = xy(e) if e["type"] == "node" else xy({"lat": sum(q["lat"] for q in e["geometry"]) / len(e["geometry"]), "lon": sum(q["lon"] for q in e["geometry"]) / len(e["geometry"])})
        pois.append({"name": t["name"], "kind": t.get("shop") or t.get("amenity"), "p": tog(c), "y": ey(c)})
inv_a = None


def fromg(gx, gz):
    b = (gx - gx0) * sign
    a = gz0 - gz
    return (q0[0] + ex[0] * a + nx[0] * b, q0[1] + ex[1] * a + nx[1] * b)


allx = [p[0] for b in blds for p in b["p"]] + [s["p"][0] for s in street]
allz = [p[1] for b in blds for p in b["p"]] + [s["p"][1] for s in street]
step = 8.0
x0g, x1g = math.floor(min(allx) / step) * step - 16, math.ceil(max(allx) / step) * step + 16
z0g, z1g = math.floor(min(allz) / step) * step - 16, math.ceil(max(allz) / step) * step + 16
nxg = int((x1g - x0g) / step) + 1
nzg = int((z1g - z0g) / step) + 1
grid = [round(elev(**unxy(*fromg(x0g + i * step, z0g + j * step))) - base, 2) for j in range(nzg) for i in range(nxg)]
json.dump({"north": [sign * nx[1], -ex[1]], "grid": {"x0": x0g, "z0": z0g, "step": step, "nx": nxg, "nz": nzg, "h": grid}, "street": street, "cross": cross, "buildings": blds, "pois": pois, "base_elev": round(base, 1)}, open(out, "w"), ensure_ascii=False)
print("street pts", len(street), "drop", street[0]["y"], "->", street[-1]["y"], "start", street[0]["p"], "end", street[-1]["p"], "bld", len(blds), "pois", pois)
