#!/usr/bin/env python3
"""Synthesize the vista ambience loops (Round 7-2): ocean, lake, valley wind.

Pure stdlib. Each loop is DUR seconds at 22050 Hz mono; every modulation period
divides DUR exactly and the noise is generated on a ring, so the loops are
seamless by construction. These are generated soundscapes (filtered noise),
not recordings — nothing copyrighted, per the project's audio rule.
"""
import math, os, random, struct, wave

RATE = 22050
DUR = 16.0
N = int(RATE * DUR)
OUT = os.path.join(os.path.dirname(__file__), "..", "app", "sounds")


def write(name, samples):
    peak = max(1e-6, max(abs(s) for s in samples))
    gain = 0.85 / peak
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(
            struct.pack("<h", int(max(-1, min(1, s * gain)) * 32767)) for s in samples))
    print("wrote", name)


def ring_noise(seed):
    """White noise on a ring (last sample neighbours the first)."""
    rng = random.Random(seed)
    return [rng.uniform(-1.0, 1.0) for _ in range(N)]


def lowpass_ring(x, k):
    """One-pole lowpass applied twice around the ring (k in cycles-ish 0..1)."""
    y = [0.0] * N
    acc = 0.0
    for _ in range(2):  # two laps so the filter state wraps seamlessly
        for i in range(N):
            acc += k * (x[i] - acc)
            y[i] = acc
    return y


def swell(t, cycles, depth, phase=0.0):
    """Periodic amplitude swell, integer cycles per loop."""
    return 1.0 - depth + depth * (0.5 + 0.5 * math.sin(2 * math.pi * cycles * t / DUR + phase)) ** 2


def coast():
    deep = lowpass_ring(ring_noise(11), 0.012)          # low rumble body
    wash = lowpass_ring(ring_noise(23), 0.10)           # brighter wash band
    out = []
    for i in range(N):
        t = i / RATE
        s = deep[i] * 1.15 * swell(t, 2, 0.55) + wash[i] * 0.5 * swell(t, 2, 0.8, phase=0.9)
        out.append(s)
    return out


def lake():
    body = lowpass_ring(ring_noise(37), 0.03)
    lap = lowpass_ring(ring_noise(41), 0.22)
    out = []
    for i in range(N):
        t = i / RATE
        s = body[i] * 0.5 * swell(t, 1, 0.3) + lap[i] * 0.16 * swell(t, 4, 0.75, phase=2.1)
        out.append(s)
    return out


def valley():
    body = lowpass_ring(ring_noise(53), 0.05)
    gust = lowpass_ring(ring_noise(59), 0.16)
    out = []
    for i in range(N):
        t = i / RATE
        s = body[i] * 0.8 * swell(t, 1, 0.45) + gust[i] * 0.35 * swell(t, 3, 0.7, phase=1.2)
        out.append(s)
    return out


write("amb-coast.wav", coast())
write("amb-lake.wav", lake())
write("amb-valley.wav", valley())
