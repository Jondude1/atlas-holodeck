#!/usr/bin/env python3
"""Synthesize the holodeck UI sounds (pure tones, stdlib only). Writes app/sounds/*.wav."""
import math, struct, wave, os

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "app", "sounds")

def write(name, samples):
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32767)) for s in samples))

def tone(freq, dur, amp=0.5, attack=0.004, decay=6.0, freq_end=None):
    n = int(RATE * dur); out = []; ph = 0.0
    for i in range(n):
        t = i / RATE
        f = freq if freq_end is None else freq + (freq_end - freq) * (i / n)
        ph += 2 * math.pi * f / RATE
        env = min(1.0, t / attack) * math.exp(-decay * t / dur)
        out.append(amp * env * math.sin(ph))
    return out

def mix(*tracks):
    n = max(len(t) for t in tracks)
    return [sum(t[i] if i < len(t) else 0 for t in tracks) for i in range(n)]

write("tick.wav", tone(2000, 0.06, 0.45, decay=5))
write("confirm.wav", tone(880, 0.075, 0.45, decay=3) + tone(1320, 0.075, 0.45, decay=4))
write("grab.wav", tone(220, 0.09, 0.5, attack=0.008, decay=4, freq_end=150))
# boot chime: soft rising sweep + a held fifth, ~1.8 s, fades out
sweep = tone(300, 1.8, 0.18, attack=0.3, decay=2.5, freq_end=900)
fifth = [0] * int(RATE * 0.9) + tone(660, 0.9, 0.2, attack=0.02, decay=3) 
fifth2 = [0] * int(RATE * 0.9) + tone(990, 0.9, 0.12, attack=0.02, decay=3)
write("boot.wav", mix(sweep, fifth, fifth2))

# voice earcons (brief #11): wake = short rising pair (listening opened), end = falling pair (utterance closed)
write("wake.wav", tone(660, 0.09, 0.5, decay=3) + tone(990, 0.13, 0.5, decay=4))
write("end.wav", tone(990, 0.09, 0.45, decay=3) + tone(560, 0.14, 0.45, decay=4))
