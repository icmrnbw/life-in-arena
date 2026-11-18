#!/usr/bin/env python3
"""Renders Emberpit's music: three original medieval-style tunes, synthesized from code (no samples).

  python3 tools/compose_music.py            -> audio/music/{menu,battle,boss}.ogg  (needs numpy + ffmpeg)

All melodies, harmonies and instruments below were written for this game; the output is ours to ship.
Each track is rendered with its reverb tail wrapped back to the start so it loops seamlessly.
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

SR = 32000
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "audio", "music")
rng = np.random.default_rng(1347)

_PC = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def midi(s: str) -> int:
    i, acc = 1, 0
    while s[i] in "#b":
        acc += 1 if s[i] == "#" else -1
        i += 1
    return 12 * (int(s[i:]) + 1) + _PC[s[0]] + acc


def hz(m) -> float:
    return 440.0 * 2.0 ** ((m - 69) / 12.0)


def seq(text: str):
    """'D5:1 E5:.5 r:.5' -> [(midi or None, beats)]"""
    out = []
    for tok in text.split():
        n, d = tok.split(":")
        out.append((None if n == "r" else midi(n), float(d)))
    return out


def lowpass(x, k):
    return np.convolve(x, np.ones(k) / k, mode="same") if k > 1 else x


def adsr(n, a, r, sustain_n):
    """attack/release in samples; holds 1.0 until sustain_n, then releases."""
    env = np.ones(n)
    a = max(1, min(a, n))
    env[:a] = np.linspace(0.0, 1.0, a)
    if sustain_n < n:
        rel = np.linspace(1.0, 0.0, max(1, n - sustain_n))
        env[sustain_n:] *= rel[: n - sustain_n]
    return env


def vib_phase(f, n, rate, depth, delay):
    t = np.arange(n) / SR
    ramp = np.clip((t - delay) / 0.3, 0.0, 1.0)
    fi = f * (1.0 + depth * ramp * np.sin(2 * np.pi * rate * t + rng.uniform(0, 6.28)))
    return 2 * np.pi * np.cumsum(fi) / SR


# ---------------------------------------------------------------- instruments
def lute(f, dur, vel=1.0):
    """Plucked gut string: harmonics decay faster the higher they are, plucked near the bridge."""
    ring = min(dur + 1.4, 2.6)
    n = int(ring * SR)
    t = np.arange(n) / SR
    y = np.zeros(n)
    for k in range(1, 16):
        fk = f * k * (1 + 0.0004 * k * k)
        if fk > SR * 0.45:
            break
        amp = abs(np.sin(np.pi * k * 0.17)) / k ** 1.05
        y += amp * np.exp(-t * (1.6 + 0.55 * k ** 1.35)) * np.sin(2 * np.pi * fk * t + rng.uniform(0, 6.28))
    y *= adsr(n, int(0.002 * SR), int(0.08 * SR), int((dur + 0.9) * SR))
    return 0.45 * vel * y


def harp(f, dur, vel=1.0):
    n = int(min(dur + 2.2, 3.2) * SR)
    t = np.arange(n) / SR
    y = np.zeros(n)
    for k, a in ((1, 1.0), (2, 0.35), (3, 0.12), (4, 0.05)):
        y += a * np.exp(-t * (0.9 + 0.8 * k)) * np.sin(2 * np.pi * f * k * t)
    y *= adsr(n, int(0.004 * SR), 1, n)
    return 0.4 * vel * y


def recorder(f, dur, vel=1.0):
    """Breathy wooden flute with a delayed vibrato."""
    n = int((dur + 0.12) * SR)
    ph = vib_phase(f, n, 5.2, 0.005, 0.25)
    y = np.sin(ph) + 0.22 * np.sin(2 * ph) + 0.1 * np.sin(3 * ph) + 0.04 * np.sin(4 * ph)
    breath = np.diff(rng.standard_normal(n + 1)) * 0.02
    env = adsr(n, int(0.05 * SR), 1, int(dur * SR))
    chiff = np.exp(-np.arange(n) / (0.02 * SR)) * rng.standard_normal(n) * 0.06
    return 0.32 * vel * ((y + breath) * env + chiff)


def shawm(f, dur, vel=1.0, bright=1200.0):
    """Double-reed bombarde: nasal formant around `bright` Hz."""
    n = int((dur + 0.08) * SR)
    ph = vib_phase(f, n, 5.6, 0.006, 0.18)
    y = np.zeros(n)
    for k in range(1, 24):
        fk = f * k
        if fk > SR * 0.42:
            break
        w = k ** -0.75 * (1.0 + 1.6 * np.exp(-(((fk - bright) / 450.0) ** 2))) * np.exp(-fk / 4500.0)
        y += w * np.sin(k * ph)
    env = adsr(n, int(0.025 * SR), 1, int(dur * SR))
    return 0.16 * vel * y * env


def drone(f, dur, vel=1.0):
    """Hurdy-gurdy/bagpipe drone: bright saw with a slow wheel wobble."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    ph = 2 * np.pi * f * t
    y = np.zeros(n)
    for k in range(1, 30):
        if f * k > SR * 0.42:
            break
        y += np.sin(k * ph) / k * np.exp(-f * k / 1400.0)
    y *= 0.88 + 0.12 * np.sin(2 * np.pi * 0.37 * t + rng.uniform(0, 6.28))
    return 0.1 * vel * y * adsr(n, int(0.4 * SR), 1, n - int(0.4 * SR))


def choir(f, dur, vel=1.0):
    """Low 'ah' voices: three detuned saws through two vowel formants."""
    n = int((dur + 0.8) * SR)
    t = np.arange(n) / SR
    y = np.zeros(n)
    for det in (-0.004, 0.0, 0.0045):
        fv = f * (1 + det)
        ph = 2 * np.pi * fv * t + rng.uniform(0, 6.28)
        for k in range(1, 40):
            fk = fv * k
            if fk > 4000:
                break
            w = (np.exp(-(((fk - 650) / 160.0) ** 2)) + 0.6 * np.exp(-(((fk - 1080) / 210.0) ** 2)) + 0.06) / k ** 0.5
            y += w * np.sin(k * ph)
    env = adsr(n, int(0.6 * SR), 1, int(dur * SR))
    return 0.05 * vel * y * env


def bell(f, vel=1.0):
    n = int(4.0 * SR)
    t = np.arange(n) / SR
    y = np.zeros(n)
    for r, a, d in ((0.5, 0.6, 0.8), (1.0, 1.0, 1.1), (1.19, 0.5, 1.6), (1.56, 0.35, 2.0), (2.0, 0.3, 2.4), (2.74, 0.2, 3.2), (3.76, 0.1, 4.5)):
        y += a * np.exp(-t * d) * np.sin(2 * np.pi * f * r * t)
    return 0.18 * vel * y


def tabor(vel=1.0):
    """Rope-tension frame drum: low thump with a falling pitch."""
    n = int(0.45 * SR)
    t = np.arange(n) / SR
    f = 95 + 90 * np.exp(-t / 0.03)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.16)
    slap = lowpass(rng.standard_normal(n), 3) * np.exp(-t / 0.025) * 0.35
    return 0.7 * vel * (body + slap)


def tak(vel=1.0):
    """Rim / snare-gut tap."""
    n = int(0.18 * SR)
    t = np.arange(n) / SR
    nz = lowpass(np.diff(rng.standard_normal(n + 1)), 2) * np.exp(-t / 0.035)
    tone = np.sin(2 * np.pi * 330 * t) * np.exp(-t / 0.03)
    return 0.3 * vel * (nz * 0.6 + tone * 0.5)


def wardrum(vel=1.0):
    """Big war drum for the boss: deep boom."""
    n = int(1.4 * SR)
    t = np.arange(n) / SR
    f = 48 + 60 * np.exp(-t / 0.05)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.45)
    hit = lowpass(rng.standard_normal(n), 8) * np.exp(-t / 0.05) * 0.5
    return 0.95 * vel * (body + hit)


# ---------------------------------------------------------------- mixing
class Track:
    def __init__(self, bpm, bars, beats_per_bar, tail=3.5):
        self.spb = 60.0 / bpm
        self.bar = beats_per_bar
        self.loop_n = int(round(bars * beats_per_bar * self.spb * SR))
        self.buf = np.zeros((2, self.loop_n + int(tail * SR)))
        self.dry_only = np.zeros_like(self.buf)

    def add(self, y, beat, pan=0.0, gain=1.0, human=0.008, wet=True):
        start = int((beat * self.spb + (rng.uniform(-human, human) if beat > 0 else 0.0)) * SR)
        start = max(0, start)
        end = min(start + len(y), self.buf.shape[1])
        if end <= start:
            return
        a = (pan + 1) * np.pi / 4
        tgt = self.buf if wet else self.dry_only
        tgt[0, start:end] += y[: end - start] * gain * np.cos(a)
        tgt[1, start:end] += y[: end - start] * gain * np.sin(a)

    def line(self, inst, notes, beat0, pan=0.0, gain=1.0, octave=0, legato=0.95):
        b = beat0
        for m, d in notes:
            if m is not None:
                self.add(inst(hz(m + 12 * octave), d * self.spb * legato), b, pan, gain * rng.uniform(0.88, 1.0))
            b += d
        return b

    def render(self, room=1.8, wet_mix=0.28):
        n_ir = int(room * SR)
        t = np.arange(n_ir) / SR
        ir = []
        for _ in range(2):
            r = lowpass(rng.standard_normal(n_ir), 4) * np.exp(-t * 6.9 / room)
            r[: int(0.012 * SR)] = 0.0  # pre-delay
            ir.append(r / np.sqrt(np.sum(r * r)))
        L = self.buf.shape[1] + n_ir
        nfft = 1 << (L - 1).bit_length()
        wet = np.zeros((2, L))
        for c in range(2):
            wet[c] = np.fft.irfft(np.fft.rfft(self.buf[c], nfft) * np.fft.rfft(ir[c], nfft), nfft)[:L]
        mix = np.zeros((2, L))
        mix[:, : self.buf.shape[1]] = self.buf + self.dry_only
        mix += wet * wet_mix
        # wrap everything past the loop point back to the start: seamless loop
        out = mix[:, : self.loop_n].copy()
        rest = mix[:, self.loop_n :]
        for i in range(0, rest.shape[1], self.loop_n):
            seg = rest[:, i : i + self.loop_n]
            out[:, : seg.shape[1]] += seg
        rms = np.sqrt(np.mean(out ** 2))
        out *= 10 ** (-17.0 / 20.0) / max(rms, 1e-9)
        return np.tanh(out * 1.05) / 1.05


def write_ogg(stereo, name):
    os.makedirs(OUT, exist_ok=True)
    pcm = (np.clip(stereo.T, -1, 1) * 32000).astype("<i2")
    with tempfile.TemporaryDirectory() as d:
        wav_path = os.path.join(d, name + ".wav")
        with wave.open(wav_path, "wb") as w:
            w.setnchannels(2)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(pcm.tobytes())
        dst = os.path.join(OUT, name + ".ogg")
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path, "-c:a", "libvorbis", "-q:a", "3", dst], check=True)
    print("%-6s %5.1f s  %4d KB" % (name, stereo.shape[1] / SR, os.path.getsize(dst) // 1024))


def check_bars(name, notes, per_bar, bars):
    total = sum(d for _, d in notes)
    assert abs(total - per_bar * bars) < 1e-6, "%s: %.2f beats, expected %d" % (name, total, per_bar * bars)


def chord_notes(root, minor):
    r = midi(root)
    return [r, r + (3 if minor else 4), r + 7]


# ---------------------------------------------------------------- 1. menu: "The Ember Hearth" (D Dorian, 3/4)
def menu():
    tr = Track(bpm=96, bars=32, beats_per_bar=3)
    A = seq("A4:1 D5:1 E5:1  F5:2 E5:1  D5:1 C5:1 A4:1  G4:1.5 A4:.5 C5:1 "
            "D5:1 F5:1 A5:1  G5:2 F5:1  E5:1 C5:1 E5:1  D5:3")
    B = seq("C5:1 F5:1 G5:1  A5:2 G5:1  F5:1 E5:1 D5:1  C5:2 A4:1 "
            "B4:1 C5:1 D5:1  E5:1.5 D5:.5 C5:1  D5:1 C5:1 A4:1  D5:3")
    # second time round: same tune, lightly ornamented
    A2 = seq("A4:1 D5:.5 E5:.5 F5:1  F5:1 G5:.5 F5:.5 E5:1  D5:1 C5:1 A4:1  G4:1.5 A4:.5 C5:1 "
             "D5:1 F5:1 A5:1  C6:1 B5:.5 A5:.5 G5:1  E5:1 C5:1 E5:1  D5:3")
    B2 = seq("C5:1 F5:1 G5:1  A5:1.5 B5:.5 C6:1  A5:1 G5:1 F5:1  E5:2 C5:1 "
             "D5:1 E5:1 F5:1  G5:1.5 F5:.5 E5:1  D5:1 E5:1 C5:1  D5:3")
    for nm, s in (("A", A), ("B", B), ("A2", A2), ("B2", B2)):
        check_bars("menu " + nm, s, 3, 8)
    chords_A = [("D3", 1), ("D3", 1), ("C3", 0), ("G2", 0), ("D3", 1), ("C3", 0), ("C3", 0), ("D3", 1)]
    chords_B = [("F2", 0), ("F2", 0), ("D3", 1), ("A2", 1), ("G2", 0), ("C3", 0), ("A2", 1), ("D3", 1)]
    harmony = chords_A + chords_B + chords_A + chords_B
    # lute: broken chords in eighths (root, fifth, octave, tenth, octave, fifth)
    for bar, (root, mi) in enumerate(harmony):
        r, third, fifth = chord_notes(root, mi)
        pattern = [r, fifth, r + 12, third + 12, r + 12, fifth]
        for i, m in enumerate(pattern):
            tr.add(lute(hz(m), tr.spb * 0.5), bar * 3 + i * 0.5, pan=-0.35, gain=0.85 if i else 1.0)
    # recorder carries the tune, the harp joins an octave below the second time
    b = 0.0
    for part, inst_gain in ((A, 1.0), (B, 1.0), (A2, 1.0), (B2, 1.0)):
        tr.line(recorder, part, b, pan=0.25, gain=inst_gain)
        if part is A2 or part is B2:
            tr.line(harp, part, b, pan=0.45, gain=0.5, octave=-1)
        b += 24
    # quiet open-fifth drone on D under everything
    tr.add(drone(hz(midi("D2")), 32 * 3 * tr.spb + 3.0), 0, pan=0.0, gain=0.55, human=0)
    tr.add(drone(hz(midi("A2")), 32 * 3 * tr.spb + 3.0), 0, pan=0.1, gain=0.35, human=0)
    # soft frame-drum heartbeat in the second half
    for bar in range(16, 32):
        tr.add(tabor(0.5), bar * 3, pan=0.0, gain=0.5)
        tr.add(tak(0.4), bar * 3 + 2, pan=0.2, gain=0.4)
    return tr.render(room=2.2, wet_mix=0.32)


# ---------------------------------------------------------------- 2. battle: "Steel of the Pit" (E Dorian, 4/4)
def battle():
    tr = Track(bpm=138, bars=32, beats_per_bar=4)
    A = seq("E5:.5 E5:.5 B4:.5 E5:.5 G5:1 F#5:.5 E5:.5  D5:.5 E5:.5 F#5:.5 D5:.5 B4:2 "
            "E5:.5 E5:.5 B4:.5 E5:.5 G5:.5 A5:.5 B5:1  A5:.5 G5:.5 F#5:.5 D5:.5 E5:2")
    B = seq("G5:1 G5:.5 A5:.5 B5:1 A5:.5 G5:.5  F#5:1 D5:1 A4:1 D5:1 "
            "E5:1 E5:.5 F#5:.5 G5:1 F#5:.5 E5:.5  D5:1 C#5:.5 D5:.5 B4:1 r:1")
    A3 = seq("B5:.5 B5:.5 G5:.5 B5:.5 E6:1 D6:.5 B5:.5  A5:.5 B5:.5 A5:.5 F#5:.5 D5:2 "
             "E5:.5 G5:.5 B5:.5 G5:.5 A5:.5 B5:.5 C#6:1  D6:.5 B5:.5 A5:.5 F#5:.5 E5:2")
    for nm, s in (("A", A), ("B", B), ("A3", A3)):
        check_bars("battle " + nm, s, 4, 4)
    form = [A, A, B, A3, A, A3, B, A]
    chords = {id(A): [("E3", 1), ("D3", 0), ("E3", 1), ("D3", 0)],
              id(A3): [("E3", 1), ("D3", 0), ("E3", 1), ("D3", 0)],
              id(B): [("G2", 0), ("D3", 0), ("E3", 1), ("D3", 0)]}
    for sec, part in enumerate(form):
        b0 = sec * 16
        tr.line(shawm, part, b0, pan=0.15, gain=1.0, legato=0.9)
        if sec >= 4:
            # second pass: a recorder doubles the tune an octave up for brightness
            tr.line(recorder, part, b0, pan=-0.3, gain=0.45, octave=1, legato=0.85)
        for bar, (root, mi) in enumerate(chords[id(part)]):
            r, third, fifth = chord_notes(root, mi)
            for e in range(8):
                beat = b0 + bar * 4 + e * 0.5
                strum = [r, fifth, r + 12] if e % 2 == 0 else [fifth, r + 12, third + 12]
                for j, m in enumerate(strum):
                    tr.add(lute(hz(m), tr.spb * 0.45, 0.9 if e % 2 == 0 else 0.6), beat + j * 0.03, pan=-0.4, gain=0.55)
    total_beats = 32 * 4
    tr.add(drone(hz(midi("E2")), total_beats * tr.spb + 3.0), 0, gain=0.7, human=0)
    tr.add(drone(hz(midi("B2")), total_beats * tr.spb + 3.0), 0, pan=0.1, gain=0.45, human=0)
    # tabor: boom . tak boom | tak . boom tak, with a roll into each phrase
    for bar in range(32):
        b0 = bar * 4
        for off, kind, v in ((0, "b", 1.0), (1, "t", 0.8), (1.5, "b", 0.6), (2, "b", 0.9), (3, "t", 0.8), (3.5, "b", 0.5)):
            tr.add(tabor(v) if kind == "b" else tak(v), b0 + off, pan=0.0 if kind == "b" else 0.25, gain=0.95)
        if bar % 4 == 3:
            for k in range(4):
                tr.add(tak(0.4 + 0.15 * k), b0 + 3 + k * 0.25, pan=0.25, gain=0.8)
    return tr.render(room=1.5, wet_mix=0.22)


# ---------------------------------------------------------------- 3. boss: "The Warden Wakes" (D Phrygian, 4/4)
def boss():
    tr = Track(bpm=116, bars=24, beats_per_bar=4)
    M = seq("D5:1.5 Eb5:.5 D5:1 C5:1  Bb4:1 C5:.5 Bb4:.5 A4:2 "
            "D5:1.5 Eb5:.5 F5:1 G5:1  F5:.5 Eb5:.5 D5:1 D5:2")
    N = seq("A5:2 G5:1 F5:1  Eb5:1.5 F5:.5 D5:2 "
            "C5:1 Eb5:1 D5:1 C5:1  Bb4:1 A4:.5 Bb4:.5 A4:2")
    for nm, s in (("M", M), ("N", N)):
        check_bars("boss " + nm, s, 4, 4)
    # 4 bars of drums and voices, then the theme
    form = [None, M, M, N, M, N]
    pads = {None: [("D3", 1), ("Eb3", 0), ("D3", 1), ("Eb3", 0)],
            id(M): [("D3", 1), ("Bb2", 0), ("D3", 1), ("D3", 1)],
            id(N): [("D3", 1), ("Eb3", 0), ("C3", 1), ("Bb2", 0)]}
    for sec, part in enumerate(form):
        b0 = sec * 16
        if part is not None:
            tr.line(shawm, part, b0, pan=0.1, gain=1.0, legato=0.92, octave=-1 if sec in (1, 4) else 0)
            if sec in (2, 3, 5):
                tr.line(shawm, part, b0, pan=-0.25, gain=0.5, octave=-1, legato=0.92)
        for bar, (root, mi) in enumerate(pads[None if part is None else id(part)]):
            for m in chord_notes(root, mi):
                tr.add(choir(hz(m), 4 * tr.spb), b0 + bar * 4, pan=rng.uniform(-0.5, 0.5), gain=1.0, human=0)
            if bar % 2 == 0:
                tr.add(bell(hz(midi("D4"))), b0 + bar * 4, pan=-0.2, gain=0.8, human=0)
    total_beats = 24 * 4
    tr.add(drone(hz(midi("D2")), total_beats * tr.spb + 3.0), 0, gain=0.9, human=0)
    tr.add(drone(hz(midi("A1")), total_beats * tr.spb + 3.0), 0, gain=0.5, human=0)
    # war drums: BOOM . . boom BOOM . boom . / taks driving the eighths
    for bar in range(24):
        b0 = bar * 4
        for off, v in ((0, 1.0), (1.5, 0.6), (2, 0.9), (3, 0.55)):
            tr.add(wardrum(v), b0 + off, gain=1.0)
        for e in range(8):
            tr.add(tak(0.35 + (0.35 if e % 2 else 0.0)), b0 + e * 0.5, pan=0.3, gain=0.7)
        if bar % 4 == 3:
            for k in range(8):
                tr.add(tabor(0.4 + 0.07 * k), b0 + 2 + k * 0.25, pan=-0.2, gain=0.8)
    return tr.render(room=2.6, wet_mix=0.3)


if __name__ == "__main__":
    want = sys.argv[1:] or ["menu", "battle", "boss"]
    for name in want:
        write_ogg({"menu": menu, "battle": battle, "boss": boss}[name](), name)
