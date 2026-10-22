import json
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

SR = 22050


def decode(path, mono=True, sr=SR, start=None, dur=None):
    cmd = ["ffmpeg", "-nostdin", "-v", "error"]
    if start is not None:
        cmd += ["-ss", str(start)]
    if dur is not None:
        cmd += ["-t", str(dur)]
    cmd += ["-i", path, "-f", "f32le", "-ac", "1" if mono else "2", "-ar", str(sr), "-"]
    raw = subprocess.run(cmd, check=True, capture_output=True).stdout
    x = np.frombuffer(raw, dtype=np.float32).astype(np.float64)
    return x if mono else x.reshape(-1, 2)


def write_wav(path, x, sr=SR):
    x = np.clip(x, -1.0, 1.0)
    pcm = (x * 32767.0).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1 if x.ndim == 1 else 2)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(pcm.tobytes())


def write_ogg(path, x, sr=SR, q=3):
    if x.ndim == 1:
        x = np.stack([x, x], axis=1)
    with tempfile.TemporaryDirectory() as d:
        tmp = os.path.join(d, "t.wav")
        write_wav(tmp, x, sr)
        subprocess.run(["ffmpeg", "-nostdin", "-v", "error", "-y", "-i", tmp, "-c:a", "vorbis", "-strict", "-2", "-q:a", str(q), path], check=True)


def db(v):
    return 20.0 * np.log10(max(v, 1e-12))


def rms(x):
    return float(np.sqrt(np.mean(np.square(x))))


def peak(x):
    return float(np.max(np.abs(x)))


def norm_rms(x, target_db, ceiling_db=-1.0):
    g = 10 ** (target_db / 20.0) / max(rms(x), 1e-9)
    y = x * g
    p = peak(y)
    c = 10 ** (ceiling_db / 20.0)
    if p > c:
        y = soft_limit(y, c)
    return y


def norm_peak(x, target_db=-1.0):
    return x * (10 ** (target_db / 20.0) / max(peak(x), 1e-9))


def soft_limit(x, c):
    return c * np.tanh(x / c)


def fft_filter(x, lp=None, hp=None, order=2, circular=False, sr=SR):
    pad = 0 if circular else int(0.4 * sr)
    if pad:
        shape = (pad,) + x.shape[1:]
        x = np.concatenate([x, np.zeros(shape)])
    n = x.shape[0]
    f = np.fft.rfftfreq(n, 1.0 / sr)
    h = np.ones_like(f)
    if lp:
        h *= 1.0 / np.sqrt(1.0 + (f / lp) ** (2 * order))
    if hp:
        with np.errstate(divide="ignore"):
            h *= 1.0 / np.sqrt(1.0 + (hp / np.maximum(f, 1e-6)) ** (2 * order))
    if x.ndim == 2:
        h = h[:, None]
    y = np.fft.irfft(np.fft.rfft(x, axis=0) * h, n=n, axis=0)
    return y if circular else y[: n - pad]


def circ_convolve(x, ir):
    n = x.shape[0]
    irp = np.zeros(n)
    irp[: min(len(ir), n)] = ir[:n]
    H = np.fft.rfft(irp)
    if x.ndim == 2:
        H = H[:, None]
    return np.fft.irfft(np.fft.rfft(x, axis=0) * H, n=n, axis=0)


def lin_convolve(x, ir):
    n = len(x) + len(ir)
    return np.fft.irfft(np.fft.rfft(x, n) * np.fft.rfft(ir, n), n)


def loopify(x, fade):
    n = x.shape[0]
    t = np.linspace(0.0, 1.0, fade)
    fi = np.sin(t * np.pi / 2)
    fo = np.cos(t * np.pi / 2)
    if x.ndim == 2:
        fi = fi[:, None]
        fo = fo[:, None]
    body = x[: n - fade].copy()
    body[:fade] = x[:fade] * fi + x[n - fade :] * fo
    return body


def best_loop(x, search, win):
    n = len(x)
    head = x[:win]
    best = n
    score = -np.inf
    for e in range(n - search, n - win):
        seg = x[e : e + win]
        c = float(np.dot(seg, head)) / (np.linalg.norm(seg) * np.linalg.norm(head) + 1e-9)
        if c > score:
            score = c
            best = e
    y = x[: best + win].copy()
    return loopify(y, win), score


def resample(x, ratio, periodic=False):
    n = x.shape[0]
    m = int(round(n / ratio))
    pos = np.arange(m) * ratio
    if periodic:
        idx = np.arange(n + 1)
        xx = np.concatenate([x, x[:1]])
        return np.interp(pos % n, idx, xx)
    return np.interp(pos, np.arange(n), x, right=0.0)


def periodic_noise(n, amp_fn, rng):
    f = np.fft.rfftfreq(n, 1.0 / SR)
    a = amp_fn(np.maximum(f, 1.0))
    a[0] = 0.0
    ph = rng.uniform(0, 2 * np.pi, len(f))
    y = np.fft.irfft(a * np.exp(1j * ph), n=n)
    return y / max(rms(y), 1e-9)


def trim(x, thr_db=-42.0, pre=0.004):
    thr = 10 ** (thr_db / 20.0) * peak(x)
    idx = np.where(np.abs(x) > thr)[0]
    if len(idx) == 0:
        return x
    s = max(0, idx[0] - int(pre * SR))
    e = min(len(x), idx[-1] + int(0.03 * SR))
    y = x[s:e].copy()
    k = min(len(y), int(0.02 * SR))
    y[-k:] *= np.linspace(1.0, 0.0, k)
    return y


def env_adsr(n, a, r):
    e = np.ones(n)
    na = max(1, int(a * SR))
    nr = max(1, int(r * SR))
    e[:na] = np.linspace(0, 1, na)
    e[n - nr :] *= np.linspace(1, 0, nr)
    return e


def tone(freq, n, harm, phase0=0.0):
    ph = phase0 + np.cumsum(2 * np.pi * freq / SR)
    y = np.zeros(n)
    for k, a in enumerate(harm, start=1):
        y += a * np.sin(k * ph)
    return y


def outdoor_ir(length, decay, rng, early=0.0):
    n = int(length * SR)
    t = np.arange(n) / SR
    ir = rng.normal(0, 1, n) * np.exp(-t / decay)
    ir = fft_filter(ir, lp=4000)
    ir /= np.sqrt(np.sum(ir ** 2))
    ir *= early
    ir[0] += 1.0
    return ir


def best_segment(x, dur, band=None, prefer="max"):
    w = int(dur * SR)
    y = fft_filter(x, hp=band) if band else x
    hop = SR
    best = 0
    bv = None
    vals = []
    for s in range(0, len(y) - w, hop):
        vals.append((rms(y[s : s + w]), s))
    vals.sort()
    if prefer == "max":
        bv = vals[-1]
    else:
        bv = vals[len(vals) // 2]
    best = bv[1]
    return best


def analyze(path, x, loop):
    mono = x if x.ndim == 1 else x.mean(axis=1)
    d = np.abs(np.diff(mono))
    seam = abs(mono[-1] - mono[0]) / (np.median(d) + 1e-9) if loop else None
    return {
        "file": path,
        "seconds": round(len(mono) / SR, 3),
        "channels": 1 if x.ndim == 1 else 2,
        "peak_db": round(db(peak(x)), 2),
        "rms_db": round(db(rms(x)), 2),
        "loop": loop,
        "seam_jump_vs_median_step": None if seam is None else round(float(seam), 2),
    }


class Builder:
    def __init__(self, src, out, report):
        self.src = src
        self.out = out
        self.report = report
        self.items = []
        os.makedirs(out, exist_ok=True)

    def p(self, rel):
        return os.path.join(self.src, rel)

    def save(self, name, x, loop=False, ogg=False):
        path = os.path.join(self.out, name)
        if ogg:
            write_ogg(path, x)
        else:
            write_wav(path, x)
        self.items.append(analyze(name, x, loop))

    def build(self):
        rng = np.random.default_rng(20261022)
        self.ambience(rng)
        self.birds(rng)
        self.vehicles(rng)
        self.steps(rng)
        self.misc(rng)
        with open(os.path.join(self.report, "assets.json"), "w") as f:
            json.dump(self.items, f, indent=1)

    def ambience(self, rng):
        traffic = decode(self.p("oga_traffic/traffic.ogg"))
        traffic = fft_filter(traffic, hp=40)
        av = loopify(traffic, int(3.0 * SR))
        av = fft_filter(av, hp=45, circular=True)
        shift = int(23.0 * SR)
        st = np.stack([av, np.roll(av, shift)], axis=1)
        self.save("amb_avenue.ogg", norm_rms(st, -18.0), loop=True, ogg=True)
        n = int(24.0 * SR)

        def shape(f):
            return f ** -0.85 / np.sqrt(1 + (f / 900.0) ** 4) / np.sqrt(1 + (28.0 / f) ** 6)

        a = periodic_noise(n, shape, rng)
        b = periodic_noise(n, shape, rng)
        c = periodic_noise(n, shape, rng)
        t = np.arange(n) / n
        mod = 1.0 + 0.18 * np.sin(2 * np.pi * 1 * t + 0.4) + 0.1 * np.sin(2 * np.pi * 3 * t + 1.3) + 0.06 * np.sin(2 * np.pi * 7 * t)
        dist = loopify(traffic[: n + int(2.0 * SR)], int(2.0 * SR))
        dist = fft_filter(dist, lp=420, order=3, circular=True)
        dist = dist / rms(dist)
        l = (a + 0.55 * b) * mod + 0.6 * dist
        r = (a + 0.55 * c) * mod + 0.6 * np.roll(dist, n // 2)
        rum = np.stack([l, r], axis=1)
        self.save("amb_city.ogg", norm_rms(rum, -18.0), loop=True, ogg=True)
        wind = decode(self.p("oga_park/wind.wav"), mono=False)
        s = best_segment(wind.mean(axis=1), 33.0, prefer="median")
        w = wind[s : s + int(33.0 * SR)]
        w = loopify(w, int(3.0 * SR))
        w = fft_filter(w, hp=70, lp=6000, circular=True)
        self.save("amb_wind.ogg", norm_rms(w, -20.0), loop=True, ogg=True)
        crowd = decode(self.p("oga_crowd/crowd.ogg"))
        crowd = fft_filter(crowd, lp=1900, hp=140)
        win = int(0.35 * SR)
        e = np.sqrt(np.convolve(crowd ** 2, np.ones(win) / win, mode="same")) + 1e-4
        tgt = np.median(e)
        g = (tgt / e) ** 0.55
        g = np.convolve(g, np.ones(win) / win, mode="same")
        cm = loopify(crowd * g, int(2.0 * SR))
        self.save("amb_crowd.wav", norm_rms(cm, -20.0), loop=True)
        heli = trim(decode(self.p("oga_heli/heli.ogg")), -36.0)
        heli = loopify(heli, int(2.0 * SR))
        heli = fft_filter(heli, hp=40, lp=5000, circular=True)
        self.save("amb_heli.wav", norm_rms(heli, -18.0), loop=True)
        self.siren(rng)

    def siren(self, rng):
        n = int(8.0 * SR)
        t = np.arange(n) / SR
        f = 720 + 640 * (0.5 - 0.5 * np.cos(2 * np.pi * t / 4.0))
        total = np.sum(2 * np.pi * f / SR)
        f *= np.round(total / (2 * np.pi)) * 2 * np.pi / total
        y = tone(f, n, [1.0, 0.45, 0.3, 0.18, 0.12, 0.07])
        y = fft_filter(y, lp=2200, hp=300, circular=True)
        ir = outdoor_ir(1.6, 0.45, rng, early=0.9)
        y = circ_convolve(y, ir)
        self.save("amb_siren.wav", norm_rms(y, -20.0), loop=True)

    def birds(self, rng):
        b = decode(self.p("oga_birds/birds.ogg"))
        b = fft_filter(b, hp=900)
        b = loopify(b, int(2.0 * SR))
        self.save("bird_loop_a.wav", norm_rms(b, -24.0), loop=True)
        park = decode(self.p("oga_park/birds.wav"))
        s = best_segment(park, 32.0, band=1500, prefer="max")
        pb = fft_filter(park[s : s + int(32.0 * SR)], hp=1000)
        pb = loopify(pb, int(2.0 * SR))
        self.save("bird_loop_b.wav", norm_rms(pb, -24.0), loop=True)
        for v in range(3):
            self.save("bird_maritaca_%d.wav" % v, self.maritaca(np.random.default_rng(100 + v)))
        for v in range(2):
            self.save("bird_bemtevi_%d.wav" % v, self.bemtevi(np.random.default_rng(200 + v), v))

    def maritaca(self, rng):
        dur = 2.6
        n = int(dur * SR)
        y = np.zeros(n)
        for bird in range(rng.integers(3, 6)):
            base = rng.uniform(1700, 2300)
            pan_t = rng.uniform(0, 0.6)
            k = rng.integers(3, 7)
            for c in range(k):
                st = pan_t + c * rng.uniform(0.17, 0.28) + rng.uniform(0, 0.05)
                cd = rng.uniform(0.08, 0.15)
                m = int(cd * SR)
                s0 = int(st * SR)
                if s0 + m >= n:
                    break
                tt = np.linspace(0, 1, m)
                fc = base * (1.0 + 0.35 * np.sin(np.pi * tt) - 0.12 * tt) * rng.uniform(0.95, 1.05)
                fc = fc * (1 + 0.04 * np.sin(2 * np.pi * rng.uniform(40, 70) * tt * cd))
                v = tone(fc, m, [1.0, 0.7, 0.5, 0.35, 0.22, 0.12], rng.uniform(0, 6))
                rough = 1.0 + 0.8 * np.sin(2 * np.pi * rng.uniform(55, 95) * tt * cd)
                env = np.sin(np.pi * tt) ** 0.6
                nz = fft_filter(rng.normal(0, 1, m), lp=6000, hp=1800)
                y[s0 : s0 + m] += (v * rough + 0.5 * nz) * env * rng.uniform(0.4, 1.0)
        y = fft_filter(y, hp=900, lp=7500)
        y = lin_convolve(y, outdoor_ir(0.5, 0.12, rng, early=0.5))[:n]
        y *= env_adsr(n, 0.002, 0.15)
        return norm_peak(y, -2.0)

    def bemtevi(self, rng, v):
        notes = [(0.11, 2650, 2350, 0.8), (0.05, 0, 0, 0), (0.08, 3050, 3000, 0.7), (0.06, 0, 0, 0), (0.34, 2450, 3300, 1.0)]
        reps = 1 if v == 0 else 2
        parts = [np.zeros(int(0.05 * SR))]
        for r in range(reps):
            for d, f0, f1, a in notes:
                m = int(d * SR)
                if f0 == 0:
                    parts.append(np.zeros(m))
                    continue
                tt = np.linspace(0, 1, m)
                if d > 0.3:
                    f = f0 + (f1 - f0) * np.sin(np.pi * 0.5 * tt / 0.6).clip(0, 1) - 500 * np.clip(tt - 0.6, 0, 1)
                else:
                    f = f0 + (f1 - f0) * tt
                f = f * rng.uniform(0.97, 1.03)
                env = np.sin(np.pi * tt) ** 1.2
                parts.append(tone(f, m, [1.0, 0.18, 0.06]) * env * a)
            parts.append(np.zeros(int(rng.uniform(0.6, 0.9) * SR)))
        y = np.concatenate(parts)
        y = lin_convolve(y, outdoor_ir(0.6, 0.15, rng, early=0.35))[: len(y)]
        y = fft_filter(y, hp=1200)
        return norm_peak(y, -2.0)

    def vehicles(self, rng):
        cars = "oga_cars/x/"
        e1 = decode(self.p(cars + "Car_Engine_Loop.ogg"))
        e1 = fft_filter(e1, hp=35)
        l1, s1 = best_loop(e1, int(0.8 * SR), int(0.15 * SR))
        self.save("sfx_engine_car.wav", norm_rms(l1, -16.0), loop=True)
        e2 = decode(self.p(cars + "Car_Engine_Loop_2.ogg"))
        e2 = fft_filter(e2, hp=35)
        l2, s2 = best_loop(e2, int(0.8 * SR), int(0.15 * SR))
        self.save("sfx_engine_car_b.wav", norm_rms(l2, -16.0), loop=True)
        bus = resample(l2, 0.62, periodic=True)
        n = len(bus)
        sub = periodic_noise(n, lambda f: 1.0 / np.sqrt(1 + (f / 90.0) ** 6) / np.sqrt(1 + (25.0 / f) ** 6), rng)
        bus = fft_filter(bus, lp=2600, circular=True) + 0.5 * sub * rms(bus)
        self.save("sfx_engine_bus.wav", norm_rms(bus, -15.0), loop=True)
        self.loop_scores = {"engine_car": round(s1, 3), "engine_car_b": round(s2, 3)}
        horn = trim(decode(self.p(cars + "Car_Horn.ogg")))
        horn = fft_filter(horn, hp=200, lp=6000)
        self.save("sfx_horn_0.wav", norm_peak(horn, -1.0))
        self.save("sfx_horn_1.wav", self.horn([(0.0, 0.42)], [415, 520], rng))
        self.save("sfx_horn_2.wav", self.horn([(0.0, 0.11), (0.18, 0.3)], [360, 452], rng))
        self.save("sfx_horn_3.wav", self.horn([(0.0, 0.9)], [392, 494], rng))
        self.save("sfx_brake_squeal.wav", self.squeal(rng))
        self.save("sfx_air_brake.wav", self.air_brake(rng))

    def horn(self, taps, freqs, rng):
        end = max(s + d for s, d in taps) + 0.25
        n = int(end * SR)
        y = np.zeros(n)
        harm = [1.0 / k ** 1.1 for k in range(1, 14)]
        for s, d in taps:
            m = int(d * SR)
            s0 = int(s * SR)
            v = sum(tone(np.full(m, f * rng.uniform(0.995, 1.005)), m, harm, rng.uniform(0, 6)) for f in freqs)
            y[s0 : s0 + m] += v * env_adsr(m, 0.012, 0.035)
        y = fft_filter(y, lp=3200, hp=250)
        y = lin_convolve(y, outdoor_ir(0.4, 0.1, rng, early=0.3))[:n]
        return norm_peak(np.tanh(1.6 * y / peak(y)), -1.0)

    def squeal(self, rng):
        d = 1.15
        n = int(d * SR)
        t = np.arange(n) / SR
        walk = np.cumsum(rng.normal(0, 1, n))
        walk = fft_filter(walk - walk.mean(), lp=6)
        walk = walk / (peak(walk) + 1e-9)
        f = 2150 + 90 * np.sin(2 * np.pi * 6.5 * t) + 160 * walk - 220 * t
        v = tone(f, n, [1.0, 0.3, 0.12])
        am = 1.0 + 0.35 * fft_filter(rng.normal(0, 1, n), lp=40)
        e = np.clip(t / 0.12, 0, 1) * np.clip((d - t) / 0.3, 0, 1)
        scrub = fft_filter(rng.normal(0, 1, n), lp=1600, hp=250) * np.exp(-t / 0.5)
        y = 0.55 * v * am * e + 0.25 * scrub * e
        return norm_peak(y, -2.0)

    def air_brake(self, rng):
        d = 1.1
        n = int(d * SR)
        t = np.arange(n) / SR
        hiss = fft_filter(rng.normal(0, 1, n), hp=1700, lp=8500)
        e = np.clip(t / 0.01, 0, 1) * (0.25 + 0.75 * np.exp(-t / 0.22)) * np.clip((d - t) / 0.4, 0, 1)
        thump = np.sin(2 * np.pi * 110 * t) * np.exp(-t / 0.025)
        chk = fft_filter(rng.normal(0, 1, n), hp=800, lp=4000) * np.exp(-t / 0.012)
        y = 0.6 * hiss * e / peak(hiss) + 0.5 * thump + 0.4 * chk / peak(chk)
        return norm_peak(y, -2.0)

    def steps(self, rng):
        imp = "kenney_impact/x/Audio/"
        for kind in ["concrete", "grass", "wood"]:
            for i in range(5):
                x = trim(decode(self.p(imp + "footstep_%s_%03d.ogg" % (kind, i))))
                x = fft_filter(x, hp=70)
                self.save("step_%s_%d.wav" % (kind, i), norm_peak(x, -3.0))
        for i in range(5):
            x = trim(decode(self.p(imp + "footstep_concrete_%03d.ogg" % i)))
            a = resample(x, 0.88)
            a = fft_filter(a, lp=2300, hp=60)
            m = len(a)
            grit = fft_filter(rng.normal(0, 1, m), hp=1800, lp=5500) * np.exp(-np.arange(m) / SR / 0.03)
            a = a / peak(a) + 0.12 * grit / peak(grit)
            self.save("step_asphalt_%d.wav" % i, norm_peak(a, -3.0))
            p = resample(x, 1.07)
            p = fft_filter(p, hp=110)
            m = len(p)
            click = np.zeros(m + int(0.05 * SR))
            off = int(rng.uniform(0.022, 0.034) * SR)
            k = int(0.02 * SR)
            cl = fft_filter(rng.normal(0, 1, k), hp=2200, lp=7000) * np.exp(-np.arange(k) / SR / 0.004)
            click[off : off + k] += 0.35 * cl / peak(cl)
            click[:m] += p / peak(p)
            self.save("step_paver_%d.wav" % i, norm_peak(click, -3.0))

    def misc(self, rng):
        n = int(0.075 * SR)
        t = np.arange(n) / SR
        sq = np.sign(np.sin(2 * np.pi * 2800 * t)) * 0.6 + np.sin(2 * np.pi * 2800 * t) * 0.4
        b = fft_filter(sq, lp=6000) * env_adsr(n, 0.004, 0.012)
        self.save("sfx_crossing_beep.wav", norm_peak(b, -3.0))
        ui = "kenney_interface/x/Audio/"
        for src, dst in [("open_001", "ui_phone_open"), ("close_001", "ui_phone_close"), ("confirmation_002", "ui_goal")]:
            x = trim(decode(self.p(ui + src + ".ogg")))
            self.save(dst + ".wav", norm_peak(x, -3.0))


def main():
    src, out, report = sys.argv[1], sys.argv[2], sys.argv[3]
    os.makedirs(report, exist_ok=True)
    b = Builder(src, out, report)
    b.build()
    with open(os.path.join(report, "loop_scores.json"), "w") as f:
        json.dump(b.loop_scores, f)
    for it in b.items:
        print(it)


if __name__ == "__main__":
    main()
