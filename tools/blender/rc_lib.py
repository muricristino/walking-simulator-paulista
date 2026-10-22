import json, math, os, random

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TEX = os.path.join(ROOT, "assets/rioclaro/tex")
OUTDIR = os.path.join(ROOT, "assets/rioclaro")
DATA = json.load(open(os.path.join(ROOT, "assets/osm/rioclaro.json")))
GRID = DATA["grid"]
ST = DATA["street"]


def height(x, z):
    fx = (x - GRID["x0"]) / GRID["step"]
    fz = (z - GRID["z0"]) / GRID["step"]
    nx, nz = GRID["nx"], GRID["nz"]
    fx = min(max(fx, 0.0), nx - 1.001)
    fz = min(max(fz, 0.0), nz - 1.001)
    i, j = int(fx), int(fz)
    tx, tz = fx - i, fz - j
    h = GRID["h"]
    a = h[j * nx + i] * (1 - tx) + h[j * nx + i + 1] * tx
    b = h[(j + 1) * nx + i] * (1 - tx) + h[(j + 1) * nx + i + 1] * tx
    return a * (1 - tz) + b * tz


def street_y(x, z):
    best, y = 1e18, 0.0
    for a, b in zip(ST, ST[1:]):
        ax, az = a["p"]
        bx, bz = b["p"]
        abx, abz = bx - ax, bz - az
        t = min(max(((x - ax) * abx + (z - az) * abz) / max(abx * abx + abz * abz, 0.001), 0.0), 1.0)
        d = math.hypot(x - (ax + abx * t), z - (az + abz * t))
        if d < best:
            best = d
            y = a["y"] + (b["y"] - a["y"]) * t
    w = min(max((best - 8.0) / 25.0, 0.0), 1.0)
    return y + (height(x, z) - y) * w


CUM = [0.0]
for a, b in zip(ST, ST[1:]):
    CUM.append(CUM[-1] + math.dist(a["p"], b["p"]))


def frame(s, t=0.0):
    k = 0
    while k < len(ST) - 2 and CUM[k + 1] < s:
        k += 1
    a, b = ST[k]["p"], ST[k + 1]["p"]
    L = CUM[k + 1] - CUM[k]
    u = (s - CUM[k]) / L
    dx, dz = (b[0] - a[0]) / L, (b[1] - a[1]) / L
    lx, lz = -dz, dx
    if lz < 0:
        lx, lz = -lx, -lz
    return (a[0] + (b[0] - a[0]) * u + lx * t, a[1] + (b[1] - a[1]) * u + lz * t)


def fdir(s):
    x0, z0 = frame(s - 0.5)
    x1, z1 = frame(s + 0.5)
    L = math.hypot(x1 - x0, z1 - z0)
    return ((x1 - x0) / L, (z1 - z0) / L)


def yaw_of(s):
    d = fdir(s)
    return math.atan2(d[0], d[1])


def gy(s, t):
    x, z = frame(s, t)
    return street_y(x, z)


def P(s, t, h=0.0, base=None):
    x, z = frame(s, t)
    y = (street_y(x, z) if base is None else base) + h
    return (x, y, z)


class Kit:
    def __init__(self):
        self.parts = {}
        self.col = {"floor": [], "wall": []}
        self.rng = random.Random(1)

    def _m(self, mat):
        return self.parts.setdefault(mat, ([], [], []))

    def poly(self, mat, pts, uvs, col=None):
        v, f, uv = self._m(mat)
        i0 = len(v)
        v.extend(pts)
        uv.extend(uvs)
        f.append(list(range(i0, i0 + len(pts))))
        if col:
            self.col[col].append(list(pts))

    def quad(self, mat, a, b, c, d, u0=0.0, v0=0.0, u1=1.0, v1=1.0, col=None):
        self.poly(mat, [a, b, c, d], [(u0, v0), (u1, v0), (u1, v1), (u0, v1)], col)

    def colq(self, kind, pts):
        self.col[kind].append(list(pts))

    def wall(self, mat, a, b, y0a, y1a, y0b=None, y1b=None, tile=(2.0, 2.0), u_off=0.0, col="wall", vfix=None):
        y0b = y0a if y0b is None else y0b
        y1b = y1a if y1b is None else y1b
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        if vfix:
            va0, va1, vb0, vb1 = vfix[0], vfix[1], vfix[0], vfix[1]
        else:
            va0, va1, vb0, vb1 = y0a / tile[1], y1a / tile[1], y0b / tile[1], y1b / tile[1]
        self.poly(mat, [(a[0], y0a, a[1]), (b[0], y0b, b[1]), (b[0], y1b, b[1]), (a[0], y1a, a[1])],
                  [(u_off / tile[0], va0), ((u_off + L) / tile[0], vb0), ((u_off + L) / tile[0], vb1), (u_off / tile[0], va1)], col)
        return L

    def prism(self, mat, pts, y0, y1, top=None, tile=(3.0, 3.0), col="wall", vfix=None, top_tile=4.0, bottom=False):
        u = 0.0
        n = len(pts)
        for i in range(n):
            a, b = pts[i], pts[(i + 1) % n]
            u += self.wall(mat, a, b, y0, y1, tile=tile, u_off=u, col=col, vfix=vfix)
        if top:
            self.poly(top, [(p[0], y1, p[1]) for p in pts], [(p[0] / top_tile, p[1] / top_tile) for p in pts])
        if bottom:
            self.poly(top or mat, [(p[0], y0, p[1]) for p in reversed(pts)], [(p[0] / top_tile, p[1] / top_tile) for p in reversed(pts)])

    def box(self, mat, c, size, yaw=0.0, tile=None, top=None, col="wall", uvfit=False):
        sx, sy, sz = size[0] / 2, size[1], size[2] / 2
        cy, sy_ = math.cos(yaw), math.sin(yaw)

        def r(px, pz):
            return (c[0] + px * cy + pz * sy_, c[2] - px * sy_ + pz * cy)

        pts = [r(-sx, -sz), r(sx, -sz), r(sx, sz), r(-sx, sz)]
        y0, y1 = c[1], c[1] + sy
        if uvfit:
            u = 0.0
            for i in range(4):
                a, b = pts[i], pts[(i + 1) % 4]
                L = math.hypot(b[0] - a[0], b[1] - a[1])
                self.poly(mat, [(a[0], y0, a[1]), (b[0], y0, b[1]), (b[0], y1, b[1]), (a[0], y1, a[1])], [(0, 0), (1, 0), (1, 1), (0, 1)], col)
        else:
            t = tile or (max(size[0], size[2]), size[1])
            self.prism(mat, pts, y0, y1, None, tile=t, col=col)
        tm = top or mat
        self.poly(tm, [(p[0], y1, p[1]) for p in pts], [(0, 0), (1, 0), (1, 1), (0, 1)])
        self.poly(tm, [(p[0], y0, p[1]) for p in reversed(pts)], [(0, 0), (1, 0), (1, 1), (0, 1)])

    def beam(self, mat, a, b, w, sides=4, col=None):
        ax, ay, az = a
        bx, by, bz = b
        d = (bx - ax, by - ay, bz - az)
        L = math.sqrt(sum(k * k for k in d))
        d = tuple(k / L for k in d)
        up = (0, 1, 0) if abs(d[1]) < 0.9 else (1, 0, 0)
        s1 = (d[1] * up[2] - d[2] * up[1], d[2] * up[0] - d[0] * up[2], d[0] * up[1] - d[1] * up[0])
        n1 = math.sqrt(sum(k * k for k in s1))
        s1 = tuple(k / n1 for k in s1)
        s2 = (d[1] * s1[2] - d[2] * s1[1], d[2] * s1[0] - d[0] * s1[2], d[0] * s1[1] - d[1] * s1[0])
        ring = []
        for i in range(sides):
            ang = 2 * math.pi * i / sides + math.pi / sides
            ring.append((s1[0] * math.cos(ang) * w + s2[0] * math.sin(ang) * w, s1[1] * math.cos(ang) * w + s2[1] * math.sin(ang) * w, s1[2] * math.cos(ang) * w + s2[2] * math.sin(ang) * w))
        for i in range(sides):
            r0, r1 = ring[i], ring[(i + 1) % sides]
            self.quad(mat, (ax + r0[0], ay + r0[1], az + r0[2]), (ax + r1[0], ay + r1[1], az + r1[2]), (bx + r1[0], by + r1[1], bz + r1[2]), (bx + r0[0], by + r0[1], bz + r0[2]), i / sides, 0, (i + 1) / sides, L / 2.0, col)

    def tube(self, mat, a, b, r0, r1, sides=6, vrep=1.0):
        ax, ay, az = a
        bx, by, bz = b
        d = (bx - ax, by - ay, bz - az)
        L = math.sqrt(sum(k * k for k in d))
        d = tuple(k / L for k in d)
        up = (0, 0, 1) if abs(d[2]) < 0.9 else (1, 0, 0)
        s1 = (d[1] * up[2] - d[2] * up[1], d[2] * up[0] - d[0] * up[2], d[0] * up[1] - d[1] * up[0])
        n1 = math.sqrt(sum(k * k for k in s1))
        s1 = tuple(k / n1 for k in s1)
        s2 = (d[1] * s1[2] - d[2] * s1[1], d[2] * s1[0] - d[0] * s1[2], d[0] * s1[1] - d[1] * s1[0])
        for i in range(sides):
            a0 = 2 * math.pi * i / sides
            a1 = 2 * math.pi * (i + 1) / sides
            o0 = tuple(s1[k] * math.cos(a0) + s2[k] * math.sin(a0) for k in range(3))
            o1 = tuple(s1[k] * math.cos(a1) + s2[k] * math.sin(a1) for k in range(3))
            self.quad(mat, tuple(a[k] + o0[k] * r0 for k in range(3)), tuple(a[k] + o1[k] * r0 for k in range(3)), tuple(b[k] + o1[k] * r1 for k in range(3)), tuple(b[k] + o0[k] * r1 for k in range(3)), i / sides, 0, (i + 1) / sides, vrep)

    def card(self, mat, c, w, h, yaw):
        dx, dz = math.sin(yaw) * w / 2, math.cos(yaw) * w / 2
        self.quad(mat, (c[0] - dx, c[1] - h / 2, c[2] - dz), (c[0] + dx, c[1] - h / 2, c[2] + dz), (c[0] + dx, c[1] + h / 2, c[2] + dz), (c[0] - dx, c[1] + h / 2, c[2] - dz))

    def hcard(self, mat, c, r, rot=0.0, tilt=0.0):
        pts = []
        for k in range(4):
            a = rot + k * math.pi / 2 + math.pi / 4
            pts.append((c[0] + math.cos(a) * r, c[1] + (tilt if k < 2 else -tilt), c[2] + math.sin(a) * r))
        self.poly(mat, pts, [(0, 0), (1, 0), (1, 1), (0, 1)])

    def tree(self, base, size=1.0, kind="ficus", seed=0, crown=None):
        r = random.Random(seed)
        x, y, z = base
        bark = {"ficus": "bark_ficus", "plane": "bark_plane", "sibi": "bark"}[kind]
        leaf = {"ficus": "cut__leaves_ficus", "plane": "cut__leaves_light", "sibi": "cut__leaves_dark"}[kind]
        th = {"ficus": 3.0, "plane": 5.0, "sibi": 4.2}[kind] * size
        tr = 0.2 * size if kind != "ficus" else 0.45 * size
        top = (x + r.uniform(-0.3, 0.3) * size, y + th, z + r.uniform(-0.3, 0.3) * size)
        self.tube(bark, (x, y - 0.1, z), top, tr, tr * 0.8, 6, 3.0)
        self.colq("wall", [(x - tr, y, z - tr), (x + tr, y, z - tr), (x + tr, y + 2, z - tr), (x - tr, y + 2, z - tr)])
        self.colq("wall", [(x - tr, y, z + tr), (x + tr, y, z + tr), (x + tr, y + 2, z + tr), (x - tr, y + 2, z + tr)])
        self.colq("wall", [(x - tr, y, z - tr), (x - tr, y, z + tr), (x - tr, y + 2, z + tr), (x - tr, y + 2, z - tr)])
        self.colq("wall", [(x + tr, y, z - tr), (x + tr, y, z + tr), (x + tr, y + 2, z + tr), (x + tr, y + 2, z - tr)])
        cr = crown or (4.0 * size)
        ch = top[1] + cr * (0.45 if kind == "plane" else 0.35)
        tips = []
        nb = 4 if kind != "plane" else 3
        for k in range(nb):
            a = 2 * math.pi * k / nb + r.uniform(-0.5, 0.5)
            spread = 0.35 if kind == "plane" else 0.6
            tip = (top[0] + math.cos(a) * cr * spread, ch + r.uniform(-0.2, 0.6) * size, top[2] + math.sin(a) * cr * spread)
            self.tube(bark, top, tip, tr * 0.55, tr * 0.2, 4, 2.0)
            tips.append(tip)
        n = int(10 + cr * 2.5)
        for k in range(n):
            a = r.uniform(0, 2 * math.pi)
            rr = math.sqrt(r.random()) * cr * 0.85
            c = (top[0] + math.cos(a) * rr, ch + r.uniform(-0.35, 0.5) * cr * 0.6, top[2] + math.sin(a) * rr)
            s = r.uniform(1.6, 2.6) * size
            self.hcard(leaf, c, s, r.uniform(0, 3.14), r.uniform(-0.4, 0.4))
            if k % 2 == 0:
                self.card(leaf, c, s * 1.5, s * 1.2, r.uniform(0, 3.14))

    def export(self, name, extra_meta=None):
        import bpy
        for o in list(bpy.data.objects):
            bpy.data.objects.remove(o, do_unlink=True)
        for m in list(bpy.data.meshes):
            bpy.data.meshes.remove(m)
        for m in list(bpy.data.materials):
            bpy.data.materials.remove(m)
        tris = 0

        def mk(oname, mat, verts, faces, uvs):
            me = bpy.data.meshes.new(oname)
            me.from_pydata([(v[0], -v[2], v[1]) for v in verts], [], faces)
            if uvs is not None:
                layer = me.uv_layers.new(name="UVMap")
                k = 0
                for poly in me.polygons:
                    for li in poly.loop_indices:
                        vi = me.loops[li].vertex_index
                        layer.data[li].uv = uvs[vi]
            me.validate()
            me.update()
            ob = bpy.data.objects.new(oname, me)
            bpy.context.scene.collection.objects.link(ob)
            if mat:
                m = bpy.data.materials.get(mat) or bpy.data.materials.new(mat)
                me.materials.append(m)
            return ob

        for mat, (v, f, uv) in self.parts.items():
            mk(name + "__" + mat, mat, v, f, uv)
            tris += sum(len(p) - 2 for p in f)
        for kind, polys in self.col.items():
            if not polys:
                continue
            verts, faces = [], []
            for p in polys:
                i0 = len(verts)
                verts.extend(p)
                faces.append(list(range(i0, i0 + len(p))))
            mk("COL_" + kind + "_" + name, None, verts, faces, None)
        path = os.path.join(OUTDIR, name + ".glb")
        bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_image_format="NONE", export_materials="EXPORT", export_yup=True, export_apply=False, export_normals=True, export_texcoords=True)
        print("exported", path, "tris", tris, "mats", len(self.parts))
        return tris


def strip(kit, mat, s0, s1, t0, t1, yf, step=4.0, tile=(2.0, 2.0), col="floor", tstep=None):
    n = max(1, int(math.ceil((s1 - s0) / step)))
    tn = 1 if tstep is None else max(1, int(math.ceil(abs(t1 - t0) / tstep)))
    for i in range(n):
        sa, sb = s0 + (s1 - s0) * i / n, s0 + (s1 - s0) * (i + 1) / n
        for j in range(tn):
            ta, tb = t0 + (t1 - t0) * j / tn, t0 + (t1 - t0) * (j + 1) / tn
            pts = []
            uvs = []
            for (s, t) in ((sa, ta), (sb, ta), (sb, tb), (sa, tb)):
                x, z = frame(s, t)
                pts.append((x, yf(s, t), z))
                uvs.append((s / tile[0], t / tile[1]))
            kit.poly(mat, pts, uvs, col)


def vwall(kit, mat, s0, s1, t, ybot, ytop, step=4.0, tile=(2.0, 2.0), col="wall", vfix=None):
    n = max(1, int(math.ceil((s1 - s0) / step)))
    for i in range(n):
        sa, sb = s0 + (s1 - s0) * i / n, s0 + (s1 - s0) * (i + 1) / n
        a, b = frame(sa, t), frame(sb, t)
        ya0, ya1, yb0, yb1 = ybot(sa), ytop(sa), ybot(sb), ytop(sb)
        if vfix:
            uv = [(sa / tile[0], vfix[0]), (sb / tile[0], vfix[0]), (sb / tile[0], vfix[1]), (sa / tile[0], vfix[1])]
        else:
            uv = [(sa / tile[0], ya0 / tile[1]), (sb / tile[0], yb0 / tile[1]), (sb / tile[0], yb1 / tile[1]), (sa / tile[0], ya1 / tile[1])]
        kit.poly(mat, [(a[0], ya0, a[1]), (b[0], yb0, b[1]), (b[0], yb1, b[1]), (a[0], ya1, a[1])], uv, col)


def twall(kit, mat, s, t0, t1, y0, y1, tile=(2.0, 2.0), col="wall", vfix=None):
    a, b = frame(s, t0), frame(s, t1)
    kit.wall(mat, a, b, y0, y1, tile=tile, col=col, vfix=vfix)


def sbox(kit, mat, s, t, y, size, top=None, col="wall", uvfit=False, tile=None, yaw_add=0.0):
    x, z = frame(s, t)
    kit.box(mat, (x, y, z), size, yaw_of(s) + yaw_add, top=top, col=col, uvfit=uvfit, tile=tile)


def car(kit, s, t, color="car_white", seed=0, flip=False):
    r = random.Random(seed)
    L, W = r.uniform(4.0, 4.6), 1.75
    x, z = frame(s, t)
    y = street_y(x, z) + 0.02
    yaw = yaw_of(s) + (math.pi if flip else 0.0)
    kit.box(color, (x, y + 0.3, z), (W, 0.75, L), yaw, top=color, col="wall", uvfit=True)
    c, sn = math.cos(yaw), math.sin(yaw)
    off = r.uniform(-0.3, 0.1)
    kit.box("glass_dark", (x + sn * off, y + 1.05, z + c * off), (W * 0.86, 0.5, L * 0.5), yaw, top=color, col=None, uvfit=True)
    for dl in (-L * 0.32, L * 0.32):
        for dw in (-W * 0.5, W * 0.5):
            px = x + sn * dl + c * dw
            pz = z + c * dl - sn * dw
            kit.tube("tire", (px - c * 0.12, y + 0.32, pz + sn * 0.12), (px + c * 0.12, y + 0.32, pz - sn * 0.12), 0.32, 0.32, 6)


def tower(kit, pts, y0, h, tex, tile=(8.0, 12.0), lobby="glass_dark", lobby_h=4.0):
    kit.prism(lobby, pts, y0, y0 + lobby_h, tile=(4.0, lobby_h))
    kit.prism(tex, pts, y0 + lobby_h, y0 + h, top="panel_dark", tile=tile, col=None)
    cx = sum(p[0] for p in pts) / len(pts)
    cz = sum(p[1] for p in pts) / len(pts)
    kit.box("concrete_wall", (cx, y0 + h, cz), (4.0, 3.0, 5.0), 0.0, col=None)
