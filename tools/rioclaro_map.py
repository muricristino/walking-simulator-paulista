import json, math, subprocess, sys

rc = json.load(open(sys.argv[1]))
pa = json.load(open(sys.argv[2]))
out = sys.argv[3]
n = rc["north"]
ang = math.atan2(n[0], -n[1])
S = 1.6
cx, cz = -200.0, -330.0
W, H = 1280, 960


def tp(x, z):
    dx, dz = x - cx, z - cz
    rx = dx * math.cos(-ang) - dz * math.sin(-ang)
    rz = dx * math.sin(-ang) + dz * math.cos(-ang)
    return W / 2 + rx * S, H / 2 + rz * S


cmd = ["magick", "-size", f"{W}x{H}", "xc:#e9e5dc"]
draws = []
for b in pa["buildings"]:
    pts = [tp(p[0], p[1]) for p in b["p"]]
    if all(-50 < x < W + 50 and -50 < y < H + 50 for x, y in pts):
        draws.append(("#b9b2a6", pts))
for b in rc["buildings"]:
    v = max(0.25, 0.75 - b["h"] / 160)
    c = "#%02x%02x%02x" % (int(255 * v), int(240 * v), int(225 * v))
    draws.append((c, [tp(p[0], p[1]) for p in b["p"]]))
for col, pts in draws:
    cmd += ["-fill", col, "-stroke", "#5a5248", "-strokewidth", "1", "-draw", "polygon " + " ".join(f"{x:.1f},{y:.1f}" for x, y in pts)]
paul = [tp(0, z) for z in (-760, 60)]
cmd += ["-stroke", "#3a3a3a", "-strokewidth", str(32 * S), "-draw", f"line {paul[0][0]:.1f},{paul[0][1]:.1f} {paul[1][0]:.1f},{paul[1][1]:.1f}"]
for c in rc["cross"]:
    pts = [tp(q["p"][0], q["p"][1]) for q in c["pts"]]
    cmd += ["-fill", "none", "-stroke", "#555", "-strokewidth", str(c["w"] * S), "-draw", "polyline " + " ".join(f"{x:.1f},{y:.1f}" for x, y in pts)]
st = [tp(q["p"][0], q["p"][1]) for q in rc["street"]]
cmd += ["-fill", "none", "-stroke", "#c0392b", "-strokewidth", str(8 * S), "-draw", "polyline " + " ".join(f"{x:.1f},{y:.1f}" for x, y in st)]
cmd += ["-stroke", "none", "-fill", "#222", "-pointsize", "22", "-annotate", f"+{st[len(st) // 2][0]:.0f}+{st[len(st) // 2][1] - 18:.0f}", "Alameda Rio Claro",
        "-annotate", f"+{paul[0][0] + 10:.0f}+{min(H - 30, max(30, paul[0][1])):.0f}", "Av. Paulista"]
for p in rc["pois"]:
    x, y = tp(p["p"][0], p["p"][1])
    cmd += ["-fill", "#1a5fb4", "-draw", f"circle {x:.0f},{y:.0f} {x + 5:.0f},{y:.0f}", "-pointsize", "16", "-annotate", f"+{x + 8:.0f}+{y:.0f}", p["name"]]
cmd += ["-fill", "#222", "-pointsize", "26", "-annotate", f"+{W - 70}+50", "N", "-stroke", "#222", "-strokewidth", "3", "-draw", f"line {W - 60},60 {W - 60},110", "-draw", f"line {W - 60},60 {W - 70},75", "-draw", f"line {W - 60},60 {W - 50},75"]
cmd += ["-stroke", "none", "-pointsize", "16", "-annotate", "+20+940", "City Look - dados OSM (c) OpenStreetMap contributors. Escala: 100 m = %d px" % int(100 * S), out]
subprocess.run(cmd, check=True)
