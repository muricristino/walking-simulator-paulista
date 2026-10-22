import os, struct, subprocess, sys, zlib
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets/rioclaro/tex")
DL = sys.argv[1] if len(sys.argv) > 1 else ""
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)


def save(name, a):
    a = np.clip(a, 0, 1)
    h, w = a.shape[:2]
    ch = a.shape[2]
    b = (a * 255 + 0.5).astype(np.uint8)
    raw = b"".join(b"\x00" + b[y].tobytes() for y in range(h))
    ct = 6 if ch == 4 else 2

    def chunk(t, d):
        c = struct.pack(">I", len(d)) + t + d
        return c + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, ct, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    open(os.path.join(OUT, name + ".png"), "wb").write(png)


def col(c):
    return np.array(c, dtype=float)[:3]


def fill(w, h, c, noise=0.04, blot=0.0, scale=8):
    a = np.ones((h, w, 3)) * col(c)
    a += rng.normal(0, noise, (h, w, 1))
    if blot:
        sm = rng.normal(0, 1, (h // scale + 2, w // scale + 2))
        big = np.kron(sm, np.ones((scale, scale)))[:h, :w]
        big = (big + np.roll(big, scale // 2, 0) + np.roll(big, scale // 2, 1) + np.roll(np.roll(big, scale // 2, 0), scale // 2, 1)) / 4
        a += big[..., None] * blot
    return a


def rect(a, x0, y0, x1, y1, c, k=1.0):
    a[y0:y1, x0:x1, :3] = a[y0:y1, x0:x1, :3] * (1 - k) + col(c) * k


def herringbone():
    u = 8
    n = 16
    cell = -np.ones((n, n), dtype=int)
    bid = 0
    for s in range(-n, n * 2, 4):
        for k in range(-n * 2, n * 2):
            for cells in (((k, k + s), (k + 1, k + s)), ((k, k + s + 1), (k, k + s + 2))):
                for (i, j) in cells:
                    cell[j % n, i % n] = bid
                bid += 1
    a = np.zeros((n * u, n * u, 3))
    shades = {}
    for b in np.unique(cell):
        r = rng.random()
        base = np.array([0.50, 0.47, 0.44]) if r < 0.6 else (np.array([0.56, 0.44, 0.38]) if r < 0.85 else np.array([0.40, 0.39, 0.38]))
        shades[b] = base * rng.uniform(0.85, 1.12)
    for y in range(n * u):
        for x in range(n * u):
            i, j = x // u, y // u
            b = cell[j, i]
            c = shades[b].copy()
            edge = False
            if x % u == 0 and cell[j, (i - 1) % n] != b:
                edge = True
            if y % u == 0 and cell[(j - 1) % n, i] != b:
                edge = True
            a[y, x] = c * (0.45 if edge else 1.0)
    a += rng.normal(0, 0.025, a.shape[:2])[..., None]
    save("paver", a)


def wood_deck():
    a = fill(64, 64, (0.42, 0.33, 0.25), 0.03)
    for x in range(0, 64, 8):
        a[:, x:x + 8] *= rng.uniform(0.8, 1.15)
        a[:, x] *= 0.5
        a[rng.integers(0, 64), x:x + 8] *= 0.6
    for y in range(64):
        a[y] *= 1 + 0.06 * np.sin(np.arange(64) * 0.9 + y * 0.05)[:, None]
    save("deck", a * np.array([0.95, 0.95, 0.9]))


def copper():
    a = fill(64, 64, (0.62, 0.36, 0.22), 0.025)
    for y in range(64):
        a[y] *= 1 + 0.05 * np.sin(np.arange(64) * 0.3 + y * 0.7)[:, None]
    for y in range(0, 64, 16):
        a[y] *= 0.7
    save("copper", a)
    s = np.zeros((32, 64, 4))
    for x in range(0, 64, 8):
        s[:, x:x + 4, :3] = col((0.66, 0.38, 0.22)) * rng.uniform(0.9, 1.1)
        s[:, x + 3, :3] *= 0.65
        s[:, x:x + 4, 3] = 1
    s[:, :, :3] += rng.normal(0, 0.02, (32, 64, 1))
    save("slats", s)


def granite():
    a = fill(64, 64, (0.66, 0.62, 0.56), 0.05, 0.03, 4)
    for y in (0, 32):
        a[y] *= 0.6
    for x in (0, 64 // 2):
        a[0:32, x] *= 0.6
    for x in (16, 48):
        a[32:64, x] *= 0.6
    a[48:64] *= np.linspace(1, 0.82, 16)[:, None, None]
    save("granite", a)


def windows(name, w, h, cols, rows, frame, glass, sill=None, lit=0.35, mull=1, refl=0.0, balcony=None):
    a = np.ones((h, w, 3)) * col(frame)
    a += rng.normal(0, 0.02, (h, w, 1))
    e = np.zeros((h, w, 3))
    cw, rh = w // cols, h // rows
    for r in range(rows):
        for c in range(cols):
            x0, y0 = c * cw + mull, r * rh + mull
            x1, y1 = (c + 1) * cw - mull, (r + 1) * rh - (sill if sill else mull)
            g = col(glass) * rng.uniform(0.8, 1.15)
            a[y0:y1, x0:x1] = g
            if refl:
                yy = np.arange(y0, y1)[:, None]
                xx = np.arange(x0, x1)[None, :]
                a[y0:y1, x0:x1] += (refl * np.clip(np.sin((xx + yy * 0.6) * 0.25) , 0, 1))[..., None] * np.array([0.7, 0.8, 0.9])
            if rng.random() < lit:
                e[y0:y1, x0:x1] = np.array([1.0, 0.78, 0.45]) * rng.uniform(0.6, 1.0)
            if balcony:
                bh = max(2, (y1 - y0) // 3)
                a[y1 - bh:y1, x0 - mull:x1 + mull] = col(balcony) * rng.uniform(0.95, 1.05)
                e[y1 - bh:y1, x0 - mull:x1 + mull] = 0
    save(name, a)
    save(name + "_e", e)


def panel_dark():
    a = fill(64, 64, (0.30, 0.31, 0.33), 0.02, 0.02, 8)
    for y in range(0, 64, 16):
        a[y] *= 0.6
    for x in range(0, 64, 32):
        a[:, x] *= 0.7
    save("panel_dark", a)


def concrete_wall():
    a = fill(64, 64, (0.70, 0.69, 0.66), 0.04, 0.05, 8)
    for x in (0, 32):
        a[:, x] *= 0.75
    a[56:64] *= np.linspace(1, 0.75, 8)[:, None, None]
    for k in range(4):
        x = rng.integers(0, 60)
        a[0:rng.integers(10, 50), x:x + 2] *= 0.88
    save("concrete_wall", a)


def fence(name, w, h, bar, gap, c=(0.12, 0.12, 0.12), rails=(1, -3)):
    a = np.zeros((h, w, 4))
    for x in range(0, w, bar + gap):
        a[:, x:x + bar, :3] = col(c)
        a[:, x:x + bar, 3] = 1
    for r in rails:
        a[r:r + 2 if r >= 0 else (r + 2 if r + 2 < 0 else None), :, :3] = col(c)
        a[r:r + 2 if r >= 0 else (r + 2 if r + 2 < 0 else None), :, 3] = 1
    save(name, a)


def flat(name, c, n=0.03, size=16):
    save(name, fill(size, size, c, n))


def roof_canopy():
    a = fill(64, 64, (0.82, 0.83, 0.82), 0.02, 0.03, 8)
    for x in range(0, 64, 16):
        a[:, x] *= 0.8
    save("canopy_roof", a)


def food_red():
    a = fill(128, 32, (0.70, 0.20, 0.17), 0.03)
    wl = np.array([0.95, 0.92, 0.88])
    x = 0
    y = 18
    while x < 128:
        w = rng.integers(4, 12)
        hh = rng.integers(6, 16)
        a[32 - 6 - hh, x:x + w] = wl
        a[32 - 6 - hh:26, x] = wl
        x += w
    a[26, :] = wl
    for cx in (20, 70, 110):
        a[8:16, cx] = wl
        a[8:11, cx - 2:cx + 3:2] = wl
        a[8:16, cx + 6] = wl
    a[0:3] = col((0.85, 0.85, 0.83))
    save("food_red", a)


def stainless():
    a = fill(64, 64, (0.64, 0.64, 0.63), 0.02)
    for x in range(0, 64, 16):
        a[:, x] *= 0.8
    a += np.linspace(0.06, -0.06, 64)[:, None, None]
    save("steel", a)


def banca():
    a = fill(128, 64, (0.62, 0.62, 0.61), 0.02)
    rect(a, 0, 0, 128, 12, (0.86, 0.86, 0.84))
    covers = [(0.85, 0.82, 0.78), (0.86, 0.66, 0.26), (0.12, 0.12, 0.14), (0.75, 0.15, 0.12), (0.2, 0.35, 0.6)]
    for i, x in enumerate(range(10, 120, 28)):
        c = covers[i % len(covers)]
        rect(a, x, 22, x + 22, 50, (0.15, 0.15, 0.15))
        rect(a, x + 2, 24, x + 20, 48, c)
        rect(a, x + 4, 27, x + 18, 30, (0.95, 0.95, 0.95) if c[0] < 0.5 else (0.7, 0.1, 0.1))
        rect(a, x + 4, 40, x + 14, 41, (0.3, 0.3, 0.3))
    save("banca", a)


def green_wall():
    a = fill(32, 32, (0.25, 0.42, 0.18), 0.09, 0.08, 4)
    save("green_wall", a)


def plane_bark():
    a = fill(32, 64, (0.78, 0.76, 0.66), 0.03)
    for k in range(40):
        x, y = rng.integers(0, 32), rng.integers(0, 64)
        w, h = rng.integers(3, 9), rng.integers(4, 12)
        c = [(0.55, 0.55, 0.42), (0.85, 0.84, 0.76), (0.6, 0.58, 0.5)][k % 3]
        a[y:y + h, x:x + w] = col(c) * rng.uniform(0.9, 1.05)
    save("bark_plane", a)


def leaves(name, base, n, size=128, rad=0.47, seed=3):
    r = np.random.default_rng(seed)
    a = np.zeros((size, size, 4))
    yy, xx = np.mgrid[0:size, 0:size] / size - 0.5
    for k in range(n):
        ang = r.uniform(0, np.pi * 2)
        rr = np.sqrt(r.random()) * rad
        cx, cy = 0.5 + rr * np.cos(ang), 0.5 + rr * np.sin(ang)
        th = r.uniform(0, np.pi)
        L, W = r.uniform(0.03, 0.06), r.uniform(0.015, 0.03)
        dx, dy = xx + 0.5 - cx, yy + 0.5 - cy
        u = dx * np.cos(th) + dy * np.sin(th)
        v = -dx * np.sin(th) + dy * np.cos(th)
        m = (u / L) ** 2 + (v / W) ** 2 < 1
        shade = r.uniform(0.55, 1.2) * (0.75 + 0.5 * (0.5 - cy))
        c = np.array(base) * shade
        a[m, :3] = c
        a[m, 3] = 1
    save(name, a)


def sidewalk():
    a = fill(64, 64, (0.62, 0.60, 0.57), 0.04, 0.05, 8)
    for y in range(0, 64, 32):
        a[y] *= 0.75
    for x in range(0, 64, 32):
        a[:, x] *= 0.75
    for k in range(6):
        x, y = rng.integers(0, 60), rng.integers(0, 60)
        a[y:y + rng.integers(2, 6), x:x + rng.integers(2, 8)] *= 0.85
    save("sidewalk", a * np.array([1.02, 0.98, 0.94]))


def graffiti_wall(name, base, seed):
    r = np.random.default_rng(seed)
    a = fill(128, 64, base, 0.035, 0.06, 8)
    a[40:64] *= np.linspace(1, 0.7, 24)[:, None, None]
    a[0:3] = col(base) * 0.75
    inks = [(0.08, 0.08, 0.08), (0.12, 0.12, 0.14), (0.25, 0.25, 0.3), (0.85, 0.85, 0.85), (0.15, 0.3, 0.6), (0.6, 0.15, 0.15), (0.2, 0.2, 0.2)]
    for k in range(26):
        ink = col(inks[r.integers(0, len(inks))])
        x = r.uniform(0, 120)
        y = r.uniform(14, 50)
        sz = r.uniform(4, 10)
        steps = r.integers(12, 40)
        th = 0.0
        for s in range(steps):
            th += r.uniform(-1.4, 1.4)
            x += np.cos(th) * 1.2 + 0.5
            y += np.sin(th) * 1.2
            if y < 10 or y > 58:
                th += np.pi
            xi, yi = int(x) % 128, int(np.clip(y, 0, 63))
            a[yi, xi] = ink
            if r.random() < 0.5:
                a[min(63, yi + 1), xi] = ink
    save(name, a)


def casarao():
    a = fill(128, 128, (0.80, 0.70, 0.56), 0.03, 0.05, 8)
    a[60:64] = col((0.88, 0.82, 0.70))
    a[0:6] = col((0.9, 0.84, 0.72))
    a[6:8] *= 0.7
    a[120:128] *= 0.75
    for c in range(4):
        x0 = 8 + c * 32
        for (y0, y1) in ((16, 52), (76, 114)):
            rect(a, x0 - 2, y0 - 2, x0 + 18, y1 + 2, (0.92, 0.88, 0.80))
            rect(a, x0, y0, x0 + 16, y1, (0.18, 0.14, 0.12))
            for yy in range(8):
                hw = int(8 * np.sqrt(max(0, 1 - ((7 - yy) / 8) ** 2)))
                a[y0 - 8 + yy, x0 + 8 - hw:x0 + 8 + hw] = col((0.18, 0.14, 0.12))
            a[y0:y1, x0 + 7:x0 + 9] = col((0.55, 0.45, 0.35))
            a[(y0 + y1) // 2, x0:x0 + 16] = col((0.55, 0.45, 0.35))
            rect(a, x0 - 3, y1 + 2, x0 + 19, y1 + 4, (0.9, 0.86, 0.78))
    save("casarao", a)
    e = np.zeros((128, 128, 3))
    save("casarao_e", e)


def roof_tile():
    a = fill(64, 64, (0.55, 0.28, 0.18), 0.04, 0.05, 8)
    for y in range(0, 64, 6):
        a[y:y + 1] *= 0.6
    for y in range(64):
        a[y] *= 1 + 0.12 * np.sin(np.arange(64) * 0.8 + (y // 6) * 1.5)[:, None]
    save("roof_tile", a)


def gate_black():
    a = fill(64, 64, (0.10, 0.10, 0.11), 0.015)
    for x in range(0, 64, 4):
        a[:, x] = col((0.18, 0.18, 0.19))
    a[0:2] = col((0.22, 0.22, 0.22))
    a[62:64] = col((0.05, 0.05, 0.05))
    save("gate_black", a)


def residential(name, wall, glass, rail, seed, cols=4):
    r = np.random.default_rng(seed)
    a = np.ones((128, 128, 3)) * col(wall) + r.normal(0, 0.02, (128, 128, 1))
    e = np.zeros((128, 128, 3))
    for row in range(4):
        y0 = row * 32
        a[y0:y0 + 3] = col(wall) * 0.7
        for c in range(cols):
            cw = 128 // cols
            x0 = c * cw + 3
            x1 = x0 + cw - 6
            a[y0 + 6:y0 + 26, x0:x1] = col(glass) * r.uniform(0.8, 1.15)
            a[y0 + 6:y0 + 26, (x0 + x1) // 2] = col(wall) * 0.9
            if r.random() < 0.3:
                e[y0 + 6:y0 + 26, x0:x1] = np.array([1.0, 0.8, 0.5]) * r.uniform(0.5, 0.9)
            a[y0 + 18:y0 + 26, x0 - 2:x1 + 2] = col(rail) * r.uniform(0.95, 1.05)
            a[y0 + 18, x0 - 2:x1 + 2] = col(rail) * 0.7
            e[y0 + 18:y0 + 26, x0 - 2:x1 + 2] = 0
    save(name, a)
    save(name + "_e", e)


def stone():
    a = fill(32, 32, (0.45, 0.40, 0.33), 0.06, 0.06, 4)
    for y in range(0, 32, 8):
        a[y] *= 0.6
        off = (y // 8) % 2 * 6
        for x in range(off, 32, 12):
            a[y:y + 8, x] *= 0.6
    save("stone", a)


def guarita():
    a = fill(64, 32, (0.86, 0.85, 0.82), 0.02)
    rect(a, 4, 8, 60, 24, (0.20, 0.26, 0.30))
    a[8:24, 32] = col((0.8, 0.8, 0.8))
    save("guarita", a)


def church():
    a = fill(64, 64, (0.86, 0.70, 0.40), 0.03)
    for y in range(0, 64, 8):
        a[y:y + 3] = col((0.62, 0.30, 0.20))
    save("church", a)


def car_tex(name, body):
    a = np.ones((64, 32, 3)) * col(body) + rng.normal(0, 0.015, (64, 32, 1))
    rect(a, 0, 0, 32, 20, (0.10, 0.12, 0.14))
    a[0:20] += np.linspace(0.12, 0, 20)[:, None, None]
    rect(a, 0, 44, 32, 52, (0.08, 0.08, 0.08))
    rect(a, 2, 52, 8, 56, (0.9, 0.2, 0.1))
    rect(a, 24, 52, 30, 56, (0.9, 0.2, 0.1))
    save(name, a)


def tire():
    a = fill(16, 16, (0.07, 0.07, 0.07), 0.02)
    rect(a, 4, 4, 12, 12, (0.55, 0.55, 0.56))
    save("tire", a)


def tent():
    a = fill(32, 32, (0.55, 0.62, 0.72), 0.04)
    for y in range(0, 32, 6):
        a[y:y + 2] = col((0.85, 0.85, 0.88))
    save("tent", a)


def copy(src, name, resize=None, mod=None):
    args = ["magick", src]
    if resize:
        args += ["-resize", resize]
    if mod:
        args += mod
    args += ["-depth", "8", os.path.join(OUT, name + ".png")]
    subprocess.run(args, check=True)


herringbone()
wood_deck()
copper()
granite()
windows("storefront", 128, 64, 8, 2, (0.55, 0.57, 0.58), (0.13, 0.17, 0.20), lit=0.5, mull=1, refl=0.18)
windows("curtain", 128, 128, 8, 16, (0.28, 0.32, 0.36), (0.30, 0.42, 0.52), lit=0.25, mull=1, refl=0.25)
windows("tower_dark", 128, 128, 16, 16, (0.10, 0.11, 0.12), (0.17, 0.20, 0.24), lit=0.2, mull=1, refl=0.15)
panel_dark()
concrete_wall()
fence("fence_bars", 64, 32, 1, 3)
fence("rail", 64, 16, 1, 7, (0.25, 0.25, 0.26), (0, 6))
flat("metal_dark", (0.20, 0.21, 0.23))
flat("metal_grey", (0.42, 0.44, 0.47))
flat("yellow", (0.85, 0.70, 0.12))
flat("white", (0.88, 0.88, 0.86))
flat("paint_white", (0.92, 0.92, 0.9), 0.02)
flat("paint_yellow", (0.88, 0.70, 0.15), 0.02)
flat("curb", (0.66, 0.65, 0.62), 0.03)
flat("soil", (0.30, 0.22, 0.16), 0.06)
flat("planter", (0.62, 0.30, 0.20), 0.05)
flat("lamp", (0.95, 0.9, 0.8), 0.0)
flat("glass_dark", (0.12, 0.15, 0.17), 0.02)
flat("grass", (0.24, 0.36, 0.16), 0.08)
flat("hedge", (0.16, 0.30, 0.12), 0.1)
flat("red_awning", (0.80, 0.12, 0.12), 0.03)
roof_canopy()
food_red()
stainless()
banca()
green_wall()
plane_bark()
leaves("leaves_ficus", (0.20, 0.36, 0.14), 900, seed=3)
leaves("leaves_light", (0.33, 0.50, 0.20), 700, seed=5)
leaves("leaves_dark", (0.14, 0.27, 0.11), 900, seed=9)
sidewalk()
graffiti_wall("wall_graffiti", (0.62, 0.58, 0.50), 11)
graffiti_wall("wall_graffiti2", (0.70, 0.66, 0.58), 12)
casarao()
roof_tile()
gate_black()
residential("res_white", (0.88, 0.87, 0.84), (0.22, 0.27, 0.30), (0.80, 0.82, 0.84), 21)
residential("res_beige", (0.80, 0.70, 0.56), (0.20, 0.22, 0.24), (0.86, 0.80, 0.70), 22, 3)
residential("res_cream", (0.90, 0.85, 0.74), (0.25, 0.28, 0.30), (0.40, 0.42, 0.44), 23)
windows("res_grey", 128, 128, 6, 8, (0.62, 0.60, 0.57), (0.18, 0.2, 0.22), lit=0.3, mull=3, balcony=(0.7, 0.7, 0.68))
stone()
guarita()
church()
car_tex("car_white", (0.86, 0.86, 0.86))
car_tex("car_black", (0.10, 0.10, 0.12))
car_tex("car_silver", (0.60, 0.62, 0.64))
car_tex("car_red", (0.72, 0.08, 0.08))
tire()
tent()
copy(os.path.join(ROOT, "assets/road/b_128.png"), "asphalt")
copy(os.path.join(ROOT, "assets/props/bark.png"), "bark")
if DL:
    copy(os.path.join(DL, "Bark012/Bark012_1K-JPG_Color.jpg"), "bark_ficus", "64x64", ["-modulate", "75,70"])
print("ok", len(os.listdir(OUT)))
