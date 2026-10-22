import json, os, random, subprocess, sys

DL = sys.argv[1]
OUT = sys.argv[2]
os.makedirs(OUT, exist_ok=True)
PK = os.path.join(DL, "panelka/x/Panelka")
random.seed(11)


def run(*a):
    subprocess.run(["magick", *a], check=True)


def mean(p):
    return float(subprocess.run(["magick", p, "-colorspace", "gray", "-format", "%[fx:mean]", "info:"], capture_output=True, text=True).stdout)


def norm(p, target=0.42):
    m = mean(p)
    k = max(0.8, min(1.7, target / max(m, 0.01)))
    run(p, "-evaluate", "multiply", str(k), "-posterize", "28", "-strip", "PNG24:" + p)


def lit(src, out, frac=78, color="#ffd49a"):
    run("(", src, "-colorspace", "gray", "-negate", "-threshold", "52%", ")",
        "(", "-size", "16x16", "xc:", "+noise", "Random", "-colorspace", "gray", "-threshold", f"{frac}%", "-filter", "point", "-resize", "128x128!", ")",
        "-compose", "multiply", "-composite", "-colorspace", "sRGB",
        "(", "-size", "128x128", f"xc:{color}", ")", "-compose", "multiply", "-composite", "-strip", "PNG24:" + out)


styles = {}


def acg(name, src, floors, kind, emis=None):
    c = os.path.join(OUT, name + "_c.png")
    e = os.path.join(OUT, name + "_e.png")
    run(os.path.join(DL, src, src + "_1K-JPG_Color.jpg"), "-filter", "Box", "-resize", "128x128!", "PNG24:" + c)
    norm(c)
    ep = os.path.join(DL, src, src + "_1K-JPG_Emission.jpg")
    if emis:
        ep = os.path.join(DL, emis, emis + "_1K-JPG_Emission.jpg")
    if os.path.exists(ep):
        run(ep, "-filter", "Box", "-resize", "128x128!", "-posterize", "28", "-strip", "PNG24:" + e)
    else:
        lit(c, e)
    styles[name] = {"floors": floors, "aspect": 1.0, "kind": kind}


acg("a001", "Facade001", 8, "tower")
acg("a002", "Facade002", 8, "tower")
acg("a003", "Facade003", 8, "tower")
acg("a004", "Facade004", 8, "tower")
acg("a005", "Facade005", 12, "tower")
acg("a006", "Facade006", 8, "mid")
acg("a012", "Facade012", 26, "tower")
acg("a013", "Facade013", 26, "mid")
acg("a014", "Facade014", 30, "tower")
acg("a015", "Facade015", 26, "tower")
acg("a017", "Facade017", 10, "mid")
acg("a018", "Facade018A", 6, "mid")
acg("a018b", "Facade018B", 6, "low")
acg("a019", "Facade019A", 5, "mid")
acg("a019b", "Facade019B", 5, "mid")
acg("a020", "Facade020A", 6, "mid")
acg("a020b", "Facade020B", 6, "tower")

c = os.path.join(OUT, "p_ii68_c.png")
run(os.path.join(PK, "Panels/II-68.png"), "-filter", "Box", "-resize", "128x140!", "PNG24:" + c)
norm(c)
lit(c, os.path.join(OUT, "p_ii68_e.png"), 80)
styles["p_ii68"] = {"floors": 15, "aspect": 968 / 1063, "kind": "mid"}

panels = ["Panel1", "Panel2", "Panel4", "Panel5", "Panel6"]
win = os.path.join(OUT, "_win.png")
run(os.path.join(PK, "Panels/Panel6.png"), "-gravity", "center", "-crop", "50%x50%+0-20", "+repage", "PNG24:" + win)
for i, tint in enumerate(["100,100,100", "95,80,100", "105,60,100"]):
    name = f"p_panel{i + 1}"
    cells = [os.path.join(PK, "Panels", random.choice(panels) + ".png") for _ in range(16)]
    c = os.path.join(OUT, name + "_c.png")
    subprocess.run(["magick", "montage", *cells, "-tile", "4x4", "-geometry", "32x32+0+0", "PNG24:" + c], check=True)
    run(c, "-modulate", tint, "PNG24:" + c)
    norm(c)
    lit(c, os.path.join(OUT, name + "_e.png"), 75)
    styles[name] = {"floors": 4, "aspect": 1.0, "kind": "mid" if i < 2 else "low"}


def wall_windows(name, base, floors, kind, cols=4, wsize=(16, 20), modulate="100,100,100"):
    c = os.path.join(OUT, name + "_c.png")
    run(base, "-filter", "Box", "-resize", "64x64!", "-write", "mpr:t", "+delete", "-size", "128x128", "tile:mpr:t", "-modulate", modulate, "PNG24:" + c)
    cw = 128 // cols
    ch = 128 // floors
    args = [c]
    for fy in range(floors):
        for cx in range(cols):
            x = cx * cw + (cw - wsize[0]) // 2
            y = fy * ch + (ch - wsize[1]) // 2
            args += ["(", win, "-resize", f"{wsize[0]}x{wsize[1]}!", ")", "-geometry", f"+{x}+{y}", "-composite"]
    run(*args, "PNG24:" + c)
    norm(c)
    lit(c, os.path.join(OUT, name + "_e.png"), 72)
    styles[name] = {"floors": floors, "aspect": 1.0, "kind": kind}


wall_windows("p_brick", os.path.join(PK, "Walls/Bricks/Bricks1diffuse.png"), 4, "low")
wall_windows("p_brickred", os.path.join(PK, "Walls/Bricks/BrickWall1diffuse.png"), 4, "low")
wall_windows("p_pastilha", os.path.join(PK, "WallTilesDiffuse.png"), 5, "mid", 5, (14, 16), "110,70,100")
wall_windows("p_pastilha2", os.path.join(PK, "WallTilesDiffuse.png"), 5, "mid", 4, (20, 14), "120,40,160")
wall_windows("p_white", os.path.join(PK, "WhiteBricks.png"), 4, "low", 3, (22, 20))

for name, src in [("e_concrete", os.path.join(PK, "Concrete1diffuse.png")), ("e_panel", os.path.join(PK, "Panels/Panel1Edge.png")), ("e_bricks", os.path.join(PK, "WhiteBricks.png"))]:
    c = os.path.join(OUT, name + "_c.png")
    run(src, "-filter", "Box", "-resize", "64x64!", "PNG24:" + c)
    norm(c, 0.45)
    run("-size", "64x64", "xc:black", "PNG24:" + os.path.join(OUT, name + "_e.png"))

props = os.path.join(os.path.dirname(OUT), "props")


def terreo(name, kind):
    c = os.path.join(OUT, name + "_c.png")
    e = os.path.join(OUT, name + "_e.png")
    run(os.path.join(props, "concrete.png"), "-resize", "64x32!", "-write", "mpr:t", "+delete", "-size", "256x64", "tile:mpr:t", "PNG24:" + c)
    run("-size", "256x64", "xc:black", "PNG24:" + e)
    for b in range(4):
        x = b * 64 + 6
        if kind == "shops":
            fill = os.path.join(props, "window.png") if b % 2 == 0 else os.path.join(props, "shutter.png")
            run(c, "(", fill, "-resize", "52x38!", ")", "-geometry", f"+{x}+24", "-composite",
                "(", os.path.join(props, f"sign{(b + random.randint(0, 3)) % 4}.png"), "-resize", "52x12!", ")", "-geometry", f"+{x}+6", "-composite", "PNG24:" + c)
            if b % 2 == 0:
                run(e, "(", os.path.join(props, "window.png"), "-resize", "52x38!", ")", "-geometry", f"+{x}+24", "-composite",
                    "(", os.path.join(props, f"sign{b % 4}.png"), "-resize", "52x12!", ")", "-geometry", f"+{x}+6", "-composite", "PNG24:" + e)
        elif kind == "lobby":
            run(c, "(", os.path.join(DL, "Facade006/Facade006_1K-JPG_Color.jpg"), "-resize", "52x50!", "-modulate", "70", ")", "-geometry", f"+{x}+12", "-composite", "PNG24:" + c)
            run(e, "(", "-size", "52x50", "xc:#4a3a22", ")", "-geometry", f"+{x}+12", "-composite", "PNG24:" + e)
        else:
            run(c, "(", "-size", "52x60", "xc:#141414", ")", "-geometry", f"+{x}+4", "-composite", "PNG24:" + c)
    norm(c, 0.38)
    styles[name] = {"floors": 1, "aspect": 4.0, "kind": "terreo"}


terreo("t_shops", "shops")
terreo("t_lobby", "lobby")
terreo("t_pilotis", "pilotis")
os.remove(win)
json.dump(styles, open(os.path.join(OUT, "styles.json"), "w"), indent=1)
print(len([k for k, v in styles.items() if v["kind"] in ("tower", "mid", "low")]), "facade styles")
