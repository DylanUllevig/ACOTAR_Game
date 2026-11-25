#!/usr/bin/env python3
"""Procedural fallback audio for the ACOTAR slice: every sound effect, UI
sound, ambience loop and music track the game asks for, synthesised from
scratch (noise, filters, plucked strings, bells, pads and a convolution
reverb). Nothing is sampled or copied.

Final audio dropped under res://assets/final/audio/<kind>/ with the same name
wins over these automatically (see scripts/autoload/audio.gd).

Usage:  python3 tools/gen_audio.py [name ...]     (default: everything)
Needs:  numpy, scipy, ffmpeg with libvorbis (music and ambience are .ogg)
Writes: assets/audio/{sfx,ui,ambience,music}/
"""
import os
import subprocess
import sys
import tempfile

import numpy as np
from scipy import signal
from scipy.io import wavfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio")
SR = 44100


# ------------------------------------------------------------------ basics
def secs(d):
    return int(round(d * SR))


def tt(d):
    return np.arange(secs(d)) / SR


def rng_for(name, k=0):
    return np.random.default_rng(abs(hash((name, k))) % (2 ** 32) if False else (sum(map(ord, name)) * 7919 + k * 104729) % (2 ** 32))


def white(n, r):
    return r.uniform(-1.0, 1.0, n)


def pink(n, r):
    b = [0.049922035, -0.095993537, 0.050612699, -0.004408786]
    a = [1, -2.494956002, 2.017265875, -0.522189400]
    x = signal.lfilter(b, a, r.standard_normal(n + 2000))[2000:]
    return x / (np.max(np.abs(x)) + 1e-9)


def brown(n, r):
    x = signal.lfilter([1.0], [1.0, -0.997], r.standard_normal(n + 4000))[4000:]
    x = x - signal.lfilter([1.0], [1.0, -0.9999], x) * 0.0
    x = hp(x, 20)
    return x / (np.max(np.abs(x)) + 1e-9)


def _sos(kind, f, order=2):
    nyq = SR / 2
    if kind == "band":
        lo, hi = f
        return signal.butter(order, [max(10, lo) / nyq, min(hi, nyq * 0.98) / nyq], "band", output="sos")
    return signal.butter(order, min(f, nyq * 0.98) / nyq, kind, output="sos")


def lp(x, f, order=2):
    return signal.sosfilt(_sos("low", f, order), x)


def hp(x, f, order=2):
    return signal.sosfilt(_sos("high", f, order), x)


def bp(x, lo, hi, order=2):
    return signal.sosfilt(_sos("band", (lo, hi), order), x)


def reson(x, f, q):
    """Resonant peak filter: an impulse through it rings at f."""
    b, a = signal.iirpeak(min(f, SR / 2 * 0.95), q, fs=SR)
    return signal.lfilter(b, a, x)


def sweep_filter(x, cut, kind="low", order=2, block=256):
    """Time-varying Butterworth filter; cut is an array (one value per sample)."""
    out = np.zeros_like(x)
    zi = None
    for s in range(0, len(x), block):
        e = min(len(x), s + block)
        c = float(np.mean(cut[s:e]))
        if kind == "band":
            sos = _sos("band", (c * 0.7, c * 1.35), order)
        else:
            sos = _sos(kind, c, order)
        if zi is None:
            zi = np.zeros((sos.shape[0], 2))
        out[s:e], zi = signal.sosfilt(sos, x[s:e], zi=zi)
    return out


def env_ad(n, a, d, curve=4.0):
    """Attack then exponential-ish decay over n samples."""
    na = max(1, secs(a))
    t = np.arange(n) / SR
    e = np.exp(-curve * np.clip(t - a, 0, None) / max(d, 1e-4))
    e[:na] *= np.linspace(0, 1, na)
    return e


def env_adsr(n, a, d, s, r):
    na, nd, nr = secs(a), secs(d), secs(r)
    ns = max(0, n - na - nd - nr)
    e = np.concatenate([np.linspace(0, 1, max(1, na)), np.linspace(1, s, max(1, nd)), np.full(ns, s), np.linspace(s, 0, max(1, nr))])
    return np.pad(e, (0, max(0, n - len(e))))[:n]


def fade(x, fin=0.003, fout=0.01):
    x = x.copy()
    a, b = secs(fin), secs(fout)
    if a > 0:
        x[:a] *= np.linspace(0, 1, a)
    if b > 0:
        x[-b:] *= np.linspace(1, 0, b)
    return x


def mix_at(dst, src, start, gain=1.0):
    s = secs(start) if isinstance(start, float) else start
    if s >= len(dst):
        return
    e = min(len(dst), s + len(src))
    dst[s:e] += src[: e - s] * gain


def norm_peak(x, peak_db=-3.0):
    p = np.max(np.abs(x)) + 1e-12
    return x * (10 ** (peak_db / 20) / p)


def norm_rms(x, rms_db, peak_db=-1.0):
    r = np.sqrt(np.mean(x ** 2)) + 1e-12
    y = x * (10 ** (rms_db / 20) / r)
    lim = 10 ** (peak_db / 20)
    over = np.max(np.abs(y))
    if over > lim:
        # gentle limiting: soft-knee tanh above 70% of the ceiling
        k = lim * 0.7
        mag = np.abs(y)
        soft = np.where(mag > k, k + (lim - k) * np.tanh((mag - k) / (lim - k)), mag)
        y = np.sign(y) * soft
    return y


def midi(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


# --------------------------------------------------------------- instruments
def ks(freq, dur, r, bright=0.55, decay=0.996, pick=0.5):
    """Karplus-Strong plucked string with a fractional delay (in tune up high)."""
    n = secs(dur)
    period = SR / freq
    N = int(np.floor(period - 0.5))
    g = (period - 0.5) - N
    N = max(2, N)
    exc = r.uniform(-1, 1, N)
    # brightness: smooth the burst; pick position: comb out some harmonics
    k = max(1, int((1.0 - bright) * 8))
    if k > 1:
        exc = np.convolve(exc, np.ones(k) / k, mode="same")
    shift = int(N * pick)
    exc = exc - 0.6 * np.roll(exc, shift)
    out = np.zeros(n + N + 2)
    out[:N] = exc
    pos = N
    while pos < n:
        e = min(n, pos + N)
        a = out[pos - N:e - N]
        b = out[pos - N - 1:e - N - 1] if pos - N - 1 >= 0 else np.concatenate([[0.0], out[pos - N:e - N - 1]])
        out[pos:e] = decay * ((1 - g) * a + g * b)
        pos = e
    y = out[:n]
    return fade(y, 0.001, 0.02)


def bell(freq, dur, ratios=(1.0, 2.0, 2.76, 4.07, 5.4), decays=(1.0, 0.6, 0.45, 0.3, 0.2), amps=(1.0, 0.5, 0.35, 0.2, 0.12)):
    t = tt(dur)
    y = np.zeros_like(t)
    for ra, de, am in zip(ratios, decays, amps):
        f = freq * ra
        if f < SR / 2 * 0.9:
            y += am * np.sin(2 * np.pi * f * t) * np.exp(-t / (dur * 0.35 * de))
    return fade(y, 0.002, 0.05)


def polyblep_saw(freq, n, phase0=0.0):
    t = np.arange(n)
    dt = freq / SR
    ph = (phase0 + t * dt) % 1.0
    y = 2.0 * ph - 1.0
    m1 = ph < dt
    x = ph[m1] / dt
    y[m1] -= x + x - x * x - 1.0
    m2 = ph > 1.0 - dt
    x = (ph[m2] - 1.0) / dt
    y[m2] -= x * x + x + x + 1.0
    return y


def pad_note(freq, dur, r, cutoff=1400.0, detune=0.006, voices=3, a=1.2, rel=1.6):
    n = secs(dur + rel)
    y = np.zeros(n)
    for v in range(voices):
        d = 1.0 + detune * (v - (voices - 1) / 2)
        y += polyblep_saw(freq * d, n, r.uniform())
    y = lp(y / voices, cutoff, 2)
    y = lp(y, cutoff * 1.6, 2)
    e = env_adsr(n, a, 0.4, 0.85, rel)
    return y * e


def flute(freq, dur, r, vib=0.004):
    n = secs(dur + 0.25)
    t = np.arange(n) / SR
    vib_amt = np.clip((t - 0.3) / 0.4, 0, 1) * vib
    f = freq * (1 + vib_amt * np.sin(2 * np.pi * 5.2 * t))
    ph = 2 * np.pi * np.cumsum(f) / SR
    y = np.sin(ph) + 0.12 * np.sin(2 * ph) + 0.04 * np.sin(3 * ph)
    breath = bp(white(n, r), freq * 0.8, freq * 2.5, 2) * 0.08
    e = env_adsr(n, 0.09, 0.2, 0.8, 0.25)
    return (y + breath) * e


def drum(f0, f1, dur, r, noise_amt=0.3, tone_decay=0.25, noise_lp=1500):
    t = tt(dur)
    f = f1 + (f0 - f1) * np.exp(-t / 0.035)
    ph = 2 * np.pi * np.cumsum(f) / SR
    tone = np.sin(ph) * np.exp(-t / tone_decay)
    nz = lp(white(len(t), r), noise_lp) * np.exp(-t / 0.04) * noise_amt
    return fade(tone + nz, 0.0005, 0.02)


# ------------------------------------------------------------------ reverb
_IR = {}


def reverb_ir(seconds, damp=5000.0, seed=3):
    key = (seconds, damp, seed)
    if key not in _IR:
        r = np.random.default_rng(seed)
        n = secs(seconds)
        t = np.arange(n) / SR
        tau = seconds / 6.9
        irs = []
        for ch in range(2):
            x = r.standard_normal(n) * np.exp(-t / tau)
            x = lp(x, damp, 1)
            x[: secs(0.012)] = 0.0
            irs.append(x / np.sqrt(np.sum(x ** 2)))
        _IR[key] = irs
    return _IR[key]


def reverb(st, wet=0.3, seconds=2.6, damp=5000.0):
    """st: (2, n) stereo. Returns (2, n + tail) with a convolution tail."""
    irl, irr = reverb_ir(seconds, damp)
    n = st.shape[1]
    out = np.zeros((2, n + len(irl)))
    out[:, :n] += st * (1 - wet * 0.5)
    out[0, : n + len(irl) - 1] += signal.fftconvolve(st[0], irl) * wet
    out[1, : n + len(irr) - 1] += signal.fftconvolve(st[1], irr) * wet
    return out


def pan(x, p):
    """Equal-power pan, p from -1 (left) to 1 (right)."""
    a = (p + 1) * np.pi / 4
    return np.vstack([x * np.cos(a), x * np.sin(a)])


def to_loop(st, loop_len):
    """Wrap everything past loop_len back onto the start: seamless loop."""
    n = secs(loop_len)
    out = st[:, :n].copy()
    tail = st[:, n:]
    pos = 0
    while tail.shape[1] > 0:
        k = min(n, tail.shape[1])
        out[:, :k] += tail[:, :k]
        tail = tail[:, k:]
        pos += k
    return out


def loop_crossfade(st, loop_len, xf=2.0):
    """For noise beds: render loop_len + xf, crossfade the extra into the head."""
    n, m = secs(loop_len), secs(xf)
    out = st[:, :n].copy()
    w = np.sin(np.linspace(0, np.pi / 2, m)) ** 2
    out[:, :m] = st[:, :m] * w + st[:, n:n + m] * (1 - w)
    return out


# ------------------------------------------------------------------- output
def write_wav(path, x):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    x = np.clip(x, -1, 1)
    data = (x.T if x.ndim == 2 else x) * 32767
    wavfile.write(path, SR, data.astype(np.int16))


def write_ogg(path, st, q=4):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        tmp = f.name
    write_wav(tmp, st)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", str(q), path], check=True)
    os.remove(tmp)


def sfx_out(kind, name, x, peak=-3.0):
    # a 20 Hz high-pass takes out any DC the saturation stages leave behind
    write_wav(os.path.join(OUT, kind, name + ".wav"), norm_peak(fade(hp(x, 20), 0.0005, 0.01), peak))


# ====================================================================== SFX
def step(surface, k):
    r = rng_for("step_" + surface, k)
    d = 0.16
    n = secs(d)
    t = np.arange(n) / SR
    if surface == "snow":
        # compacting snow: a dull press and a spray of tiny crystal crunches
        press = lp(white(n, r), 380) * np.exp(-t / 0.045) * 0.9
        crunch = np.zeros(n)
        for _ in range(int(r.integers(18, 30))):
            at = int(r.uniform(0.004, 0.1) * SR)
            g = r.uniform(0.2, 1.0) ** 2
            L = int(r.uniform(0.002, 0.006) * SR)
            mix_at(crunch, white(L, r) * np.exp(-np.arange(L) / (L * 0.3)) * g, at)
        crunch = bp(crunch, 1400, 6500) * 1.1
        y = press + crunch * np.clip(1.2 - t / d, 0, 1)
    elif surface == "mud":
        # wet slush: low suck with a resonant gurgle that drops in pitch
        y = lp(white(n, r), 700) * np.exp(-t / 0.05)
        cut = 900 * np.exp(-t / 0.06) + 250
        y = sweep_filter(white(n, r), cut, "band") * np.exp(-t / 0.07) * 0.8 + y * 0.6
    else:
        # boards underfoot: a few wooden modes
        imp = np.zeros(n)
        imp[0] = 1.0
        imp[1:secs(0.004)] = white(secs(0.004) - 1, r) * 0.3
        y = np.zeros(n)
        for f, q, g in ((r.uniform(150, 190), 8, 1.0), (r.uniform(380, 450), 12, 0.6), (r.uniform(850, 1000), 18, 0.35)):
            y += reson(imp, f, q) * g
        y *= np.exp(-t / 0.05)
        y += lp(white(n, r), 2500) * np.exp(-t / 0.01) * 0.25
    return y


def bow_draw():
    r = rng_for("bow_draw")
    d = 0.75
    n = secs(d)
    t = np.arange(n) / SR
    # wood creak: stick-slip clicks speeding up as the limbs bend
    clicks = np.zeros(n)
    tt_ = 0.02
    while tt_ < d - 0.05:
        g = 0.4 + 0.6 * tt_ / d
        L = secs(0.004)
        mix_at(clicks, np.exp(-np.arange(L) / (L * 0.25)) * g, secs(tt_))
        tt_ += r.uniform(0.012, 0.03) * (1.4 - tt_ / d)
    creak = reson(clicks, 520 + 0 * t[0], 14) * 0.6 + reson(clicks, 1260, 20) * 0.25
    cut = 300 + 900 * (t / d)
    stretch = sweep_filter(white(n, r), cut, "band") * (0.15 + 0.35 * t / d)
    y = (creak + stretch) * env_adsr(n, 0.05, 0.1, 1.0, 0.08)
    return y


def bow_full():
    r = rng_for("bow_full")
    n = secs(0.3)
    t = np.arange(n) / SR
    imp = np.zeros(n)
    for k in range(6):
        imp[secs(0.02 + k * 0.025)] = 1.0 - k * 0.12
    return (reson(imp, 610, 16) + reson(imp, 1400, 22) * 0.3) * np.exp(-t / 0.12)


def bow_release():
    r = rng_for("bow_release")
    d = 0.5
    n = secs(d)
    t = np.arange(n) / SR
    twang = ks(98.0, d, r, bright=0.9, decay=0.985) * 0.9
    twang += ks(196.5, d, r, bright=0.8, decay=0.98) * 0.3
    cut = 3500 * np.exp(-t / 0.12) + 400
    whoosh = sweep_filter(white(n, r), cut, "band") * env_ad(n, 0.01, 0.12, 3.0) * 0.8
    thump = lp(white(n, r), 200) * np.exp(-t / 0.03) * 0.6
    return twang * np.exp(-t / 0.18) + whoosh + thump


def dry_click():
    r = rng_for("dry_click")
    n = secs(0.08)
    t = np.arange(n) / SR
    imp = np.zeros(n)
    imp[0] = 1
    imp[secs(0.025)] = 0.6
    return reson(imp, 2200, 12) * np.exp(-t / 0.02) + reson(imp, 900, 8) * 0.4 * np.exp(-t / 0.02)


def knife_swing(k):
    r = rng_for("knife_swing", k)
    d = 0.22
    n = secs(d)
    t = np.arange(n) / SR
    peak = r.uniform(0.07, 0.1)
    shape = np.exp(-((t - peak) / 0.045) ** 2)
    cut = 900 + 3200 * shape * r.uniform(0.85, 1.15)
    y = sweep_filter(white(n, r), cut, "band") * shape
    ring = np.sin(2 * np.pi * r.uniform(3800, 4600) * t) * shape * 0.04
    return y + ring


def flesh_hit(name, k, wet=1.0, thud_f=140.0):
    r = rng_for(name, k)
    n = secs(0.25)
    t = np.arange(n) / SR
    thud = lp(white(n, r), thud_f * 2) * np.exp(-t / 0.035)
    thud += np.sin(2 * np.pi * thud_f * t * (1 - 0.3 * t / 0.25)) * np.exp(-t / 0.05) * 0.7
    slap = bp(white(n, r), 900, 3000) * np.exp(-t / 0.012) * 0.6 * wet
    squelch = sweep_filter(white(n, r), 1800 * np.exp(-t / 0.05) + 300, "band") * np.exp(-t / 0.06) * 0.35 * wet
    return thud + slap + squelch


def arrow_hit_wood(k):
    r = rng_for("arrow_hit_wood", k)
    n = secs(0.45)
    t = np.arange(n) / SR
    imp = np.zeros(n)
    imp[0] = 1.0
    imp[1:secs(0.003)] = white(secs(0.003) - 1, r) * 0.4
    thock = reson(imp, r.uniform(560, 680), 10) + reson(imp, r.uniform(1400, 1700), 16) * 0.5
    thock *= np.exp(-t / 0.06)
    # the shaft quivering in the trunk
    f = r.uniform(70, 95)
    buzz = np.sign(np.sin(2 * np.pi * f * t)) * 0.5 + np.sin(2 * np.pi * f * t)
    buzz = lp(buzz, 900) * np.exp(-t / 0.12) * 0.22 * (0.6 + 0.4 * np.sin(2 * np.pi * 12 * t))
    return thock + buzz


def arrow_hit_snow(k):
    r = rng_for("arrow_hit_snow", k)
    n = secs(0.2)
    t = np.arange(n) / SR
    return lp(white(n, r), 1200) * np.exp(-t / 0.04) + bp(white(n, r), 2500, 7000) * np.exp(-t / 0.02) * 0.3


def arrow_break():
    r = rng_for("arrow_break")
    n = secs(0.22)
    t = np.arange(n) / SR
    snap = np.zeros(n)
    for a, g in ((0.0, 1.0), (0.012, 0.6), (0.03, 0.35), (0.045, 0.2)):
        L = secs(0.006)
        mix_at(snap, white(L, r) * np.exp(-np.arange(L) / (L * 0.2)) * g, secs(a))
    return reson(snap, 1800, 6) * 0.6 + hp(snap, 2000) * 0.8 + reson(snap, 420, 8) * 0.3 * np.exp(-t / 0.05)


def pickup():
    t = tt(0.32)
    y = bell(midi(79), 0.32) * 0.6
    y[secs(0.06):] += bell(midi(84), 0.32)[: len(y) - secs(0.06)] * 0.5
    return y * np.exp(-t / 0.2)


def eat():
    r = rng_for("eat")
    d = 0.5
    y = np.zeros(secs(d))
    for a in (0.0, 0.13, 0.27):
        n = secs(0.09)
        tt_ = np.arange(n) / SR
        c = bp(white(n, r), 1500, 5500) * np.exp(-tt_ / 0.025) * r.uniform(0.6, 1.0)
        c += lp(white(n, r), 400) * np.exp(-tt_ / 0.03) * 0.5
        mix_at(y, c, a)
    return y


def forage():
    r = rng_for("forage")
    d = 0.6
    n = secs(d)
    t = np.arange(n) / SR
    flutter = 0.5 + 0.5 * np.abs(np.sin(2 * np.pi * 11 * t + r.uniform(0, 6)))
    rustle = bp(white(n, r), 1800, 6000) * flutter * env_adsr(n, 0.05, 0.2, 0.6, 0.25)
    twig = np.zeros(n)
    twig[secs(0.32)] = 1.0
    twig = reson(twig, 1300, 10) * np.exp(-np.clip(t - 0.32, 0, None) / 0.03)
    return rustle * 0.7 + twig * 0.5


def wings():
    """A bird bursting up: four or five quick, papery wingbeats, slowing and
    fading as it climbs away."""
    r = rng_for("wings")
    d = 0.7
    n = secs(d)
    y = np.zeros(n)
    at = 0.0
    gap = 0.07
    g = 1.0
    for k in range(5):
        L = secs(0.05)
        tt = np.arange(L) / SR
        beat = bp(white(L, r), 500, 3200) * np.exp(-tt / 0.018) * np.sin(np.pi * np.clip(tt / 0.05, 0, 1)) ** 0.5
        mix_at(y, beat * g, secs(at))
        at += gap
        gap *= 1.12
        g *= 0.78
    return lp(y, 4200)


def breath(n, r, f1, f2, dur_env):
    """Breathy vocal noise through two formants (no words, no pitch)."""
    x = white(n, r)
    y = reson(x, f1, 6) + reson(x, f2, 8) * 0.6
    return lp(y, 3500) * dur_env


def player_hurt():
    r = rng_for("player_hurt")
    n = secs(0.35)
    t = np.arange(n) / SR
    impact = lp(white(n, r), 300) * np.exp(-t / 0.03) + np.sin(2 * np.pi * 95 * t) * np.exp(-t / 0.06) * 0.6
    # the blow lands on wool and leather: a dry mid slap, so the hit reads on small speakers too
    slap = bp(white(n, r), 700, 3200) * np.exp(-t / 0.018) * 0.55
    gasp = breath(n, r, 800, 1300, env_ad(n, 0.015, 0.12, 3.0)) * 0.3
    return impact + slap + gasp


def player_down():
    r = rng_for("player_down")
    n = secs(1.0)
    t = np.arange(n) / SR
    fall = lp(white(n, r), 500) * np.exp(-np.clip(t - 0.12, 0, None) / 0.08) * (t > 0.12)
    boom = np.sin(2 * np.pi * (60 - 20 * t) * t) * np.exp(-np.clip(t - 0.12, 0, None) / 0.3) * (t > 0.12)
    snow = bp(white(n, r), 2000, 7000) * np.exp(-np.clip(t - 0.12, 0, None) / 0.15) * (t > 0.12) * 0.25
    sigh = breath(n, r, 650, 1100, env_ad(n, 0.05, 0.4, 3.0)) * 0.08
    return fall * 0.8 + boom * 0.7 + snow + sigh


def growl(name, k, dur, f0, formants, rough=28.0, gain_curve=None):
    r = rng_for(name, k)
    n = secs(dur)
    t = np.arange(n) / SR
    # a rough glottal buzz: a low pulse train jittered, through throat formants
    f = f0 * (1 + 0.04 * np.sin(2 * np.pi * r.uniform(2, 4) * t)) * (1 + 0.02 * white(n, r))
    ph = np.cumsum(f) / SR
    pulses = np.maximum(0, np.sin(2 * np.pi * ph)) ** 6
    roughness = 0.6 + 0.4 * np.sin(2 * np.pi * rough * t + 2 * np.sin(2 * np.pi * 3 * t))
    src = pulses * roughness + white(n, r) * 0.35
    y = np.zeros(n)
    for fc, q, g in formants:
        y += reson(src, fc, q) * g
    y = lp(y, 2600)
    e = env_adsr(n, 0.08, 0.2, 0.9, 0.25) if gain_curve is None else gain_curve(t)
    return np.tanh(y * 3.0) * e


def wolf_growl(k):
    return growl("wolf_growl", k, 1.3, 62 + k * 6, ((260, 4, 1.0), (620, 6, 0.6), (1150, 8, 0.25)))


def wolf_snarl():
    return growl("wolf_snarl", 0, 0.9, 110, ((480, 4, 0.8), (1100, 5, 0.8), (2100, 7, 0.4)), rough=40)


def wolf_lunge():
    r = rng_for("wolf_lunge")
    n = secs(0.6)
    t = np.arange(n) / SR
    s = growl("wolf_lunge", 0, 0.6, 120, ((520, 4, 0.9), (1300, 6, 0.6)), rough=45,
              gain_curve=lambda tt_: np.clip(tt_ / 0.05, 0, 1) * np.exp(-tt_ / 0.3))
    whoosh = sweep_filter(white(n, r), 2500 * np.exp(-t / 0.2) + 500, "band") * env_ad(n, 0.02, 0.25, 3.0) * 0.6
    return s + whoosh


def wolf_bite():
    r = rng_for("wolf_bite")
    n = secs(0.35)
    t = np.arange(n) / SR
    imp = np.zeros(n)
    imp[0] = 1.0
    imp[secs(0.012)] = 0.8
    clack = reson(imp, 1900, 9) + reson(imp, 3100, 12) * 0.5 + reson(imp, 700, 6) * 0.4
    clack *= np.exp(-t / 0.03)
    tail = growl("wolf_bite", 0, 0.35, 140, ((600, 5, 0.6), (1400, 6, 0.4)), gain_curve=lambda tt_: np.exp(-tt_ / 0.12)) * 0.4
    return clack + tail


def wolf_yelp():
    r = rng_for("wolf_yelp")
    n = secs(0.55)
    t = np.arange(n) / SR
    f = 950 * np.exp(-t / 0.35) + 380
    f = f * (1 + 0.02 * np.sin(2 * np.pi * 9 * t))
    ph = 2 * np.pi * np.cumsum(f) / SR
    tone = np.sin(ph) + 0.4 * np.sin(2 * ph) + 0.15 * np.sin(3 * ph)
    y = tone + bp(white(n, r), 800, 2600) * 0.3
    y = reson(y, 1200, 3) * 0.5 + y * 0.5
    return np.tanh(y * 1.5) * env_adsr(n, 0.02, 0.1, 0.7, 0.3)


def ash_strike():
    r = rng_for("ash_strike")
    d = 2.0
    n = secs(d)
    t = np.arange(n) / SR
    impact = lp(white(n, r), 250) * np.exp(-t / 0.08) * 1.2 + np.sin(2 * np.pi * (55 - 15 * t) * t) * np.exp(-t / 0.4)
    shimmer = np.zeros(n)
    for f in (midi(86), midi(90), midi(93), midi(98), midi(101)):
        b = bell(f * r.uniform(0.995, 1.005), 1.8, ratios=(1.0, 2.32, 3.9), decays=(1.0, 0.5, 0.3), amps=(1.0, 0.3, 0.12))
        mix_at(shimmer, b, r.uniform(0.02, 0.25), 0.22)
    sizzle = hp(white(n, r), 5000) * env_ad(n, 0.01, 0.5, 3.0) * 0.15
    st = np.vstack([impact + shimmer + sizzle, impact + np.roll(shimmer, 220) + sizzle])
    st = reverb(st, wet=0.35, seconds=2.2)[:, :n]
    return st.mean(axis=0)


def beast_roar():
    r = rng_for("beast_roar")
    d = 2.6
    n = secs(d)
    t = np.arange(n) / SR
    gc = lambda tt_: np.clip(tt_ / 0.25, 0, 1) * np.exp(-np.clip(tt_ - 1.2, 0, None) / 0.5)
    low = growl("beast_roar", 0, d, 48, ((180, 3, 1.0), (420, 4, 0.8), (900, 6, 0.45)), rough=22, gain_curve=gc)
    mid = growl("beast_roar", 1, d, 95, ((700, 4, 0.7), (1500, 6, 0.5)), rough=31, gain_curve=gc) * 0.5
    st = np.vstack([low + mid, low + np.roll(mid, 300)])
    st = reverb(st, wet=0.3, seconds=2.4)[:, :n]
    return st.mean(axis=0)


# ======================================================================= UI
def ui_tap(name, f, decay=0.03, noise=0.2):
    r = rng_for(name)
    n = secs(0.12)
    t = np.arange(n) / SR
    imp = np.zeros(n)
    imp[0] = 1
    imp[1:secs(0.002)] = white(secs(0.002) - 1, r) * noise
    y = reson(imp, f, 10) + reson(imp, f * 2.3, 14) * 0.3
    return y * np.exp(-t / decay)


def ui_swoosh(name, up=True, d=0.28):
    r = rng_for(name)
    n = secs(d)
    t = np.arange(n) / SR
    cut = (600 + 2600 * t / d) if up else (3200 - 2600 * t / d)
    y = sweep_filter(white(n, r), cut, "band") * np.sin(np.pi * t / d) ** 2 * 0.7
    if up:
        y += bell(midi(84), d, amps=(1.0, 0.3, 0.1, 0.05, 0.0)) * 0.12
    return y


def ui_page():
    r = rng_for("page")
    d = 0.32
    n = secs(d)
    t = np.arange(n) / SR
    flutter = 0.4 + 0.6 * np.abs(np.sin(2 * np.pi * 18 * t))
    cut = 1500 + 3000 * np.sin(np.pi * t / d)
    return sweep_filter(white(n, r), cut, "band") * flutter * np.sin(np.pi * t / d) ** 1.5


def ui_chime(notes, gap, d, decay_scale=1.0):
    total = secs(gap * (len(notes) - 1) + d)
    y = np.zeros(total)
    for i, m in enumerate(notes):
        b = bell(midi(m), d * decay_scale, amps=(1.0, 0.45, 0.2, 0.08, 0.04))
        mix_at(y, b, secs(gap * i), 0.8)
    return y


def ui_coin():
    y = np.zeros(secs(0.45))
    for a, g in ((0.0, 1.0), (0.07, 0.55)):
        b = bell(2100, 0.35, ratios=(1.0, 1.62, 2.48, 3.3), decays=(1.0, 0.7, 0.5, 0.3), amps=(1.0, 0.6, 0.4, 0.2))
        mix_at(y, b, a, g)
    return y


def ui_chapter():
    d = 3.2
    n = secs(d)
    r = rng_for("chapter")
    gong = bell(midi(38), d, ratios=(1.0, 2.0, 2.9, 4.1), decays=(1.0, 0.6, 0.4, 0.3), amps=(1.0, 0.4, 0.25, 0.1))
    pad = np.zeros(n)
    for m in (50, 57, 62, 65):
        pn = pad_note(midi(m), d - 1.4, r, cutoff=900, a=1.0, rel=1.4)
        mix_at(pad, pn, 0, 0.15)
    st = np.vstack([gong * 0.6 + pad, gong * 0.6 + pad])
    st = reverb(st, wet=0.4, seconds=2.6)[:, :n]
    return st.mean(axis=0) * env_adsr(n, 0.01, 0.1, 1.0, 0.6)


def ui_tier():
    y = ui_chime([62, 66, 69, 74, 78], 0.11, 1.4)
    r = rng_for("tier")
    st = np.vstack([y, np.roll(y, 120)])
    st = reverb(st, wet=0.35, seconds=2.0)[:, : len(y) + secs(0.6)]
    return st.mean(axis=0)


# ================================================================= AMBIENCE
def amb_forest_wind(L=40.0):
    r = rng_for("forest_wind")
    n = secs(L + 2.0)
    t = np.arange(n) / SR
    per = lambda k, ph=0.0: np.sin(2 * np.pi * k * t / L + ph)
    gust = 0.55 + 0.25 * per(3, 0.4) + 0.12 * per(7, 1.9) + 0.08 * per(13, 4.1)
    low = lp(brown(n, r), 260) * (0.7 + 0.3 * per(2, 1.0))
    cut = 520 + 260 * per(3, 0.4) + 140 * per(9, 2.2)
    mid = sweep_filter(pink(n, r), cut, "band") * gust
    whistle_cut = 1500 + 300 * per(5, 0.7)
    whistle = sweep_filter(white(n, r), whistle_cut, "band", order=4) * np.clip(per(4, 2.5), 0, 1) ** 3 * 0.25
    left = low * 0.9 + mid * 1.0 + whistle
    right = low * 0.9 + np.roll(mid, secs(0.4)) * 1.0 + np.roll(whistle, secs(0.9))
    st = loop_crossfade(np.vstack([left, right]), L)
    return norm_rms(st, -24.0)


def amb_night_wind(L=40.0):
    r = rng_for("night_wind")
    n = secs(L + 2.0)
    t = np.arange(n) / SR
    per = lambda k, ph=0.0: np.sin(2 * np.pi * k * t / L + ph)
    gust = 0.5 + 0.3 * per(4, 0.1) + 0.15 * per(11, 2.0)
    low = lp(brown(n, r), 180) * 0.6
    mid = sweep_filter(pink(n, r), 700 + 300 * per(4, 0.1), "band") * gust
    w1 = sweep_filter(white(n, r), 1100 + 250 * per(6, 1.3), "band", order=4) * (0.5 + 0.5 * per(5, 0.3)) * 0.35
    w2 = sweep_filter(white(n, r), 1750 + 300 * per(7, 2.9), "band", order=4) * np.clip(per(3, 1.1), 0, 1) ** 2 * 0.25
    left = low + mid + w1 + w2 * 0.6
    right = low + np.roll(mid, secs(0.5)) + w1 * 0.6 + np.roll(w2, secs(1.1))
    st = loop_crossfade(np.vstack([left, right]), L)
    return norm_rms(st, -25.0)


def amb_hearth(L=30.0):
    r = rng_for("hearth")
    n = secs(L + 2.0)
    t = np.arange(n) / SR
    per = lambda k, ph=0.0: np.sin(2 * np.pi * k * t / L + ph)
    roar = lp(brown(n, r), 380) * (0.75 + 0.15 * per(5, 0.3) + 0.1 * per(17, 1.7))
    st = np.zeros((2, n))
    st[0] += roar
    st[1] += roar
    # crackles: many tiny ticks, a few louder snaps, the odd low pop
    tick_t = 0.0
    while tick_t < L + 1.9:
        tick_t += r.exponential(1 / 9.0)
        g = min(1.0, r.pareto(2.5) * 0.25 + 0.05)
        L2 = secs(r.uniform(0.002, 0.008))
        c = white(L2, r) * np.exp(-np.arange(L2) / (L2 * 0.25)) * g
        c = bp(np.pad(c, (0, secs(0.02))), r.uniform(1500, 3000), r.uniform(5000, 9000))
        p = r.uniform(-0.7, 0.7)
        cs = pan(c, p)
        s = secs(tick_t)
        e = min(n, s + cs.shape[1])
        if s < n:
            st[:, s:e] += cs[:, : e - s] * 0.9
    pop_t = 0.0
    while pop_t < L + 1.9:
        pop_t += r.exponential(1 / 0.6)
        L3 = secs(0.08)
        c = reson(np.pad(white(secs(0.004), r), (0, L3)), r.uniform(250, 700), 4) * np.exp(-np.arange(L3 + secs(0.004)) / secs(0.02))
        s = secs(pop_t)
        cs = pan(c * r.uniform(0.3, 0.7), r.uniform(-0.5, 0.5))
        e = min(n, s + cs.shape[1])
        if s < n:
            st[:, s:e] += cs[:, : e - s]
    hiss = hp(pink(n, r), 3500) * 0.05
    st += hiss
    st = loop_crossfade(st, L)
    return norm_rms(st, -26.0)


def amb_village(L=40.0):
    r = rng_for("village")
    n = secs(L + 2.0)
    t = np.arange(n) / SR
    st = np.zeros((2, n))
    # a crowd murmur: many voices of shaped noise, too far away to make out
    for v in range(14):
        rate = r.uniform(3.0, 5.5)
        syll = np.maximum(0, np.sin(2 * np.pi * rate * t + r.uniform(0, 6))) ** 2
        phrase = np.clip(np.sin(2 * np.pi * t / r.uniform(3, 7) + r.uniform(0, 6)) + 0.3, 0, 1)
        f1 = r.uniform(350, 750)
        f2 = r.uniform(1100, 2200)
        src = white(n, r)
        voice = (reson(src, f1, 4) + reson(src, f2, 6) * 0.5) * syll * phrase
        voice = lp(voice, 1800)
        st += pan(voice * r.uniform(0.4, 1.0), r.uniform(-0.8, 0.8))
    st *= 0.18
    # distant hammer at the smithy, a cart, a little wind
    k = 0.0
    while k < L:
        k += r.uniform(4.0, 9.0)
        for j in range(int(r.integers(2, 5))):
            b = bell(r.uniform(1250, 1450), 0.5, ratios=(1.0, 2.7, 4.1), decays=(1.0, 0.4, 0.2), amps=(1.0, 0.3, 0.1))
            b = lp(b, 3000) * 0.12
            s = secs(k + j * 0.55)
            bs = pan(b, 0.55)
            e = min(n, s + bs.shape[1])
            if s < n:
                st[:, s:e] += bs[:, : e - s]
    wind = sweep_filter(pink(n, r), 600 + 200 * np.sin(2 * np.pi * 3 * t / L), "band") * 0.25
    st += np.vstack([wind, np.roll(wind, secs(0.3))])
    st = loop_crossfade(st, L)
    return norm_rms(st, -26.0)


# =================================================================== MUSIC
class Song:
    def __init__(self, name, bpm, beats_per_bar, bars, tail=4.0):
        self.name = name
        self.beat = 60.0 / bpm
        self.bar = self.beat * beats_per_bar
        self.bars = bars
        self.L = self.bar * bars
        self.n = secs(self.L + tail)
        self.st = np.zeros((2, self.n))
        self.r = rng_for("music_" + name)

    def at(self, bar, beat=0.0):
        return (bar * self.bar + beat * self.beat) % self.L

    def add(self, mono, start, gain=1.0, p=0.0):
        s = secs(start)
        x = pan(mono * gain, p)
        e = min(self.n, s + x.shape[1])
        self.st[:, s:e] += x[:, : e - s]

    def finish(self, rms_db=-21.0, wet=0.32, rev=2.8, damp=5500.0):
        st = reverb(self.st, wet=wet, seconds=rev, damp=damp)
        st = to_loop(st, self.L)
        st = hp(st, 30)
        return norm_rms(st, rms_db)


def chord_pad(song, bar, bars, notes, gain=0.12, cutoff=1300, a=1.4):
    dur = bars * song.bar
    for i, m in enumerate(notes):
        x = pad_note(midi(m), dur, song.r, cutoff=cutoff, a=a, rel=1.8)
        song.add(x, song.at(bar), gain, p=(-0.5 + i / max(1, len(notes) - 1)) * 0.6)


def music_title():
    # F major, wistful rather than grim: harp arpeggios under a flute that
    # rises, and a half cadence on C that leads back round to F
    s = Song("title", 70, 4, 16)
    prog = [("F", [53, 57, 60, 65], 41), ("C/E", [52, 55, 60, 64], 40), ("Dm", [50, 53, 57, 62], 38), ("Bb", [46, 50, 53, 58], 34),
            ("F", [53, 57, 60, 65], 41), ("Gm", [50, 55, 58, 62], 43), ("Bb", [50, 53, 58, 62], 46), ("C", [48, 52, 55, 60], 48)]
    for i, (_, notes, bass) in enumerate(prog):
        bar = i * 2
        chord_pad(s, bar, 2, notes, gain=0.07, cutoff=1300)
        b = pad_note(midi(bass + 12), 2 * s.bar, s.r, cutoff=520, a=0.6, rel=1.2)
        s.add(b, s.at(bar), 0.15)
        # harp: broken chord in eighths, rising then falling
        tones = sorted(set([n + 12 for n in notes] + [notes[0] + 24]))
        pattern = tones + tones[-2:0:-1]
        for k in range(16):
            m = pattern[k % len(pattern)]
            x = ks(midi(m), 2.5, s.r, bright=0.52, decay=0.9965)
            s.add(x, s.at(bar, k * 0.5), 0.10 * (1.0 if k % 4 == 0 else 0.75), p=(m - 66) / 20.0)
        # a soft bell on each change of chord
        s.add(bell(midi(notes[-1] + 12), 3.0, amps=(1.0, 0.3, 0.12, 0.05, 0.02)), s.at(bar), 0.035, p=0.4)
    melody = [(4, 0, 69, 2), (4, 2, 72, 1), (4, 3, 74, 1), (5, 0, 72, 3), (5, 3, 69, 1),
              (6, 0, 70, 2), (6, 2, 69, 1), (6, 3, 67, 1), (7, 0, 65, 4),
              (8, 0, 72, 2), (8, 2, 77, 2), (9, 0, 76, 2), (9, 2, 72, 2),
              (10, 0, 74, 3), (10, 3, 70, 1), (11, 0, 74, 2), (11, 2, 72, 2),
              (12, 0, 70, 2), (12, 2, 74, 2), (13, 0, 77, 3), (13, 3, 76, 1),
              (14, 0, 74, 2), (14, 2, 72, 2), (15, 0, 72, 4)]
    for bar, beat, m, d in melody:
        x = flute(midi(m), d * s.beat * 0.95, s.r)
        s.add(x, s.at(bar, beat), 0.085, p=0.1)
    return s.finish(-21.0, wet=0.36, rev=3.0)


def music_forest():
    # D major pentatonic over an open fifth: a quiet, clear winter morning
    # rather than a threat; the hunt has its own music for that
    s = Song("forest", 64, 4, 16)
    chord_pad(s, 0, 16, [38, 45], gain=0.075, cutoff=650, a=3.0)
    chord_pad(s, 0, 8, [62, 66, 69], gain=0.028, cutoff=2400, a=3.5)
    chord_pad(s, 8, 8, [59, 62, 67], gain=0.028, cutoff=2400, a=3.5)
    scale = [62, 64, 66, 69, 71, 74, 76, 78]
    tpos = 0.4
    while tpos < s.L - 0.5:
        m = scale[int(s.r.integers(0, len(scale)))]
        x = ks(midi(m), 4.0, s.r, bright=0.45, decay=0.998)
        s.add(x, tpos, 0.11 * s.r.uniform(0.65, 1.0), p=s.r.uniform(-0.6, 0.6))
        if s.r.random() < 0.4:
            m2 = scale[min(len(scale) - 1, scale.index(m) + 2)]
            s.add(ks(midi(m2), 4.0, s.r, bright=0.45, decay=0.998), tpos + 0.2, 0.07, p=s.r.uniform(-0.6, 0.6))
        if s.r.random() < 0.12:
            s.add(bell(midi(m + 12), 3.5, amps=(1.0, 0.3, 0.12, 0.05, 0.02)), tpos + 0.5, 0.03, p=s.r.uniform(-0.5, 0.5))
        tpos += s.r.uniform(1.3, 3.2)
    return s.finish(-22.5, wet=0.44, rev=3.6, damp=4800)


def music_hunt():
    s = Song("hunt", 96, 4, 16)
    roots = [38] * 4 + [34, 34, 36, 36] + [38] * 4 + [39, 39, 38, 38]
    hits = [0, 3, 6]
    for bar in range(16):
        root = roots[bar]
        for e in range(8):
            accent = e in hits
            x = pad_note(midi(root), s.beat * 0.45, s.r, cutoff=700 if accent else 450, a=0.005, rel=0.12, voices=2)
            s.add(x, s.at(bar, e * 0.5), 0.2 if accent else 0.11)
            if accent:
                s.add(drum(140, 48, 0.6, s.r, noise_amt=0.4, tone_decay=0.22), s.at(bar, e * 0.5), 0.55)
            elif e % 2 == 1:
                tick = hp(white(secs(0.05), s.r), 4000) * np.exp(-np.arange(secs(0.05)) / secs(0.01))
                s.add(tick, s.at(bar, e * 0.5), 0.05, p=0.4)
        if bar % 4 == 0:
            chord_pad(s, bar, 4, [root + 12, root + 15, root + 19], gain=0.07, cutoff=900, a=0.8)
    for bar in (12, 13, 14, 15):
        for k in range(16):
            for m in (69, 70):
                x = pad_note(midi(m), s.beat * 0.22, s.r, cutoff=2400, a=0.01, rel=0.05, voices=2)
                s.add(x, s.at(bar, k * 0.25), 0.025 + 0.02 * (bar - 12) / 3.0, p=0.3 if m == 69 else -0.3)
    rn = secs(s.bar)
    tr = np.arange(rn) / SR
    riser = sweep_filter(white(rn, s.r), 300 + 4000 * (tr / s.bar) ** 2, "band") * (tr / s.bar) ** 2
    s.add(riser, s.at(15), 0.12)
    return s.finish(-20.0, wet=0.22, rev=2.0)


def music_cottage():
    s = Song("cottage", 84, 3, 24)
    chords = [(41, [53, 57, 60]), (41, [53, 57, 60]), (40, [52, 55, 60]), (40, [52, 55, 60]), (38, [50, 53, 57]), (38, [50, 53, 57]),
              (46, [50, 53, 58]), (48, [52, 55, 60]), (41, [53, 57, 60]), (41, [53, 57, 60]), (45, [52, 57, 60]), (45, [52, 57, 60]),
              (46, [50, 53, 58]), (46, [50, 53, 58]), (48, [52, 55, 60]), (48, [52, 55, 58]), (38, [50, 53, 57]), (38, [50, 53, 57]),
              (46, [50, 53, 58]), (46, [50, 53, 58]), (41, [53, 57, 60]), (48, [52, 55, 60]), (41, [53, 57, 60]), (41, [53, 57, 60])]
    for bar, (bass, notes) in enumerate(chords):
        root = bass + 12
        arp = [root, root + 7, notes[1] + 12, notes[2] + 12, notes[1] + 12, root + 7]
        for k, m in enumerate(arp):
            x = ks(midi(m), 2.2, s.r, bright=0.4, decay=0.9968)
            s.add(x, s.at(bar, k * 0.5), 0.12 * (1.0 if k == 0 else 0.7), p=(m - 62) / 24.0)
        if bar % 2 == 0:
            chord_pad(s, bar, 2, notes, gain=0.04, cutoff=900, a=1.2)
    melody = [(8, 0, 72, 3), (9, 0, 69, 2), (9, 2, 70, 1), (10, 0, 72, 2), (10, 2, 74, 1), (11, 0, 72, 3), (12, 0, 69, 2), (12, 2, 67, 1),
              (13, 0, 65, 3), (14, 0, 67, 2), (14, 2, 69, 1), (15, 0, 67, 3), (16, 0, 69, 3), (17, 0, 65, 2), (17, 2, 62, 1),
              (18, 0, 70, 3), (19, 0, 69, 2), (19, 2, 67, 1), (20, 0, 65, 3), (21, 0, 64, 3), (22, 0, 65, 3)]
    for bar, beat, m, d in melody:
        s.add(flute(midi(m), d * s.beat * 0.95, s.r, vib=0.003), s.at(bar, beat), 0.07, p=-0.1)
    return s.finish(-22.0, wet=0.34, rev=2.6)


def music_village():
    s = Song("village", 140, 6, 24)  # 6/8 counted in eighths: beat = one eighth
    prog = [(43, [55, 59, 62]), (43, [55, 59, 62]), (41, [53, 57, 60]), (43, [55, 59, 62]),
            (43, [55, 59, 62]), (48, [52, 55, 60]), (41, [53, 57, 60]), (43, [55, 59, 62])] * 3
    for bar, (bass, notes) in enumerate(prog):
        for beat in (0, 3):
            for i, m in enumerate(sorted(notes)):
                x = ks(midi(m), 1.4, s.r, bright=0.6, decay=0.993)
                s.add(x, s.at(bar, beat) + i * 0.014, 0.085 if beat == 0 else 0.06, p=-0.3 + i * 0.15)
            s.add(drum(110, 60, 0.4, s.r, noise_amt=0.5, tone_decay=0.12, noise_lp=900), s.at(bar, beat), 0.28 if beat == 0 else 0.18)
        x = pad_note(midi(bass), s.bar, s.r, cutoff=500, a=0.05, rel=0.3, voices=2)
        s.add(x, s.at(bar), 0.09)
    chord_pad(s, 0, 24, [43, 50], gain=0.035, cutoff=700, a=1.0)
    tune = [(0, [74, 71, 67]), (1, [69, 71, 72]), (2, [72, 69, 65]), (3, [67, 71, 74]),
            (4, [76, 74, 71]), (5, [72, 67, 64]), (6, [65, 69, 72]), (7, [71, None, 67])]
    for rep in (1, 2):
        for b, notes in tune:
            bar = rep * 8 + b
            for k, m in enumerate(notes):
                if m is None:
                    continue
                s.add(flute(midi(m + 12 * (rep == 2 and b in (4, 5))), s.beat * 1.8, s.r, vib=0.0025), s.at(bar, k * 2), 0.06, p=0.2)
    return s.finish(-22.0, wet=0.25, rev=2.0)


def music_night_ride():
    s = Song("night_ride", 180, 6, 28)  # 6/8 in eighths
    # E minor, but climbing (i, VI, III, VII) rather than sinking to a dark V
    prog = [[52, 55, 59], [48, 52, 55], [55, 59, 62], [50, 54, 57]]
    for i in range(14):
        notes = prog[i % 4]
        chord_pad(s, i * 2, 2, notes, gain=0.07, cutoff=1000, a=1.2)
    for bar in range(28):
        for beat in (0, 3):
            for k, g in ((0, 0.6), (1, 0.45), (2, 1.0)):
                x = drum(90, 50, 0.25, s.r, noise_amt=0.6, tone_decay=0.06, noise_lp=500)
                s.add(lp(x, 400), s.at(bar, beat + k * 0.55), 0.12 * g)
    shimmer = [83, 84, 86, 78, 83, 79, 86, 81]
    for i in range(14):
        m = shimmer[i % len(shimmer)]
        s.add(bell(midi(m), 3.0, amps=(1.0, 0.25, 0.12, 0.05, 0.02)), s.at(i * 2, 1.5), 0.05, p=0.5 if i % 2 else -0.5)
    horn = [(0, 64, 10), (8, 67, 10), (16, 64, 6), (22, 71, 6)]
    for bar, m, d in horn:
        x = pad_note(midi(m - 12), d * s.beat, s.r, cutoff=900, a=0.8, rel=1.5, voices=2)
        s.add(x, s.at(bar), 0.06)
    return s.finish(-22.0, wet=0.45, rev=3.6, damp=4500)


# ============================================================ SPRING COURT
# Milestone 2: the manor's gardens and halls, the woods in eternal spring,
# Fire Night, Midsummer. Brighter and warmer than the mortal winter.

def saw_var(f):
    """Band-limited sawtooth whose frequency can change every sample."""
    dt = np.clip(f / SR, 1e-6, 0.45)
    ph = np.cumsum(dt) % 1.0
    y = 2.0 * ph - 1.0
    m1 = ph < dt
    x = ph[m1] / dt[m1]
    y[m1] -= x + x - x * x - 1.0
    m2 = ph > 1.0 - dt
    x = (ph[m2] - 1.0) / dt[m2]
    y[m2] -= x * x + x + x + 1.0
    return y


def fiddle(freq, dur, r, vib=0.006, a=0.05, rel=0.14, bright=3400.0, slide=0.0):
    """A bowed string: a vibrato sawtooth through a violin-ish body, with bow hiss.
    slide > 0 scoops up into the note from that many semitones below."""
    n = secs(dur + rel)
    t = np.arange(n) / SR
    vib_amt = np.clip((t - 0.14) / 0.25, 0, 1) * vib
    f = freq * (1 + vib_amt * np.sin(2 * np.pi * 5.7 * t + r.uniform(0, 6)))
    if slide > 0:
        f = f * 2 ** (-slide * np.exp(-t / 0.04) / 12.0)
    src = saw_var(f)
    body = (reson(src, 290, 3) * 1.0 + reson(src, 470, 4) * 0.7 + reson(src, 1050, 5) * 0.55
            + reson(src, 2700, 6) * 0.3 + lp(src, bright) * 0.35)
    bow = bp(white(n, r), 2200, 7000) * 0.025
    e = env_adsr(n, a, 0.12, 0.82, rel)
    return lp(body * 0.4 + bow, bright * 1.4) * e


def strum(song, start, notes, gain, spread=0.016, bright=0.55, dur=1.6, p=0.0):
    for i, m in enumerate(sorted(notes)):
        song.add(ks(midi(m), dur, song.r, bright=bright, decay=0.9955), start + i * spread, gain * (0.8 + 0.2 * (i == 0)), p=p - 0.2 + i * 0.12)


def bodhran(r, hit="open"):
    if hit == "open":
        return drum(190, 72, 0.32, r, noise_amt=0.45, tone_decay=0.09, noise_lp=1200)
    return drum(320, 160, 0.12, r, noise_amt=0.6, tone_decay=0.03, noise_lp=2600)


# ----------------------------------------------------------------- sfx
def step_spring(surface, k):
    r = rng_for("step_" + surface, k)
    d = 0.18
    n = secs(d)
    t = np.arange(n) / SR
    if surface == "grass":
        # a soft brush of blades and a muffled press into turf
        swish = bp(white(n, r), r.uniform(1800, 2400), r.uniform(6000, 8000)) * env_ad(n, 0.012, 0.05, 3.0) * 0.5
        press = lp(white(n, r), 260) * np.exp(-t / 0.03) * 0.8
        y = swish + press
    elif surface == "gravel":
        # many small stones shifting: a crisp scatter of clicks over a low press
        press = lp(white(n, r), 420) * np.exp(-t / 0.035) * 0.8
        grit = np.zeros(n)
        for _ in range(int(r.integers(26, 42))):
            at = int(r.uniform(0.002, 0.11) * SR)
            L = int(r.uniform(0.0015, 0.004) * SR)
            g = r.uniform(0.25, 1.0) ** 1.5
            c = reson(np.pad(white(L, r), (0, secs(0.006))), r.uniform(2500, 5200), 6) * g
            mix_at(grit, c * np.exp(-np.arange(len(c)) / (L * 0.8)), at)
        y = press + hp(grit, 1500) * 0.9 * np.clip(1.15 - t / d, 0, 1)
    elif surface == "stone":
        # a heel on marble: a hard click, a short bright ring, a little room
        imp = np.zeros(n)
        imp[0] = 1.0
        imp[1:secs(0.002)] = white(secs(0.002) - 1, r) * 0.5
        ring = reson(imp, r.uniform(2300, 2900), 14) * 0.6 + reson(imp, r.uniform(4200, 5200), 20) * 0.3
        thud = np.sin(2 * np.pi * r.uniform(90, 120) * t) * np.exp(-t / 0.018) * 0.6
        y = (ring + hp(white(n, r), 3000) * np.exp(-t / 0.004) * 0.4) * np.exp(-t / 0.03) + thud
    else:
        # shallow water: a slap, then a few bubbles rising in pitch
        slap = bp(white(n, r), 600, 4000) * np.exp(-t / 0.03) * 0.7
        y = slap
        for _ in range(int(r.integers(2, 5))):
            at = r.uniform(0.01, 0.09)
            L = secs(r.uniform(0.02, 0.04))
            tb = np.arange(L) / SR
            fb = r.uniform(500, 900) * (1 + 3.0 * tb / (L / SR))
            b = np.sin(2 * np.pi * np.cumsum(fb) / SR) * np.exp(-tb / 0.012) * r.uniform(0.15, 0.35)
            mix_at(y, b, secs(at))
    return y


def hiss():
    r = rng_for("hiss")
    n = secs(0.8)
    t = np.arange(n) / SR
    e = np.clip(t / 0.25, 0, 1) ** 1.5 * np.exp(-np.clip(t - 0.45, 0, None) / 0.12)
    sib = bp(white(n, r), 4200, 9500, 4) * e
    tongue = sweep_filter(white(n, r), 3100 + 400 * np.sin(2 * np.pi * 9 * t), "band", order=4) * e * 0.25
    return sib + tongue


def hiss_hurt():
    r = rng_for("hiss_hurt")
    n = secs(0.55)
    t = np.arange(n) / SR
    f = 1150 * np.exp(-t / 0.5) + 520
    shriek = saw_var(f * (1 + 0.03 * np.sin(2 * np.pi * 31 * t)))
    shriek = (reson(shriek, 1400, 4) + reson(shriek, 2600, 6) * 0.6) * env_ad(n, 0.01, 0.25, 3.0) * 0.5
    sib = bp(white(n, r), 3800, 9000, 4) * env_ad(n, 0.005, 0.3, 3.0) * 0.7
    return np.tanh((shriek + sib) * 2.0)


def puca_growl():
    gc = lambda tt_: np.clip(tt_ / 0.3, 0, 1) * np.exp(-np.clip(tt_ - 0.7, 0, None) / 0.25)
    a = growl("puca_growl", 0, 1.2, 78, ((320, 4, 1.0), (760, 6, 0.7), (1500, 8, 0.3)), rough=34, gain_curve=gc)
    b = growl("puca_growl", 1, 1.2, 117, ((540, 5, 0.6), (1900, 7, 0.4)), rough=41, gain_curve=gc) * 0.4
    return a + b


def puca_hurt():
    r = rng_for("puca_hurt")
    n = secs(0.5)
    t = np.arange(n) / SR
    f = 520 * np.exp(-t / 0.18) + 210
    v = saw_var(f * (1 + 0.04 * np.sin(2 * np.pi * 27 * t)))
    y = reson(v, 900, 4) + reson(v, 1800, 5) * 0.6 + reson(v, 3200, 7) * 0.3
    return np.tanh(y * env_ad(n, 0.008, 0.22, 3.0) * 2.5) + bp(white(n, r), 2000, 6000) * env_ad(n, 0.004, 0.06) * 0.2


def bogge_whisper(k=0):
    r = rng_for("bogge_whisper", k)
    n = secs(2.2)
    t = np.arange(n) / SR
    y = np.zeros(n)
    at = 0.05
    while at < 1.8:
        L = secs(r.uniform(0.12, 0.26))
        f1, f2 = r.uniform(400, 900), r.uniform(1100, 2400)
        syl = breath(L, r, f1, f2, env_adsr(L, 0.03, 0.05, 0.7, 0.06)) * r.uniform(0.5, 1.0)
        if r.random() < 0.35:
            # a sibilant: the 's' of 'look'... 'see'... 'me'
            syl = syl + bp(white(L, r), 4500, 9000) * env_ad(L, 0.02, 0.1) * 0.5
        mix_at(y, syl, secs(at))
        at += L / SR + r.uniform(0.01, 0.08)
    y = hp(y, 250)
    st = reverb(np.vstack([y, np.roll(y, secs(0.012))]), wet=0.55, seconds=3.2, damp=3500)[:, :n]
    return st.mean(axis=0) * np.clip(1.4 - t / 2.2, 0, 1)


def suriel_scream():
    r = rng_for("suriel_scream")
    d = 2.0
    n = secs(d)
    t = np.arange(n) / SR
    e = np.clip(t / 0.06, 0, 1) * np.exp(-np.clip(t - 0.9, 0, None) / 0.35)
    y = np.zeros(n)
    for k, (f0, g) in enumerate(((980, 1.0), (1237, 0.7), (1486, 0.5), (734, 0.5))):
        f = f0 * (1 + 0.025 * np.sin(2 * np.pi * (6.5 + k) * t + k)) * (1 - 0.12 * t / d)
        y += saw_var(f) * g
    y = reson(y, 1800, 3) + reson(y, 3100, 4) * 0.7 + bp(white(n, r), 1500, 6000) * 0.25
    y = np.tanh(y * 1.5) * e
    st = reverb(np.vstack([y, np.roll(y, secs(0.02))]), wet=0.4, seconds=3.0)[:, :n]
    return st.mean(axis=0)


def door_thud():
    r = rng_for("door_thud")
    n = secs(0.9)
    t = np.arange(n) / SR
    boom = np.sin(2 * np.pi * (72 - 18 * t) * t) * np.exp(-t / 0.12)
    wood = (reson(np.pad(white(secs(0.01), r), (0, n - secs(0.01))), 180, 6) * 0.6
            + reson(np.pad(white(secs(0.01), r), (0, n - secs(0.01))), 430, 9) * 0.35) * np.exp(-t / 0.08)
    latch = np.zeros(n)
    lt = secs(0.16)
    L = secs(0.03)
    latch[lt:lt + L] = reson(white(L, r), 3200, 12) * np.exp(-np.arange(L) / (L * 0.2)) * 0.4
    st = reverb(np.vstack([boom + wood + latch, boom + wood + latch]), wet=0.25, seconds=1.6)[:, :n]
    return st.mean(axis=0)


def big_drum():
    r = rng_for("big_drum")
    x = drum(120, 44, 1.6, r, noise_amt=0.35, tone_decay=0.45, noise_lp=900)
    st = reverb(np.vstack([x, x]), wet=0.35, seconds=2.6, damp=3000)[:, :len(x)]
    return st.mean(axis=0)


def clatter():
    # tins and brushes, or a knife, hitting the ground and bouncing
    r = rng_for("clatter")
    n = secs(1.1)
    y = np.zeros(n)
    at, g = 0.0, 1.0
    for k in range(9):
        f = r.uniform(1800, 3600)
        b = bell(f, 0.25, ratios=(1.0, 1.47, 2.09, 2.56), decays=(1.0, 0.7, 0.5, 0.4), amps=(1.0, 0.6, 0.4, 0.25))
        b = b + bp(white(len(b), r), 2000, 8000) * np.exp(-np.arange(len(b)) / secs(0.005)) * 0.5
        mix_at(y, b * g, secs(at))
        at += r.uniform(0.04, 0.16) * (0.8 ** k) + 0.02
        g *= r.uniform(0.6, 0.85)
    thump = lp(white(n, r), 400) * np.exp(-np.arange(n) / secs(0.03)) * 0.5
    return y + thump


# ------------------------------------------------------------ ambience
def bird_call(r, kind):
    if kind == "chirp":
        out = np.zeros(secs(0.5))
        at = 0.0
        f0 = r.uniform(2800, 4200)
        for _ in range(int(r.integers(2, 6))):
            L = secs(r.uniform(0.035, 0.07))
            tb = np.arange(L) / SR
            f = f0 * (1 + r.uniform(0.25, 0.5) * tb / (L / SR))
            c = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * tb / (L / SR)) ** 2
            c += 0.2 * np.sin(4 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * tb / (L / SR)) ** 2
            mix_at(out, c, secs(at))
            at += L / SR + r.uniform(0.03, 0.08)
        return out
    if kind == "warble":
        L = secs(r.uniform(0.6, 1.1))
        tb = np.arange(L) / SR
        f = r.uniform(2400, 3400) * (1 + 0.18 * np.sin(2 * np.pi * r.uniform(14, 22) * tb)) * (1 + 0.1 * np.sin(2 * np.pi * 2.2 * tb))
        return np.sin(2 * np.pi * np.cumsum(f) / SR) * env_adsr(L, 0.04, 0.1, 0.8, 0.15)
    # a soft two-note dove-ish call, low and round
    out = np.zeros(secs(1.4))
    for k, (f, d) in enumerate(((560, 0.35), (470, 0.55))):
        L = secs(d)
        tb = np.arange(L) / SR
        c = np.sin(2 * np.pi * f * (1 - 0.04 * tb) * tb) * np.sin(np.pi * tb / d) ** 1.5
        mix_at(out, c + 0.15 * np.sin(4 * np.pi * f * tb) * np.sin(np.pi * tb / d), secs(0.05 + k * 0.45))
    return out


def amb_spring_day(L=40.0):
    r = rng_for("spring_day")
    n = secs(L + 2.0)
    t = np.arange(n) / SR
    per = lambda k, ph=0.0: np.sin(2 * np.pi * k * t / L + ph)
    breeze = sweep_filter(pink(n, r), 500 + 200 * per(3, 0.7), "band") * (0.45 + 0.2 * per(5, 1.1)) * 0.5
    leaves = hp(pink(n, r), 3000) * (0.5 + 0.5 * per(7, 2.3)) ** 2 * 0.08
    st = np.vstack([breeze + leaves, np.roll(breeze, secs(0.35)) + np.roll(leaves, secs(0.6))])
    at = 0.3
    while at < L + 1.5:
        kind = ["chirp", "chirp", "warble", "dove"][int(r.integers(0, 4))]
        c = bird_call(r, kind) * (0.12 if kind != "dove" else 0.08) * r.uniform(0.4, 1.0)
        c = hp(c, 300)
        cs = pan(c, r.uniform(-0.85, 0.85))
        s = secs(at)
        e = min(n, s + cs.shape[1])
        st[:, s:e] += cs[:, : e - s]
        at += r.exponential(1.1) + 0.15
    st = reverb(st, wet=0.18, seconds=1.8, damp=6000)[:, :n]
    st = loop_crossfade(st, L)
    return norm_rms(st, -27.0)


def amb_spring_night(L=40.0):
    r = rng_for("spring_night")
    n = secs(L + 2.0)
    t = np.arange(n) / SR
    per = lambda k, ph=0.0: np.sin(2 * np.pi * k * t / L + ph)
    breeze = sweep_filter(pink(n, r), 380 + 120 * per(2, 0.4), "band") * 0.3
    st = np.vstack([breeze, np.roll(breeze, secs(0.4))])
    # crickets: each a tiny pulse train repeated at its own rate
    for c in range(7):
        f = r.uniform(3900, 5200)
        rate = r.uniform(1.6, 3.2)
        pulses = int(r.integers(2, 5))
        p = r.uniform(-0.9, 0.9)
        g = r.uniform(0.02, 0.06)
        k = r.uniform(0, 1.0 / rate)
        Lp = secs(0.012)
        tp = np.arange(Lp) / SR
        blip = np.sin(2 * np.pi * f * tp) * np.sin(np.pi * tp / (Lp / SR)) ** 2
        while k < L + 1.9:
            for j in range(pulses):
                s = secs(k + j * 0.022)
                if s + Lp < n:
                    st[0, s:s + Lp] += blip * g * (1 - p) * 0.7
                    st[1, s:s + Lp] += blip * g * (1 + p) * 0.7
            k += 1.0 / rate * r.uniform(0.9, 1.1)
    # now and then, an owl
    at = r.uniform(3, 8)
    while at < L - 2:
        for j, (f, d) in enumerate(((370, 0.28), (330, 0.5))):
            Lh = secs(d)
            th = np.arange(Lh) / SR
            h = (np.sin(2 * np.pi * f * th) + 0.2 * np.sin(4 * np.pi * f * th)) * np.sin(np.pi * th / d) ** 2
            h = h + breath(Lh, r, f * 1.5, f * 3, np.sin(np.pi * th / d) ** 2) * 0.1
            hs = pan(h * 0.05, -0.5)
            s = secs(at + j * 0.4)
            st[:, s:s + hs.shape[1]] += hs[:, : min(hs.shape[1], n - s)]
        at += r.uniform(9, 16)
    st = reverb(st, wet=0.25, seconds=2.4, damp=5000)[:, :n]
    st = loop_crossfade(st, L)
    return norm_rms(st, -28.0)


def amb_bogge(L=30.0):
    r = rng_for("bogge_amb")
    n = secs(L + 2.0)
    t = np.arange(n) / SR
    per = lambda k, ph=0.0: np.sin(2 * np.pi * k * t / L + ph)
    drone = lp(brown(n, r), 110) * 0.9 + np.sin(2 * np.pi * 41.2 * t) * 0.12 * (0.6 + 0.4 * per(3))
    cold = sweep_filter(white(n, r), 1000 + 400 * per(4, 1.0) + 150 * per(11, 0.2), "band", order=4) * np.clip(per(3, 2.0), 0, 1) ** 2 * 0.35
    left = drone + cold
    right = drone + np.roll(cold, secs(1.3))
    st = np.vstack([left, right])
    at = 2.0
    k = 1
    while at < L - 2:
        w = bogge_whisper(k)[: secs(1.6)] * 0.12
        k += 1
        ws = pan(w, r.uniform(-0.9, 0.9))
        s = secs(at)
        st[:, s:s + ws.shape[1]] += ws[:, : min(ws.shape[1], n - s)]
        at += r.uniform(5.0, 9.0)
    st = loop_crossfade(st, L)
    return norm_rms(st, -25.0)


# --------------------------------------------------------------- music
SPRING_CH = {
    "D": (50, [62, 66, 69]), "A": (45, [61, 64, 69]), "Bm": (47, [62, 66, 71]), "F#m": (42, [61, 66, 69]),
    "G": (43, [62, 67, 71]), "Em": (40, [64, 67, 71]), "A7": (45, [61, 67, 69]),
}


def music_spring_manor():
    # D major waltz for the gardens in eternal spring: harp, pizzicato,
    # a flute tune, and a fiddle answering it in the middle
    s = Song("spring_manor", 96, 3, 32)
    prog = ["D", "A", "Bm", "F#m", "G", "D", "Em", "A",
            "D", "A", "Bm", "F#m", "G", "D", "A7", "D",
            "G", "D", "Em", "A", "Bm", "F#m", "G", "A",
            "D", "A", "Bm", "G", "D", "Em", "A", "D"]
    for bar, name in enumerate(prog):
        bass, notes = SPRING_CH[name]
        s.add(ks(midi(bass), 1.8, s.r, bright=0.35, decay=0.994), s.at(bar), 0.16, p=-0.1)
        s.add(ks(midi(bass + 7), 1.2, s.r, bright=0.35, decay=0.993), s.at(bar, 2), 0.08, p=-0.1)
        arp = [bass + 12, notes[0], notes[1], notes[2], notes[1], notes[0]]
        for k, m in enumerate(arp):
            s.add(ks(midi(m + 12), 2.0, s.r, bright=0.55, decay=0.9965), s.at(bar, k * 0.5), 0.075 * (1.0 if k == 0 else 0.7), p=(m - 62) / 22.0)
        if bar % 2 == 0:
            chord_pad(s, bar, 2, notes, gain=0.032, cutoff=1500, a=1.0)
        if bar % 4 == 0:
            s.add(bell(midi(notes[-1] + 24), 3.0, amps=(1.0, 0.3, 0.12, 0.05, 0.02)), s.at(bar), 0.025, p=0.5)
    tune = [(8, 0, 78, 2), (8, 2, 76, 1), (9, 0, 76, 2), (9, 2, 73, 1), (10, 0, 74, 1), (10, 1, 73, 1), (10, 2, 71, 1),
            (11, 0, 73, 3), (12, 0, 71, 2), (12, 2, 74, 1), (13, 0, 78, 2), (13, 2, 81, 1), (14, 0, 79, 1), (14, 1, 78, 1),
            (14, 2, 76, 1), (15, 0, 74, 3),
            (24, 0, 81, 2), (24, 2, 78, 1), (25, 0, 76, 2), (25, 2, 73, 1), (26, 0, 74, 1), (26, 1, 76, 1), (26, 2, 78, 1),
            (27, 0, 79, 3), (28, 0, 78, 2), (28, 2, 74, 1), (29, 0, 76, 1), (29, 1, 74, 1), (29, 2, 71, 1), (30, 0, 73, 2),
            (30, 2, 76, 1), (31, 0, 74, 3)]
    for bar, beat, m, d in tune:
        s.add(flute(midi(m), d * s.beat * 0.95, s.r, vib=0.0035), s.at(bar, beat), 0.075, p=0.12)
    answer = [(16, 0, 71, 3), (17, 0, 69, 3), (18, 0, 67, 2), (18, 2, 71, 1), (19, 0, 73, 3),
              (20, 0, 74, 3), (21, 0, 73, 3), (22, 0, 71, 3), (23, 0, 69, 2), (23, 2, 73, 1)]
    for bar, beat, m, d in answer:
        s.add(fiddle(midi(m), d * s.beat * 0.98, s.r, vib=0.005, a=0.12, rel=0.3), s.at(bar, beat), 0.05, p=-0.25)
    return s.finish(-21.5, wet=0.3, rev=2.4)


def music_spring_night():
    # a nocturne: slow harp under a music-box tune, warm and unhurried
    s = Song("spring_night", 58, 4, 16)
    prog = [(41, [57, 60, 64, 65]), (40, [55, 59, 62, 64]), (38, [57, 60, 62, 65]), (36, [55, 59, 60, 64]),
            (41, [57, 60, 64, 65]), (43, [55, 59, 62, 67]), (45, [55, 60, 64, 67]), (43, [55, 60, 62, 67])] * 2
    for bar, (bass, notes) in enumerate(prog):
        s.add(pad_note(midi(bass + 12), s.bar, s.r, cutoff=480, a=1.0, rel=1.6), s.at(bar), 0.1)
        chord_pad(s, bar, 1, notes, gain=0.03, cutoff=1100, a=1.4)
        figure = [notes[0], notes[2], notes[3], notes[1] + 12]
        for k, m in enumerate(figure):
            s.add(ks(midi(m + 12), 3.0, s.r, bright=0.45, decay=0.9975), s.at(bar, k), 0.07 * (1.0 if k == 0 else 0.75), p=(m - 60) / 20.0)
    box = [(8, 0, 76), (8, 2, 77), (9, 0, 74), (9, 3, 72), (10, 0, 77), (10, 2, 76), (11, 0, 71), (11, 2, 72),
           (12, 0, 76), (12, 2, 81), (13, 0, 79), (13, 2, 74), (14, 0, 76), (14, 2, 72), (15, 0, 74)]
    for bar, beat, m in box:
        s.add(bell(midi(m + 12), 3.2, amps=(1.0, 0.22, 0.1, 0.04, 0.02)), s.at(bar, beat), 0.045, p=0.3)
    for bar, m in ((1, 72), (3, 71), (5, 74), (7, 72)):
        s.add(flute(midi(m), 3.6 * s.beat, s.r, vib=0.003), s.at(bar), 0.035, p=-0.2)
    return s.finish(-23.0, wet=0.42, rev=3.4, damp=4500)


def music_spring_woods():
    # E major, light and dappled: a harp figure that never quite repeats,
    # a flute that calls like a bird, and pentatonic sparkles
    s = Song("spring_woods", 76, 4, 16)
    prog = [(40, [56, 59, 64]), (37, [56, 61, 64]), (45, [57, 61, 64]), (47, [59, 63, 66])] * 4
    for bar, (bass, notes) in enumerate(prog):
        s.add(pad_note(midi(bass + 12), s.bar, s.r, cutoff=520, a=0.8, rel=1.4), s.at(bar), 0.09)
        figure = [notes[0] + 12, notes[1] + 12, notes[2] + 12, notes[1] + 12, notes[0] + 24, notes[2] + 12, notes[1] + 12, notes[2] + 12]
        for k, m in enumerate(figure):
            s.add(ks(midi(m), 2.4, s.r, bright=0.5, decay=0.997), s.at(bar, k * 0.5), 0.065 * (1.0 if k % 4 == 0 else 0.7), p=(m - 70) / 18.0)
        if bar % 4 == 0:
            chord_pad(s, bar, 4, notes, gain=0.025, cutoff=1700, a=2.0)
    penta = [76, 78, 80, 83, 85, 88]
    tpos = 1.0
    while tpos < s.L - 1.0:
        m = penta[int(s.r.integers(0, len(penta)))]
        s.add(bell(midi(m + 12), 2.0, amps=(1.0, 0.2, 0.08, 0.03, 0.01)), tpos, 0.022, p=s.r.uniform(-0.7, 0.7))
        tpos += s.r.uniform(1.4, 3.4)
    calls = [(4, 0, 83, 0.5), (4, 0.5, 80, 1.0), (6, 2, 85, 0.5), (6, 2.5, 83, 1.5),
             (12, 0, 83, 0.5), (12, 0.5, 80, 1.0), (13, 2, 88, 0.5), (13, 2.5, 85, 0.5), (13, 3, 83, 1.0)]
    for bar, beat, m, d in calls:
        s.add(flute(midi(m), d * s.beat, s.r, vib=0.002), s.at(bar, beat), 0.05, p=0.35)
    return s.finish(-22.5, wet=0.4, rev=3.2, damp=5200)


def music_solstice():
    # Midsummer: a jig in D, fiddle on the tune, a flute doubling it on the
    # repeats, strummed strings and a frame drum
    s = Song("solstice", 270, 6, 32)  # 6/8 counted in eighths
    A = [[(74, 1), (78, 1), (81, 1), (81, 1), (78, 1), (74, 1)], [(79, 1), (83, 1), (79, 1), (78, 1), (76, 1), (74, 1)],
         [(78, 1), (81, 1), (78, 1), (74, 1), (78, 1), (81, 1)], [(76, 2), (73, 1), (69, 2), (73, 1)],
         [(74, 1), (78, 1), (81, 1), (83, 1), (81, 1), (78, 1)], [(79, 2), (83, 1), (81, 1), (79, 1), (78, 1)],
         [(76, 1), (78, 1), (79, 1), (78, 1), (76, 1), (73, 1)], [(74, 3), (74, 2), (None, 1)]]
    B = [[(83, 1), (86, 1), (83, 1), (81, 1), (83, 1), (79, 1)], [(81, 2), (78, 1), (74, 2), (78, 1)],
         [(79, 1), (83, 1), (86, 1), (83, 1), (81, 1), (79, 1)], [(81, 2), (76, 1), (73, 2), (76, 1)],
         [(78, 1), (83, 1), (78, 1), (74, 1), (78, 1), (83, 1)], [(79, 2), (74, 1), (71, 2), (74, 1)],
         [(76, 1), (78, 1), (79, 1), (81, 1), (79, 1), (76, 1)], [(74, 3), (74, 3)]]
    chA = ["D", "G", "D", "A", "D", "G", "A", "D"]
    chB = ["G", "D", "G", "A", "Bm", "G", "A", "D"]
    bars = [(A, chA, 0), (A, chA, 1), (B, chB, 0), (B, chB, 1)]
    bar = 0
    for part, chords, rep in bars:
        for i in range(8):
            bass, notes = SPRING_CH[chords[i]]
            strum(s, s.at(bar, 0), [n for n in notes], 0.07, bright=0.6, dur=1.2, p=-0.3)
            strum(s, s.at(bar, 3), [n for n in notes], 0.05, bright=0.6, dur=1.0, p=-0.3)
            s.add(ks(midi(bass), 1.2, s.r, bright=0.35, decay=0.993), s.at(bar, 0), 0.14)
            s.add(ks(midi(bass + 7), 1.0, s.r, bright=0.35, decay=0.993), s.at(bar, 3), 0.09)
            s.add(bodhran(s.r, "open"), s.at(bar, 0), 0.3, p=0.1)
            s.add(bodhran(s.r, "open"), s.at(bar, 3), 0.2, p=0.1)
            for b in (1, 2, 4, 5):
                s.add(bodhran(s.r, "tip"), s.at(bar, b), 0.07 + 0.03 * (b in (2, 5)), p=0.15)
            beat = 0
            for m, d in part[i]:
                if m is not None:
                    s.add(fiddle(midi(m), d * s.beat * 0.92, s.r, vib=0.004, a=0.012, rel=0.06), s.at(bar, beat), 0.085, p=0.15)
                    if rep == 1:
                        s.add(flute(midi(m + 12), d * s.beat * 0.85, s.r, vib=0.002), s.at(bar, beat), 0.03, p=-0.2)
                beat += d
            bar += 1
    return s.finish(-20.5, wet=0.22, rev=1.8)


def music_battle_spring():
    # a fight in the Spring Court: urgent rather than grim, D dorian, driving
    # string ostinato, toms, and a fiddle line that climbs
    s = Song("battle_spring", 132, 4, 16)
    CH = {"Dm": (38, [62, 65, 69]), "C": (36, [60, 64, 67]), "Bb": (34, [58, 62, 65]), "A": (33, [61, 64, 69]),
          "F": (41, [60, 65, 69]), "Gm": (43, [58, 62, 67])}
    prog = ["Dm", "C", "Bb", "C", "Dm", "C", "Bb", "A", "Dm", "C", "Bb", "C", "Dm", "F", "Gm", "A"]
    for bar, name in enumerate(prog):
        bass, notes = CH[name]
        root = bass + 12
        pattern = [root, root, root + 7, root, root + 12, root, root + 7, root]
        for e, m in enumerate(pattern):
            acc = e in (0, 3, 6)
            s.add(fiddle(midi(m), s.beat * 0.4, s.r, vib=0.0, a=0.006, rel=0.04, bright=2600), s.at(bar, e * 0.5), 0.07 if acc else 0.045, p=-0.25)
        s.add(drum(150, 55, 0.5, s.r, noise_amt=0.35, tone_decay=0.18), s.at(bar, 0), 0.45)
        s.add(drum(150, 55, 0.5, s.r, noise_amt=0.35, tone_decay=0.18), s.at(bar, 1.5), 0.3)
        s.add(drum(220, 110, 0.3, s.r, noise_amt=0.5, tone_decay=0.08, noise_lp=2500), s.at(bar, 2), 0.3, p=0.2)
        s.add(drum(150, 55, 0.5, s.r, noise_amt=0.35, tone_decay=0.18), s.at(bar, 3), 0.3)
        if bar % 2 == 0:
            chord_pad(s, bar, 2, notes, gain=0.05, cutoff=1200, a=0.4)
        s.add(pad_note(midi(bass), s.bar, s.r, cutoff=300, a=0.05, rel=0.3, voices=2), s.at(bar), 0.12)
    line = [(8, 0, 74, 2), (8, 2, 77, 2), (9, 0, 76, 3), (9, 3, 72, 1), (10, 0, 74, 2), (10, 2, 70, 2), (11, 0, 72, 4),
            (12, 0, 77, 2), (12, 2, 81, 2), (13, 0, 81, 3), (13, 3, 77, 1), (14, 0, 79, 2), (14, 2, 74, 2), (15, 0, 76, 2), (15, 2, 73, 2)]
    for bar, beat, m, d in line:
        s.add(fiddle(midi(m), d * s.beat * 0.95, s.r, vib=0.006, a=0.04, rel=0.12), s.at(bar, beat), 0.085, p=0.2)
    return s.finish(-19.5, wet=0.2, rev=1.8)


def music_calanmai():
    # Fire Night: drums under the hill, a drone, and a low flute in D phrygian
    s = Song("calanmai", 100, 4, 16)
    chord_pad(s, 0, 16, [38, 45], gain=0.09, cutoff=420, a=3.0)
    chord_pad(s, 4, 12, [50, 57], gain=0.03, cutoff=900, a=4.0)
    for bar in range(16):
        for step in range(16):
            b = step * 0.25
            if step in (0, 6, 8, 11):
                s.add(drum(95, 40, 0.6, s.r, noise_amt=0.25, tone_decay=0.22, noise_lp=600), s.at(bar, b), 0.42 if step == 0 else 0.3)
            if bar >= 2 and step in (4, 12):
                s.add(drum(170, 90, 0.35, s.r, noise_amt=0.45, tone_decay=0.1, noise_lp=1600), s.at(bar, b), 0.26, p=-0.2)
            if bar >= 4 and step in (2, 3, 7, 10, 14, 15):
                tick = hp(white(secs(0.06), s.r), 3500) * np.exp(-np.arange(secs(0.06)) / secs(0.012))
                s.add(tick, s.at(bar, b), 0.045, p=0.35)
    line = [(8, 0, 74, 3), (8, 3, 75, 1), (9, 0, 74, 2), (9, 2, 72, 2), (10, 0, 70, 4),
            (12, 0, 74, 2), (12, 2, 77, 2), (13, 0, 75, 3), (13, 3, 74, 1), (14, 0, 72, 2), (14, 2, 70, 2), (15, 0, 74, 4)]
    for bar, beat, m, d in line:
        s.add(flute(midi(m - 12), d * s.beat * 0.95, s.r, vib=0.005), s.at(bar, beat), 0.08, p=0.1)
    return s.finish(-20.5, wet=0.3, rev=2.8, damp=3800)


# ================================================================= catalogue
def sfx_all():
    out = {}
    for surf in ("snow", "mud", "wood"):
        for k in range(6):
            out[("sfx", "step_%s_%d" % (surf, k))] = (lambda s=surf, k=k: step(s, k), -8.0)
    out[("sfx", "bow_draw")] = (bow_draw, -6.0)
    out[("sfx", "bow_full")] = (bow_full, -8.0)
    out[("sfx", "bow_release")] = (bow_release, -2.0)
    out[("sfx", "dry_click")] = (dry_click, -8.0)
    for k in range(4):
        out[("sfx", "knife_swing_%d" % k)] = (lambda k=k: knife_swing(k), -4.0)
        out[("sfx", "knife_hit_%d" % k)] = (lambda k=k: flesh_hit("knife_hit", k), -2.0)
    for k in range(3):
        out[("sfx", "arrow_hit_flesh_%d" % k)] = (lambda k=k: flesh_hit("arrow_hit_flesh", k, wet=1.2, thud_f=120), -2.0)
        out[("sfx", "arrow_hit_wood_%d" % k)] = (lambda k=k: arrow_hit_wood(k), -3.0)
        out[("sfx", "arrow_hit_snow_%d" % k)] = (lambda k=k: arrow_hit_snow(k), -8.0)
        out[("sfx", "wolf_growl_%d" % k)] = (lambda k=k: wolf_growl(k), -3.0)
    out[("sfx", "arrow_break")] = (arrow_break, -5.0)
    out[("sfx", "pickup")] = (pickup, -8.0)
    out[("sfx", "eat")] = (eat, -6.0)
    out[("sfx", "forage")] = (forage, -6.0)
    out[("sfx", "wings")] = (wings, -8.0)
    out[("sfx", "player_hurt")] = (player_hurt, -2.0)
    out[("sfx", "player_down")] = (player_down, -2.0)
    out[("sfx", "wolf_snarl")] = (wolf_snarl, -2.0)
    out[("sfx", "wolf_lunge")] = (wolf_lunge, -2.0)
    out[("sfx", "wolf_bite")] = (wolf_bite, -2.0)
    out[("sfx", "wolf_yelp")] = (wolf_yelp, -4.0)
    out[("sfx", "ash_strike")] = (ash_strike, -1.0)
    out[("sfx", "beast_roar")] = (beast_roar, -1.0)
    for surf in ("grass", "gravel", "stone", "water"):
        for k in range(6):
            out[("sfx", "step_%s_%d" % (surf, k))] = (lambda s=surf, k=k: step_spring(s, k), -9.0 if surf != "stone" else -8.0)
    out[("sfx", "hiss")] = (hiss, -4.0)
    out[("sfx", "hiss_hurt")] = (hiss_hurt, -3.0)
    out[("sfx", "puca_growl")] = (puca_growl, -3.0)
    out[("sfx", "puca_hurt")] = (puca_hurt, -3.0)
    out[("sfx", "bogge_whisper")] = (bogge_whisper, -4.0)
    out[("sfx", "suriel_scream")] = (suriel_scream, -2.0)
    out[("sfx", "door_thud")] = (door_thud, -3.0)
    out[("sfx", "drum")] = (big_drum, -2.0)
    out[("sfx", "clatter")] = (clatter, -5.0)
    out[("ui", "hotbar")] = (lambda: ui_tap("hotbar", 1700, 0.025), -12.0)
    out[("ui", "pick")] = (lambda: ui_tap("pick", 1300, 0.035, 0.4), -10.0)
    out[("ui", "place")] = (lambda: ui_tap("place", 820, 0.045, 0.5), -10.0)
    out[("ui", "tick")] = (lambda: ui_tap("tick", 2600, 0.012), -14.0)
    out[("ui", "dialogue_next")] = (lambda: ui_tap("dialogue_next", 1100, 0.03, 0.1), -14.0)
    out[("ui", "choice")] = (lambda: ui_tap("choice", 700, 0.06, 0.3), -9.0)
    out[("ui", "open")] = (lambda: ui_swoosh("open", True), -9.0)
    out[("ui", "close")] = (lambda: ui_swoosh("close", False, 0.22), -11.0)
    out[("ui", "page")] = (ui_page, -10.0)
    out[("ui", "save")] = (lambda: ui_chime([72, 79], 0.14, 0.9), -9.0)
    out[("ui", "coin")] = (ui_coin, -8.0)
    out[("ui", "chapter")] = (ui_chapter, -4.0)
    out[("ui", "tier")] = (ui_tier, -5.0)
    return out


AMBIENCE = {"forest_wind": amb_forest_wind, "night_wind": amb_night_wind, "hearth": amb_hearth, "village": amb_village,
            "spring_day": amb_spring_day, "spring_night": amb_spring_night, "bogge": amb_bogge}

def music_chateau():
    # G major, a summer afternoon at a rich man's house across the Wall: a
    # pianoforte figure, a warm pad, a flute tune the fiddle answers; a
    # wistful turn to E minor in the middle that comes home again
    s = Song("chateau", 84, 4, 24)
    CH = {"G": (43, [55, 59, 62]), "D/F#": (42, [54, 57, 62]), "Em": (40, [55, 59, 64]), "C": (36, [55, 60, 64]),
          "Am": (45, [57, 60, 64]), "D": (38, [54, 57, 62]), "Bm": (47, [54, 59, 62]), "D7": (38, [54, 57, 60])}
    prog = ["G", "D/F#", "Em", "C", "G", "Am", "D", "D7",
            "G", "D/F#", "Em", "C", "Am", "Bm", "C", "D",
            "Em", "Bm", "C", "G", "Am", "D", "G", "G"]
    for bar, name in enumerate(prog):
        bass, notes = CH[name]
        s.add(ks(midi(bass + 12), 2.4, s.r, bright=0.4, decay=0.995), s.at(bar), 0.14, p=-0.15)
        lo, mid, hi = notes
        for k, m in enumerate([lo, hi, mid, hi] * 2):
            s.add(ks(midi(m + 12), 1.6, s.r, bright=0.62, decay=0.9955), s.at(bar, k * 0.5), 0.058 * (1.0 if k % 4 == 0 else 0.72), p=(m - 60) / 24.0)
        if bar % 2 == 0:
            chord_pad(s, bar, 2, notes, gain=0.03, cutoff=1500, a=1.2)
        if bar % 8 == 0:
            s.add(bell(midi(hi + 24), 3.0, amps=(1.0, 0.3, 0.12, 0.05, 0.02)), s.at(bar), 0.025, p=0.45)
    flute_tune = [(0, 0, 71, 1.5), (0, 1.5, 74, 0.5), (0, 2, 79, 2), (1, 0, 78, 1), (1, 1, 76, 1), (1, 2, 74, 2),
                  (2, 0, 76, 1.5), (2, 1.5, 79, 0.5), (2, 2, 71, 2), (3, 0, 72, 1), (3, 1, 74, 1), (3, 2, 76, 2),
                  (4, 0, 74, 2), (4, 2, 71, 1), (4, 3, 67, 1), (5, 0, 72, 1.5), (5, 1.5, 71, 0.5), (5, 2, 69, 2),
                  (6, 0, 66, 1), (6, 1, 69, 1), (6, 2, 74, 2), (7, 0, 72, 2), (7, 2, 69, 2),
                  (16, 0, 71, 3), (16, 3, 74, 1), (17, 0, 74, 2), (17, 2, 71, 2), (18, 0, 72, 1), (18, 1, 76, 1), (18, 2, 79, 2),
                  (19, 0, 78, 2), (19, 2, 74, 2), (20, 0, 76, 1), (20, 1, 74, 1), (20, 2, 72, 1), (20, 3, 71, 1),
                  (21, 0, 69, 2), (21, 2, 74, 2), (22, 0, 71, 4)]
    for bar, beat, m, d in flute_tune:
        s.add(flute(midi(m), d * s.beat * 0.95, s.r, vib=0.003), s.at(bar, beat), 0.07, p=0.12)
    answer = [(8, 0, 79, 2), (8, 2, 78, 1), (8, 3, 76, 1), (9, 0, 74, 3), (9, 3, 71, 1), (10, 0, 76, 1), (10, 1, 78, 1), (10, 2, 79, 2),
              (11, 0, 81, 2), (11, 2, 79, 2), (12, 0, 76, 1.5), (12, 1.5, 74, 0.5), (12, 2, 72, 2), (13, 0, 74, 1), (13, 1, 71, 1),
              (13, 2, 78, 2), (14, 0, 76, 2), (14, 2, 72, 2), (15, 0, 74, 4)]
    for bar, beat, m, d in answer:
        s.add(fiddle(midi(m), d * s.beat * 0.96, s.r, vib=0.005, a=0.1, rel=0.28), s.at(bar, beat), 0.048, p=-0.22)
    return s.finish(-21.5, wet=0.3, rev=2.4)


def music_ball():
    # a waltz in F for the ball: oom-pah-pah from the bass and plucked
    # strings, a fiddle on the tune and a flute floating over the second half
    s = Song("ball", 168, 3, 32)
    CH = {"F": (41, [57, 60, 65]), "C7": (36, [55, 58, 64]), "Bb": (46, [58, 62, 65]), "Gm": (43, [58, 62, 67]),
          "Dm": (38, [57, 62, 65])}
    prog = ["F", "F", "C7", "C7", "C7", "C7", "F", "F", "F", "F", "Bb", "Bb", "F", "C7", "F", "F",
            "Bb", "Bb", "F", "F", "Gm", "C7", "F", "F", "Dm", "Dm", "Gm", "Gm", "C7", "C7", "F", "F"]
    for bar, name in enumerate(prog):
        bass, notes = CH[name]
        s.add(ks(midi(bass), 1.6, s.r, bright=0.35, decay=0.994), s.at(bar, 0), 0.17, p=-0.1)
        s.add(pad_note(midi(bass + 12), s.beat * 0.9, s.r, cutoff=600, a=0.02, rel=0.3, voices=2), s.at(bar, 0), 0.05)
        for b in (1, 2):
            strum(s, s.at(bar, b), notes, 0.045 if b == 1 else 0.038, spread=0.008, bright=0.58, dur=0.7, p=0.2)
        if bar % 4 == 0:
            chord_pad(s, bar, 4, notes, gain=0.022, cutoff=1600, a=1.0)
    tune = [(0, 0, 69, 1), (0, 1, 72, 1), (0, 2, 77, 1), (1, 0, 81, 2), (1, 2, 79, 1),
            (2, 0, 79, 1), (2, 1, 76, 1), (2, 2, 72, 1), (3, 0, 70, 3),
            (4, 0, 67, 1), (4, 1, 70, 1), (4, 2, 76, 1), (5, 0, 79, 2), (5, 2, 77, 1),
            (6, 0, 76, 1), (6, 1, 77, 1), (6, 2, 69, 1), (7, 0, 72, 3),
            (8, 0, 69, 1), (8, 1, 72, 1), (8, 2, 77, 1), (9, 0, 81, 2), (9, 2, 84, 1),
            (10, 0, 82, 2), (10, 2, 81, 1), (11, 0, 77, 3), (12, 0, 81, 2), (12, 2, 79, 1),
            (13, 0, 79, 1), (13, 1, 76, 1), (13, 2, 72, 1), (14, 0, 77, 3), (15, 0, 77, 2),
            (16, 0, 74, 1), (16, 1, 77, 1), (16, 2, 82, 1), (17, 0, 82, 2), (17, 2, 81, 1),
            (18, 0, 81, 1), (18, 1, 77, 1), (18, 2, 72, 1), (19, 0, 69, 3),
            (20, 0, 70, 1), (20, 1, 74, 1), (20, 2, 79, 1), (21, 0, 79, 2), (21, 2, 76, 1),
            (22, 0, 77, 1), (22, 1, 72, 1), (22, 2, 69, 1), (23, 0, 72, 3),
            (24, 0, 74, 1), (24, 1, 77, 1), (24, 2, 81, 1), (25, 0, 81, 2), (25, 2, 79, 1),
            (26, 0, 79, 1), (26, 1, 74, 1), (26, 2, 70, 1), (27, 0, 74, 3),
            (28, 0, 76, 1), (28, 1, 79, 1), (28, 2, 82, 1), (29, 0, 81, 2), (29, 2, 79, 1),
            (30, 0, 77, 3), (31, 0, 77, 1)]
    for bar, beat, m, d in tune:
        s.add(fiddle(midi(m), d * s.beat * 0.94, s.r, vib=0.005, a=0.03, rel=0.16), s.at(bar, beat), 0.075, p=0.12)
        if bar >= 16:
            s.add(flute(midi(m + 12), d * s.beat * 0.9, s.r, vib=0.0025), s.at(bar, beat), 0.026, p=-0.25)
    return s.finish(-21.0, wet=0.3, rev=2.2)


def music_wreck():
    # the empty manor: slow and sparse, but not grim. A minor turning to F
    # and C, a lone harp, a flute that hopes a little, a far-off bell
    s = Song("wreck", 54, 4, 16)
    prog = [(45, [57, 60, 64]), (41, [57, 60, 65]), (36, [55, 60, 64]), (43, [55, 59, 62]),
            (45, [57, 60, 64]), (41, [57, 60, 65]), (43, [55, 59, 62]), (40, [56, 59, 64])] * 2
    for bar, (bass, notes) in enumerate(prog):
        s.add(pad_note(midi(bass + 12), s.bar, s.r, cutoff=420, a=1.6, rel=2.0), s.at(bar), 0.085)
        if bar % 2 == 0:
            chord_pad(s, bar, 2, notes, gain=0.03, cutoff=900, a=2.2)
        for k, m in enumerate([notes[0] + 12, notes[2] + 12]):
            s.add(ks(midi(m), 3.2, s.r, bright=0.38, decay=0.998), s.at(bar, 1 + k * 1.5), 0.055 * (1.0 if k == 0 else 0.7), p=(m - 66) / 22.0)
    melody = [(8, 0, 76, 4), (9, 0, 77, 2), (9, 2, 76, 2), (10, 0, 72, 4), (11, 0, 71, 3), (11, 3, 74, 1),
              (12, 0, 72, 2), (12, 2, 69, 2), (13, 0, 72, 2), (13, 2, 77, 2), (14, 0, 74, 4), (15, 0, 71, 4)]
    for bar, beat, m, d in melody:
        s.add(flute(midi(m), d * s.beat * 0.92, s.r, vib=0.0025), s.at(bar, beat), 0.045, p=0.15)
    for bar in (3, 7, 11, 15):
        s.add(bell(midi(88), 4.0, amps=(1.0, 0.25, 0.1, 0.04, 0.02)), s.at(bar, 2), 0.02, p=-0.5)
    return s.finish(-24.0, wet=0.46, rev=3.8, damp=4200)

MUSIC = {"title": music_title, "forest": music_forest, "hunt": music_hunt, "cottage": music_cottage,
         "village": music_village, "night_ride": music_night_ride,
         "spring_manor": music_spring_manor, "spring_night": music_spring_night, "spring_woods": music_spring_woods,
         "solstice": music_solstice, "battle_spring": music_battle_spring, "calanmai": music_calanmai,
         "chateau": music_chateau, "ball": music_ball, "wreck": music_wreck}


def main(argv):
    want = set(argv)
    for (kind, name), (fn, peak) in sfx_all().items():
        if want and name not in want and name.rsplit("_", 1)[0] not in want:
            continue
        sfx_out(kind, name, fn(), peak)
        print("wrote", kind, name)
    for name, fn in AMBIENCE.items():
        if want and name not in want:
            continue
        write_ogg(os.path.join(OUT, "ambience", name + ".ogg"), fn())
        print("wrote ambience", name)
    for name, fn in MUSIC.items():
        if want and name not in want:
            continue
        write_ogg(os.path.join(OUT, "music", name + ".ogg"), fn())
        print("wrote music", name)


if __name__ == "__main__":
    main(sys.argv[1:])
