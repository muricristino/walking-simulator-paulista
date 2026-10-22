import json, math, os, sys, urllib.parse, urllib.request
import numpy as np

src, out, cache = sys.argv[1], sys.argv[2], sys.argv[3]
os.makedirs(cache, exist_ok=True)
LAT0, LON0 = -23.5614, -46.6559
KX, KY = 111320 * math.cos(math.radians(LAT0)), 110540
WFS = "https://wfs.geosampa.prefeitura.sp.gov.br/geoserver/geoportal/wfs"
OVERPASS = "https://overpass-api.de/api/interpreter"
UA = {"User-Agent": "city-look/1.0"}


def get(name, url, data=None):
    path = os.path.join(cache, name)
    if not os.path.exists(path):
        req = urllib.request.Request(url, data=data.encode() if data else None, headers=UA)
        open(path, "wb").write(urllib.request.urlopen(req, timeout=180).read())
    return json.load(open(path))


def xy(lon, lat):
    return ((lon - LON0) * KX, (lat - LAT0) * KY)


def lonlat(x, y):
    return (x / KX + LON0, y / KY + LAT0)


d = json.load(open(src))
osm = get("rioclaro_osm.json", OVERPASS, "data=" + urllib.parse.quote('[out:json];way["name"="Alameda Rio Claro"](-23.566,-46.657,-23.558,-46.649);out geom;'))
ways = {e["tags"]["highway"]: [xy(p["lon"], p["lat"]) for p in e["geometry"]] for e in osm["elements"] if e["tags"].get("name") == "Alameda Rio Claro"}
ped, res = ways["pedestrian"], ways["residential"]
if math.dist(ped[0], res[0]) < 1 or math.dist(ped[0], res[-1]) < 1:
    ped = ped[::-1]
if math.dist(res[-1], ped[-1]) < 1:
    res = res[::-1]
line = ped + res[1:]
gs = [tuple(s["p"]) for s in d["street"]]
ang = math.atan2(gs[-1][1] - gs[0][1], gs[-1][0] - gs[0][0]) - math.atan2(-(line[-1][1] - line[0][1]), line[-1][0] - line[0][0])
C, S = math.cos(ang), math.sin(ang)


def to_real(gx, gz):
    dx, dz = gx - gs[0][0], gz - gs[0][1]
    rx = C * dx + S * dz
    ry = -(-S * dx + C * dz)
    return (line[0][0] + rx, line[0][1] + ry)


g = d["grid"]
corners = [to_real(g["x0"] + a * g["step"] * (g["nx"] - 1), g["z0"] + b * g["step"] * (g["nz"] - 1)) for a in (0, 1) for b in (0, 1)]
lo = lonlat(min(c[0] for c in corners) - 80, min(c[1] for c in corners) - 80)
hi = lonlat(max(c[0] for c in corners) + 80, max(c[1] for c in corners) + 80)
bbox = "%.5f,%.5f,%.5f,%.5f,EPSG:4326" % (lo[0], lo[1], hi[0], hi[1])
base_q = "?service=WFS&version=1.1.0&request=GetFeature&outputFormat=application/json&srsName=EPSG:4326&bbox=" + bbox + "&typeName=geoportal:"
pts, lev = [], []
for layer in ("curva_intermediaria", "curva_mestra"):
    for f in get(layer + ".json", WFS + base_q + layer)["features"]:
        z = float(f["properties"]["cd_numero_isovalor"])
        geo = f["geometry"]
        for cs in ([geo["coordinates"]] if geo["type"] == "LineString" else geo["coordinates"]):
            q = [xy(*c) for c in cs]
            for a, b in zip(q, q[1:]):
                n = max(1, int(math.dist(a, b) / 1.5))
                for i in range(n):
                    pts.append((a[0] + (b[0] - a[0]) * i / n, a[1] + (b[1] - a[1]) * i / n))
                    lev.append(z)
P = np.array(pts)
L = np.array(lev)
levels = np.unique(L)
spots = [(xy(*f["geometry"]["coordinates"]), f["properties"]["cd_altitude"]) for f in get("ponto_cotado.json", WFS + base_q + "ponto_cotado")["features"]]


def contour_z(q):
    q = np.asarray(q)
    dist = np.full((len(q), len(levels)), 1e9)
    for i, lv in enumerate(levels):
        m = L == lv
        pp = P[m]
        for k in range(0, len(q), 256):
            dd = np.sqrt(((q[k:k + 256, None, :] - pp[None, :, :]) ** 2).sum(-1)).min(1)
            dist[k:k + 256, i] = dd
    z = np.zeros(len(q))
    for r in range(len(q)):
        i1 = int(np.argmin(dist[r]))
        cand = [j for j in (i1 - 1, i1 + 1) if 0 <= j < len(levels)]
        i2 = min(cand, key=lambda j: dist[r, j])
        d1, d2 = dist[r, i1], dist[r, i2]
        z[r] = (levels[i1] * d2 + levels[i2] * d1) / max(d1 + d2, 1e-6)
    return z


sp = np.array([s[0] for s in spots])
resid = np.array([s[1] for s in spots]) - contour_z(sp)


def elev(q):
    q = np.asarray(q, dtype=float)
    z = contour_z(q)
    dd = np.sqrt(((q[:, None, :] - sp[None, :, :]) ** 2).sum(-1))
    w = np.clip(1.0 - dd / 35.0, 0.0, 1.0) ** 2
    ws = w.sum(1)
    return z + np.where(ws > 0, (w * resid[None, :]).sum(1) / np.maximum(ws, 1e-6) * np.minimum(ws, 1.0), 0.0)


def game_elev(gpts):
    return elev([to_real(*p) for p in gpts])


base = float(game_elev([gs[0]])[0])


def flat(gx):
    t = min(max((-gx - 34.0) / 30.0, 0.0), 1.0)
    return t * t * (3 - 2 * t)


nodes = [(g["x0"] + i * g["step"], g["z0"] + j * g["step"]) for j in range(g["nz"]) for i in range(g["nx"])]
H = (game_elev(nodes) - base).reshape(g["nz"], g["nx"])
for _ in range(2):
    E = np.pad(H, 1, mode="edge")
    H = (4 * E[1:-1, 1:-1] + 2 * (E[:-2, 1:-1] + E[2:, 1:-1] + E[1:-1, :-2] + E[1:-1, 2:]) + E[:-2, :-2] + E[:-2, 2:] + E[2:, :-2] + E[2:, 2:]) / 16.0
g["h"] = [round(float(h) * flat(p[0]), 2) for p, h in zip(nodes, H.ravel())]
cum = np.cumsum([0.0] + [math.dist(a, b) for a, b in zip(gs, gs[1:])])
samp = np.arange(0.0, cum[-1] + 0.5, 2.0)
sx = np.interp(samp, cum, [p[0] for p in gs])
sz = np.interp(samp, cum, [p[1] for p in gs])
sy = game_elev(list(zip(sx, sz)))
for s, c in zip(d["street"], cum):
    w = np.exp(-0.5 * ((samp - c) / 12.0) ** 2)
    s["y"] = round(float((w * sy).sum() / w.sum() - base) * flat(s["p"][0]), 2)
for c in d["cross"]:
    for q, h in zip(c["pts"], game_elev([tuple(q["p"]) for q in c["pts"]])):
        q["y"] = round(float(h - base) * flat(q["p"][0]), 2)
for b in d["buildings"]:
    hs = game_elev([tuple(p) for p in b["p"]])
    b["y"] = round(float(hs.min() - base) * flat(sum(p[0] for p in b["p"]) / len(b["p"])), 2)
for p in d["pois"]:
    p["y"] = round(float(game_elev([tuple(p["p"])])[0] - base) * flat(p["p"][0]), 2)
d["base_elev"] = round(base, 2)
d["elev_source"] = "GeoSampa curvas de nivel 1 m (curva_intermediaria, curva_mestra) e ponto_cotado, escala 1:1000/1:5000"
json.dump(d, open(out, "w"), ensure_ascii=False)
print("base", round(base, 2))
print([(int(c), s["y"]) for c, s in zip(cum, d["street"])])
