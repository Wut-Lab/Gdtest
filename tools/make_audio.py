#!/usr/bin/env python3
"""Generate Square Hop's music and sound effects (needs numpy and ffmpeg).

    python3 tools/make_audio.py

Writes audio/music.ogg (a soft, happy loop, exactly 3:00 at 96 BPM) and audio/jump.wav,
audio/land.wav, audio/hurt.wav, audio/buy.wav, audio/ding.wav. Everything is synthesized here, so edit this file and rerun
it to change the sound, then run `godot --headless --path . --import`.
"""
import os
import subprocess
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "audio")
SR = 32000
rng = np.random.default_rng(7)

# ---------- Instruments ----------

def midi_hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def env_adsr(n, a, d, s, r, sustain_len):
    """Attack/decay/sustain then release, all in seconds; returns n samples."""
    t = np.arange(n) / SR
    e = np.where(t < a, t / max(a, 1e-4), s + (1 - s) * np.exp(-(t - a) / max(d, 1e-4)))
    rel = t > sustain_len
    e[rel] *= np.exp(-(t[rel] - sustain_len) / max(r, 1e-4))
    return e


def pluck(f, dur):
    """Music-box / marimba: bright attack, quick fade."""
    n = int((dur + 0.6) * SR)
    t = np.arange(n) / SR
    w = np.sin(2 * np.pi * f * t) + 0.25 * np.sin(4 * np.pi * f * t) * np.exp(-t / 0.08)
    return w * np.minimum(t / 0.004, 1) * np.exp(-t / 0.32)


def bell(f, dur):
    """Soft bell for melodies in the quiet parts."""
    n = int((dur + 1.0) * SR)
    t = np.arange(n) / SR
    w = (np.sin(2 * np.pi * f * t) + 0.35 * np.sin(2 * np.pi * f * 2.0 * t) * np.exp(-t / 0.3)
         + 0.12 * np.sin(2 * np.pi * f * 3.01 * t) * np.exp(-t / 0.15))
    return w * np.minimum(t / 0.005, 1) * np.exp(-t / 0.6)


def lead(f, dur):
    """Soft flute-like lead with a little vibrato on long notes."""
    n = int((dur + 0.15) * SR)
    t = np.arange(n) / SR
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5.2 * t) * np.clip((t - 0.18) / 0.2, 0, 1)
    ph = 2 * np.pi * np.cumsum(f * vib) / SR
    w = np.sin(ph) + 0.12 * np.sin(3 * ph) + 0.05 * np.sin(2 * ph)
    return w * env_adsr(n, 0.03, 0.25, 0.75, 0.08, dur)


def pad(f, dur):
    """Warm, slow chord pad: two slightly detuned sines."""
    n = int((dur + 0.5) * SR)
    t = np.arange(n) / SR
    w = np.sin(2 * np.pi * f * 0.998 * t) + np.sin(2 * np.pi * f * 1.002 * t)
    return w * 0.5 * env_adsr(n, 0.45, 1.0, 0.8, 0.4, dur)


def bass(f, dur):
    n = int((dur + 0.1) * SR)
    t = np.arange(n) / SR
    w = np.sin(2 * np.pi * f * t) + 0.18 * np.sin(6 * np.pi * f * t)
    return w * env_adsr(n, 0.008, 0.2, 0.6, 0.05, dur)


def kick(_f=0, _d=0):
    n = int(0.25 * SR)
    t = np.arange(n) / SR
    f = 50 + 70 * np.exp(-t / 0.03)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.09)


def noise_hit(decay, bright=True, n_sec=0.15):
    n = int(n_sec * SR)
    x = rng.standard_normal(n)
    if bright:
        x = np.diff(x, prepend=0)          # crude high-pass
    else:
        x = np.convolve(x, np.ones(6) / 6, "same")
    return x * np.exp(-np.arange(n) / SR / decay)


def hat(_f=0, _d=0):
    return noise_hit(0.025) * 0.5


def shaker(_f=0, _d=0):
    return noise_hit(0.04, n_sec=0.1) * 0.25


def clap(_f=0, _d=0):
    return noise_hit(0.06, bright=False, n_sec=0.2)


# ---------- The tune ----------

BPM = 96
BEAT = 60 / BPM
SLOT = BEAT / 2                 # eighth note
BAR = BEAT * 4
SCALE = [0, 2, 4, 5, 7, 9, 11]  # C major


def deg(d, base=60):
    """Scale degree (0 = C4, 7 = C5) to a MIDI note."""
    return base + 12 * (d // 7) + SCALE[d % 7]


CHORDS = {   # root MIDI note (octave 3) and quality
    "C": (48, "maj"), "G": (43, "maj"), "Am": (45, "min"), "F": (41, "maj"),
    "Em": (40, "min"), "Dm": (38, "min"),
}
TRIAD = {"maj": [0, 4, 7], "min": [0, 3, 7]}

PROG = {
    "A": ["C", "G", "Am", "F", "C", "G", "F", "G"],
    "B": ["F", "G", "Em", "Am", "F", "G", "C", "C"],
    "C": ["Dm", "G", "C", "Am", "Dm", "Em", "F", "G"],
}
# Melodies: per bar, (slot, length in slots, scale degree).
MEL = {
    "A": [[(0, 2, 2), (2, 2, 4), (4, 3, 7)],
          [(0, 2, 6), (2, 2, 8), (4, 2, 6), (6, 2, 4)],
          [(0, 3, 5), (3, 1, 7), (4, 4, 9)],
          [(0, 2, 8), (2, 2, 7), (4, 4, 5)],
          [(0, 2, 2), (2, 2, 4), (4, 2, 7), (6, 2, 9)],
          [(0, 3, 8), (3, 1, 6), (4, 4, 4)],
          [(0, 2, 5), (2, 2, 7), (4, 2, 10), (6, 2, 9)],
          [(0, 6, 8)]],
    "B": [[(0, 1, 7), (1, 1, 5), (2, 2, 7), (4, 4, 10)],
          [(0, 2, 8), (2, 2, 6), (4, 2, 4), (6, 2, 6)],
          [(0, 3, 9), (3, 1, 8), (4, 4, 6)],
          [(0, 2, 7), (2, 2, 5), (4, 4, 2)],
          [(0, 2, 3), (2, 2, 5), (4, 2, 7), (6, 2, 8)],
          [(0, 2, 8), (2, 2, 6), (4, 2, 8), (6, 2, 11)],
          [(0, 4, 9), (4, 2, 8), (6, 2, 7)],
          [(0, 6, 7)]],
    "C": [[(0, 4, 3), (4, 4, 5)],
          [(0, 4, 6), (4, 4, 8)],
          [(0, 6, 9), (6, 2, 8)],
          [(0, 8, 7)],
          [(0, 4, 8), (4, 4, 10)],
          [(0, 4, 9), (4, 4, 11)],
          [(0, 4, 12), (4, 2, 11), (6, 2, 10)],
          [(0, 4, 8), (4, 4, 6)]],
}
# Nine 8-bar sections = 72 bars = exactly 3:00. The last one ends on G so it leads back to C.
SECTIONS = [
    dict(part="A", mel=None, drums="light"),
    dict(part="A", mel="lead", drums="full"),
    dict(part="B", mel="lead", drums="full"),
    dict(part="A", mel="lead", bell=True, drums="full"),
    dict(part="C", mel="bell", drums="soft"),
    dict(part="B", mel="lead", drums="full"),
    dict(part="A", mel="lead", bell=True, drums="full"),
    dict(part="C", mel="bell", drums=None),
    dict(part="A", mel="outro", drums="light"),
]
ARP = [0, 1, 2, 3, 2, 1, 2, 1]   # chord-tone index per eighth note


def render_music():
    total = int(len(SECTIONS) * 8 * BAR * SR)
    buf = np.zeros(total + 4 * SR)

    def put(sound, t, gain):
        i = int(t * SR)
        s = sound * gain
        buf[i:i + len(s)] += s[: len(buf) - i]

    bar_i = 0
    for sec in SECTIONS:
        for b in range(8):
            t0 = bar_i * BAR
            root, q = CHORDS[PROG[sec["part"]][b]]
            tones = [root + 12 + x for x in TRIAD[q]] + [root + 24]
            # Pad: the chord, held for the bar.
            for m in tones[:3]:
                put(pad(midi_hz(m + 12), BAR * 0.95), t0, 0.05)
            # Arpeggio on the music box.
            for s, k in enumerate(ARP):
                accent = 1.0 if s % 2 == 0 else 0.75
                put(pluck(midi_hz(tones[k] + 12), SLOT), t0 + s * SLOT, 0.07 * accent)
            # Bouncy bass: root, root, fifth, octave.
            for s, ln, iv in [(0, 2, 0), (3, 1, 0), (4, 2, 7), (6, 2, 12)]:
                put(bass(midi_hz(root - 12 + iv), ln * SLOT * 0.9), t0 + s * SLOT, 0.16)
            # Melody.
            notes = MEL[sec["part"]][b]
            if sec["mel"] == "outro":
                notes = notes if b < 4 else notes[:1]
            for s, ln, d in notes if sec["mel"] else []:
                f = midi_hz(deg(d))
                if sec["mel"] in ("lead", "outro"):
                    put(lead(f, ln * SLOT * 0.92), t0 + s * SLOT, 0.12)
                else:
                    put(bell(f * 2, ln * SLOT), t0 + s * SLOT, 0.08)
                if sec.get("bell"):
                    put(bell(f * 2, ln * SLOT), t0 + s * SLOT, 0.035)
            # Drums, kept soft.
            dr = sec["drums"]
            if dr:
                for s in range(8):
                    t = t0 + s * SLOT
                    if s in (0, 4) and (dr != "light" or b >= 4):
                        put(kick(), t, 0.22)
                    if s % 2 == 1:
                        put(hat(), t, 0.05)
                    if dr == "full" and s in (2, 6):
                        put(clap(), t, 0.05)
                    if dr in ("full", "soft"):
                        put(shaker(), t + SLOT / 2, 0.04)
            bar_i += 1

    # Seamless loop: fold the ringing tail past the end back onto the start.
    tail = buf[total:]
    buf = buf[:total]
    buf[: len(tail)] += tail
    buf *= 0.7 / np.max(np.abs(buf))
    return buf


# ---------- Level tracks: busier, 128 BPM, 48 bars = exactly 90 s ----------

LEVEL_SECTIONS = {
    # Practice and dungeon (random) levels.
    "level": dict(shift=0, prog=["A", "A", "B", "C", "B", "A"],
                  mel=[None, "lead", "lead", "bell", "lead", "lead"]),
    # Saved levels in the Replay Room: same tune, new key, different order and colours.
    "saved": dict(shift=2, prog=["C", "B", "A", "C", "A", "B"],
                  mel=[None, "bell", "lead", "lead", "bell", "lead"]),
}


def render_level_music(variant):
    cfg = LEVEL_SECTIONS[variant]
    bpm = 128
    beat = 60 / bpm
    slot = beat / 2
    bar = beat * 4
    sh = cfg["shift"]
    total = int(len(cfg["prog"]) * 8 * bar * SR)
    buf = np.zeros(total + 4 * SR)

    def put(sound, t, gain):
        i = int(t * SR)
        x = sound * gain
        buf[i:i + len(x)] += x[: len(buf) - i]

    bar_i = 0
    for si, part in enumerate(cfg["prog"]):
        mel = cfg["mel"][si]
        for b in range(8):
            t0 = bar_i * bar
            root, q = CHORDS[PROG[part][b]]
            root += sh
            tones = [root + 12 + x for x in TRIAD[q]] + [root + 24]
            for m in tones[:3]:
                put(pad(midi_hz(m + 12), bar * 0.95), t0, 0.04)
            # Sixteenth-note arpeggio for drive.
            for k in range(16):
                idx = [0, 1, 2, 3][k % 4] if variant == "level" else [3, 2, 1, 0][k % 4]
                put(pluck(midi_hz(tones[idx] + 12), slot / 2), t0 + k * slot / 2,
                    0.055 * (1.0 if k % 2 == 0 else 0.7))
            # Driving eighth-note bass.
            for k in range(8):
                iv = [0, 0, 12, 0, 7, 0, 12, 7][k]
                put(bass(midi_hz(root - 12 + iv), slot * 0.8), t0 + k * slot, 0.15)
            for st, ln, d in MEL[part][b] if mel else []:
                f = midi_hz(deg(d) + sh)
                if mel == "lead":
                    put(lead(f, ln * slot * 0.9), t0 + st * slot, 0.12)
                    put(bell(f * 2, ln * slot), t0 + st * slot, 0.03)
                else:
                    put(bell(f * 2, ln * slot), t0 + st * slot, 0.09)
            # Drums: four-on-the-floor, claps on 2 and 4, eighth hats, sixteenth shakers.
            intro = si == 0 and b < 4
            for k in range(8):
                t = t0 + k * slot
                if k % 2 == 0 and not intro:
                    put(kick(), t, 0.24)
                if k in (2, 6):
                    put(clap(), t, 0.07)
                put(hat(), t + (slot / 2 if variant == "saved" else 0), 0.045)
                put(shaker(), t + slot / 2, 0.035)
            if b == 7:   # little fill into the next section
                for k in range(4):
                    put(clap(), t0 + (4 + k) * slot + slot / 2, 0.04)
            bar_i += 1

    tail = buf[total:]
    buf = buf[:total]
    buf[: len(tail)] += tail
    buf *= 0.7 / np.max(np.abs(buf))
    return buf


# ---------- Sound effects ----------

def sweep(f0, f1, dur, shape="tri"):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = f0 * (f1 / f0) ** (t / dur)
    ph = 2 * np.pi * np.cumsum(f) / SR
    if shape == "tri":
        return np.sin(ph) + 0.2 * np.sin(3 * ph) + 0.08 * np.sin(5 * ph)
    return np.sign(np.sin(ph)) * 0.5 + np.sin(ph) * 0.5


def sfx_jump():
    n_dur = 0.14
    w = sweep(330, 720, n_dur)
    t = np.arange(len(w)) / SR
    return w * np.minimum(t / 0.003, 1) * np.exp(-t / 0.07) * 0.6


def sfx_land():
    w = sweep(150, 60, 0.12)
    t = np.arange(len(w)) / SR
    thump = w * np.exp(-t / 0.035)
    dust = noise_hit(0.025, bright=False, n_sec=0.12) * 0.25
    return (thump + dust) * 0.7


def sfx_hurt():
    w = sweep(620, 170, 0.32, shape="square")
    t = np.arange(len(w)) / SR
    w *= 0.75 + 0.25 * np.sign(np.sin(2 * np.pi * 28 * t))    # a little wobble
    w *= np.minimum(t / 0.004, 1) * np.exp(-t / 0.14)
    crunch = noise_hit(0.04, n_sec=0.32) * 0.3
    return (w + crunch) * 0.45


def sfx_buy():
    """Shop purchase: a two-note bell "cha-ching" over a little coin shimmer."""
    out = np.zeros(int(0.7 * SR))
    for start, f in ((0.0, midi_hz(84)), (0.09, midi_hz(91))):
        w = bell(f, 0.2)[: len(out) - int(start * SR)]
        out[int(start * SR): int(start * SR) + len(w)] += w * 0.5
    shimmer = noise_hit(0.05, n_sec=0.15) * 0.15
    out[: len(shimmer)] += shimmer
    return out * 0.7


def sfx_ding():
    """Checkpoint: one clear, bright bell note with a soft octave shimmer."""
    w = bell(midi_hz(88), 0.25)
    t = np.arange(len(w)) / SR
    w += 0.3 * np.sin(2 * np.pi * midi_hz(100) * t) * np.exp(-t / 0.12)
    return w * 0.55


def write_wav(path, x, rate=SR):
    x = np.clip(x, -1, 1)
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(rate)
        f.writeframes((x * 32767).astype("<i2").tobytes())


def main():
    os.makedirs(OUT, exist_ok=True)
    write_wav(os.path.join(OUT, "jump.wav"), sfx_jump())
    write_wav(os.path.join(OUT, "land.wav"), sfx_land())
    write_wav(os.path.join(OUT, "hurt.wav"), sfx_hurt())
    write_wav(os.path.join(OUT, "buy.wav"), sfx_buy())
    write_wav(os.path.join(OUT, "ding.wav"), sfx_ding())
    tmp = os.path.join(OUT, "_music.wav")
    music = render_music()
    write_wav(tmp, music)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis",
                    "-q:a", "2", os.path.join(OUT, "music.ogg")], check=True)
    os.remove(tmp)
    for v in ("level", "saved"):
        m = render_level_music(v)
        write_wav(tmp, m)
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis",
                        "-q:a", "2", os.path.join(OUT, "music_%s.ogg" % v)], check=True)
        os.remove(tmp)
        print("AUDIO OK: music_%s %.1fs" % (v, len(m) / SR))
    print("AUDIO OK: music %.1fs" % (len(music) / SR))


if __name__ == "__main__":
    main()
